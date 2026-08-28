import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';
import '../../../core/network/token_store.dart';
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
/// Injeta o JWT de acesso salvo pelo login em cada requisição via
/// `Authorization: Bearer <token>`.
class AdminApi {
  AdminApi({http.Client? client, TokenStore? tokenStore})
      : _client = client ?? http.Client(),
        _tokenStore = tokenStore ?? TokenStore();

  final http.Client _client;
  final TokenStore _tokenStore;

  Future<dynamic> _get(String path) async {
    final token = await _tokenStore.readAccessToken();
    final headers = <String, String>{
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };

    final http.Response res;
    try {
      res = await _client.get(
        Uri.parse('${ApiConfig.adminBaseUrl}$path'),
        headers: headers,
      );
    } on Exception {
      throw AdminApiException('Não foi possível conectar ao servidor');
    }

    if (res.statusCode == 401) {
      throw AdminApiException('Sessão expirada. Faça login novamente.');
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

  // -------------------------------------------------------------------------
  // Endpoints dedicados às seções do dashboard mobile (top 3, filtrados)
  // -------------------------------------------------------------------------

  /// Top 3 produtos com estoque baixo.
  /// `GET /inventory?lowStock=true&size=3`
  Future<List<InventoryItem>> fetchLowStockTop3() async {
    final json = await _get('/inventory?lowStock=true&size=3');
    return _content(json)
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Top 3 transportadoras ativas.
  /// `GET /carriers?status=ACTIVE&size=3`
  Future<List<Carrier>> fetchActiveCarriersTop3() async {
    final json = await _get('/carriers?status=ACTIVE&size=3');
    return _content(json)
        .map((e) => Carrier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Top 3 ocorrências abertas (mais recentes).
  /// `GET /carrier-occurrences?status=OPEN&size=3`
  Future<List<CarrierOccurrence>> fetchOpenOccurrencesTop3() async {
    final json = await _get('/carrier-occurrences?status=OPEN&size=3');
    return _content(json)
        .map((e) => CarrierOccurrence.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
