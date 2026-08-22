/// Modelos espelhando back-end/analytics-service/app/schemas/analytics.py.
/// Todos os campos do JSON continuam em português (o analytics-service não
/// tem cliente HTTP externo além deste painel admin, então não seguiu a
/// tradução aplicada em commerce/learning para o Flutter do aluno).
library;

/// GET /analytics/executive-summary
class ResumoExecutivo {
  const ResumoExecutivo({
    required this.periodoDias,
    required this.metricas,
    required this.resumoExecutivo,
  });

  factory ResumoExecutivo.fromJson(Map<String, dynamic> json) {
    return ResumoExecutivo(
      periodoDias: json['periodo_dias'] as int,
      metricas: ResumoMetricas.fromJson(
        json['metricas'] as Map<String, dynamic>,
      ),
      resumoExecutivo: json['resumo_executivo'] as String,
    );
  }

  final int periodoDias;
  final ResumoMetricas metricas;
  final String resumoExecutivo;
}

class ResumoMetricas {
  const ResumoMetricas({
    required this.pedidosCriados,
    required this.pedidosPorStatus,
    required this.ocorrenciasAbertas,
    required this.ocorrenciasResolvidas,
    required this.diagnosticosPorAcao,
  });

  factory ResumoMetricas.fromJson(Map<String, dynamic> json) {
    return ResumoMetricas(
      pedidosCriados: json['pedidos_criados'] as int? ?? 0,
      pedidosPorStatus: _intMap(json['pedidos_por_status']),
      ocorrenciasAbertas: json['ocorrencias_abertas'] as int? ?? 0,
      ocorrenciasResolvidas: json['ocorrencias_resolvidas'] as int? ?? 0,
      diagnosticosPorAcao: _intMap(json['diagnosticos_por_acao']),
    );
  }

  final int pedidosCriados;
  final Map<String, int> pedidosPorStatus;
  final int ocorrenciasAbertas;
  final int ocorrenciasResolvidas;
  final Map<String, int> diagnosticosPorAcao;
}

Map<String, int> _intMap(dynamic raw) {
  if (raw is! Map) return const {};
  return raw.map(
    (key, value) => MapEntry(key.toString(), (value as num).toInt()),
  );
}

/// GET /analytics/summary — contagem de eventos por tipo (event log bruto).
class TipoContagem {
  const TipoContagem({required this.tipo, required this.total});

  factory TipoContagem.fromJson(Map<String, dynamic> json) {
    return TipoContagem(
      tipo: json['tipo'] as String,
      total: json['total'] as int,
    );
  }

  final String tipo;
  final int total;
}

/// GET /analytics/deliveries — contagem de pedidos por status.
class StatusContagem {
  const StatusContagem({required this.status, required this.total});

  factory StatusContagem.fromJson(Map<String, dynamic> json) {
    return StatusContagem(
      status: json['status'] as String? ?? 'desconhecido',
      total: json['total'] as int,
    );
  }

  final String status;
  final int total;
}

/// GET /analytics/anomalies
class AnomaliasResponse {
  const AnomaliasResponse({
    required this.diasHistorico,
    required this.resultados,
  });

  factory AnomaliasResponse.fromJson(Map<String, dynamic> json) {
    return AnomaliasResponse(
      diasHistorico: json['dias_historico'] as int,
      resultados: (json['resultados'] as List<dynamic>)
          .map((e) => Anomalia.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int diasHistorico;
  final List<Anomalia> resultados;
}

class Anomalia {
  const Anomalia({
    required this.tipoEvento,
    required this.contagemHoje,
    required this.mediaHistorica,
    required this.desvioHistorico,
    required this.zScore,
    required this.anomalia,
    required this.diasHistoricoUsados,
  });

  factory Anomalia.fromJson(Map<String, dynamic> json) {
    return Anomalia(
      tipoEvento: json['tipo_evento'] as String,
      contagemHoje: json['contagem_hoje'] as int,
      mediaHistorica: (json['media_historica'] as num).toDouble(),
      desvioHistorico: (json['desvio_historico'] as num).toDouble(),
      zScore: (json['z_score'] as num?)?.toDouble(),
      anomalia: json['anomalia'] as bool,
      diasHistoricoUsados: json['dias_historico_usados'] as int,
    );
  }

  final String tipoEvento;
  final int contagemHoje;
  final double mediaHistorica;
  final double desvioHistorico;
  final double? zScore;
  final bool anomalia;
  final int diasHistoricoUsados;
}
