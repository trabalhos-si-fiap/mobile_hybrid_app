import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/admin_api.dart';
import '../domain/analytics.dart';
import 'widgets/admin_scaffold.dart';
import 'widgets/admin_widgets.dart';

/// Painel Analítico: KPIs vindos de GET /analytics/summary (eventos por
/// tipo) e GET /analytics/deliveries (pedidos por status), mais a lista de
/// anomalias de GET /analytics/anomalies.
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _api = AdminApi();
  late Future<_PainelData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _dataFuture = _carregarDados();
    });
  }

  Future<_PainelData> _carregarDados() async {
    final eventos = await _api.fetchResumoEventos();
    final entregas = await _api.fetchEntregasPorStatus();
    final anomalias = await _api.fetchAnomalias(diasHistorico: 30);
    return _PainelData(
      eventos: eventos,
      entregasPorStatus: entregas,
      anomalias: anomalias,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      tab: AdminTab.painel,
      titulo: 'Painel Analítico',
      body: RefreshIndicator(
        onRefresh: () async => _carregar(),
        child: FutureBuilder<_PainelData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  AdminErrorState(
                    mensagem: 'Erro ao carregar o painel:\n${snapshot.error}',
                    onRetry: _carregar,
                  ),
                ],
              );
            }
            final data = snapshot.data!;
            final totalEventos = data.eventos.fold<int>(
              0,
              (a, e) => a + e.total,
            );
            final totalPedidos = data.entregasPorStatus.fold<int>(
              0,
              (a, s) => a + s.total,
            );
            final entregues = data.entregasPorStatus
                .where((s) => s.status == 'ENTREGUE')
                .fold<int>(0, (a, s) => a + s.total);
            final taxaEntrega = totalPedidos == 0
                ? 0.0
                : (entregues / totalPedidos) * 100;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // Mesma altura do dashboard — ver o comentário em
                  // admin_dashboard_screen.dart.
                  childAspectRatio: 1.15,
                  children: [
                    AdminStatCard(
                      icon: Icons.event_note_outlined,
                      label: 'Eventos registrados',
                      value: '$totalEventos',
                    ),
                    AdminStatCard(
                      icon: Icons.local_shipping_outlined,
                      label: 'Pedidos no período',
                      value: '$totalPedidos',
                    ),
                    AdminStatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Taxa de entrega',
                      value: '${taxaEntrega.toStringAsFixed(0)}%',
                      badge: taxaEntrega >= 80 ? 'Excelente' : null,
                      badgeColor: AppColors.success,
                    ),
                    AdminStatCard(
                      icon: Icons.warning_amber_outlined,
                      label: 'Anomalias detectadas',
                      value:
                          '${data.anomalias.resultados.where((a) => a.anomalia).length}',
                      badge: data.anomalias.resultados.any((a) => a.anomalia)
                          ? 'Revisar'
                          : null,
                      badgeColor: AppColors.danger,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Eventos por tipo',
                  subtitle: 'Event log completo (sem filtro de período)',
                  child: data.eventos.isEmpty
                      ? const AdminEmptyState(
                          titulo: 'Nenhum evento registrado',
                          subtitulo:
                              'Os eventos aparecerão aqui assim que houver atividade.',
                        )
                      : MiniBarChart(
                          height: 160,
                          data: {
                            for (final e in data.eventos.take(6))
                              _abreviarTipoEvento(e.tipo): e.total,
                          },
                        ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Anomalias',
                  subtitle:
                      'Comparado à média dos últimos ${data.anomalias.diasHistorico} dias',
                  child: data.anomalias.resultados.isEmpty
                      ? const AdminEmptyState(
                          titulo: 'Nenhum histórico suficiente ainda.',
                          subtitulo:
                              'São necessários dados de pelo menos alguns dias para detectar anomalias.',
                        )
                      : Column(
                          children: data.anomalias.resultados
                              .map((a) => _LinhaAnomalia(anomalia: a))
                              .toList(),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PainelData {
  const _PainelData({
    required this.eventos,
    required this.entregasPorStatus,
    required this.anomalias,
  });

  final List<TipoContagem> eventos;
  final List<StatusContagem> entregasPorStatus;
  final AnomaliasResponse anomalias;
}

class _LinhaAnomalia extends StatelessWidget {
  const _LinhaAnomalia({required this.anomalia});

  final Anomalia anomalia;

  @override
  Widget build(BuildContext context) {
    final cor = anomalia.anomalia ? AppColors.danger : AppColors.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            anomalia.anomalia
                ? Icons.priority_high_rounded
                : Icons.check_circle_outline,
            color: cor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _abreviarTipoEvento(anomalia.tipoEvento),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Hoje: ${anomalia.contagemHoje} · média histórica: '
                  '${anomalia.mediaHistorica.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (anomalia.zScore != null)
            Text(
              'z=${anomalia.zScore!.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cor,
              ),
            ),
        ],
      ),
    );
  }
}

/// Os tipos de evento no event log seguem o padrão `dominio.acao`
/// (order.created, diagnostic.answered...) — mostra só a última parte pra
/// caber no mini gráfico e nas linhas de anomalia.
String _abreviarTipoEvento(String tipo) {
  final partes = tipo.split('.');
  return partes.length > 1 ? partes.last : tipo;
}
