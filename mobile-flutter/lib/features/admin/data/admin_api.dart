import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';
import '../../../core/network/app_http.dart';
import '../../../core/network/token_store.dart';
import '../domain/analytics.dart';

/// Lançada quando uma chamada ao analytics-service falha; carrega mensagem
/// amigável pronta para exibir ao usuário.
class AdminApiException implements Exception {
  AdminApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Cliente HTTP para os endpoints do Analytics Service (`/analytics/*`) e
/// demais rotas admin, todos protegidos por `role=admin` no backend. Segue
/// a mesma convenção dos demais serviços do app: usa [appAuthClient]
/// (refresh automático de token em 401) em vez de gerenciar o header de
/// autorização manualmente.
class AdminApi {
  AdminApi({http.Client? client, TokenStore? tokenStore})
    : _client = client ?? appAuthClient,
      _tokenStore = tokenStore ?? TokenStore();

  final http.Client _client;
  final TokenStore _tokenStore;

  Future<Map<String, String>> _headers() async {
    final access = await _tokenStore.readAccessToken();
    if (access == null) {
      throw AdminApiException('Sessão expirada. Entre novamente.');
    }
    return {'Authorization': 'Bearer $access'};
  }

  Future<dynamic> _get(String path) async {
    final http.Response res;
    try {
      res = await _client.get(
        Uri.parse('${ApiConfig.adminBaseUrl}$path'),
        headers: await _headers(),
      );
    } on AdminApiException {
      rethrow;
    } on Exception {
      throw AdminApiException('Não foi possível conectar ao servidor');
    }
    if (res.statusCode == 403) {
      throw AdminApiException(
        'Seu usuário não tem permissão de administrador.',
      );
    }
    if (res.statusCode != 200) {
      throw AdminApiException(
        'Falha ao carregar dados do painel (${res.statusCode})',
      );
    }
    return jsonDecode(res.body);
  }

  /// Relatório executivo (métricas agregadas + resumo em texto gerado por
  /// LLM) do período dos últimos [dias] dias. Alimenta a tela inicial do
  /// admin.
  Future<ResumoExecutivo> fetchResumoExecutivo({int dias = 7}) async {
    final json = await _get('/analytics/executive-summary?dias=$dias');
    return ResumoExecutivo.fromJson(json as Map<String, dynamic>);
  }

  /// Contagem de eventos do event log por tipo (ex: order.created,
  /// order.delivered, diagnostic.answered...). Alimenta os KPIs do Painel
  /// Analítico.
  Future<List<TipoContagem>> fetchResumoEventos() async {
    final json = await _get('/analytics/summary');
    return (json as List<dynamic>)
        .map((e) => TipoContagem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Contagem de pedidos por status atual (criado, confirmado,
  /// despachado, em trânsito, entregue...). Alimenta o mini gráfico da
  /// tela inicial e os KPIs do Painel Analítico.
  Future<List<StatusContagem>> fetchEntregasPorStatus() async {
    final json = await _get('/analytics/deliveries');
    return (json as List<dynamic>)
        .map((e) => StatusContagem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Detecção de anomalias: compara a contagem de eventos de hoje com a
  /// média histórica dos últimos [diasHistorico] dias (z-score). Alimenta
  /// a seção de alertas do Painel Analítico.
  Future<AnomaliasResponse> fetchAnomalias({int diasHistorico = 30}) async {
    final json = await _get(
      '/analytics/anomalies?dias_historico=$diasHistorico',
    );
    return AnomaliasResponse.fromJson(json as Map<String, dynamic>);
  }
}
