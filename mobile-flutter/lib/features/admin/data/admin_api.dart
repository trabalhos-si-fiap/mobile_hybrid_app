import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';
import '../domain/dashboard.dart';

/// Lançada quando uma chamada à Edu Admin API falha; carrega mensagem
/// amigável pronta para exibir ao usuário.
class AdminApiException implements Exception {
  AdminApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Cliente HTTP para os endpoints da Edu Admin API (`api/`) consumidos
/// pelas telas administrativas do app.
///
/// A API hoje não exige autenticação (`SecurityConfig` é `permitAll`), e
/// login está fora do escopo atual do app — por isso este cliente usa um
/// [http.Client] simples, sem injetar `Authorization` nem depender de uma
/// sessão salva.
class AdminApi {
  AdminApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<dynamic> _get(String path) async {
    final http.Response res;
    try {
      res = await _client.get(Uri.parse('${ApiConfig.adminBaseUrl}$path'));
    } on Exception {
      throw AdminApiException('Não foi possível conectar ao servidor');
    }
    if (res.statusCode == 404) {
      throw AdminApiException('Recurso não encontrado (404)');
    }
    if (res.statusCode >= 500) {
      throw AdminApiException('Erro interno do servidor (${res.statusCode})');
    }
    if (res.statusCode != 200) {
      throw AdminApiException(
        'Falha ao carregar dados do painel (${res.statusCode})',
      );
    }
    return jsonDecode(res.body);
  }

  /// Extrai a lista de itens de uma resposta paginada do Spring Data
  /// (`Page<T>`, serializada com o conteúdo em `content`).
  List<dynamic> _content(dynamic json) {
    if (json is Map<String, dynamic>) {
      return json['content'] as List<dynamic>? ?? [];
    }
    return json as List<dynamic>;
  }

  /// Métricas agregadas + resumo executivo do dashboard mobile.
  /// `GET /dashboard`.
  Future<DashboardResponse> fetchDashboard({int days = 30}) async {
    final json = await _get('/dashboard?days=$days');
    return DashboardResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Lista de transportadoras. `GET /carriers`.
  Future<List<Carrier>> fetchCarriers({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final json = await _get('/carriers$query');
    return _content(json)
        .map((e) => Carrier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lista de ocorrências de transportadoras. `GET /carrier-occurrences`.
  Future<List<CarrierOccurrence>> fetchOccurrences({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final json = await _get('/carrier-occurrences$query');
    return _content(json)
        .map((e) => CarrierOccurrence.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Itens de estoque, opcionalmente filtrados por estoque baixo.
  /// `GET /inventory`.
  Future<List<InventoryItem>> fetchInventory({bool lowStock = false}) async {
    final json = await _get('/inventory?lowStock=$lowStock');
    return _content(json)
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
