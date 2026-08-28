import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/admin_api.dart';
import '../domain/dashboard.dart';
import 'widgets/admin_scaffold.dart';
import 'widgets/admin_widgets.dart';

// Tag exibida no canto das seções que têm gestão completa na versão web.
class _TagWebOnly extends StatelessWidget {
  const _TagWebOnly();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Gestão completa na versão web',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Tela inicial do modo Admin: relatório executivo, grade compacta de 7
/// métricas e gráfico reduzido de atividade educacional — tudo a partir
/// de uma única chamada a `GET /dashboard` na Edu Admin API.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _api = AdminApi();
  late Future<_DashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _dataFuture = Future.wait([
        _api.fetchDashboard(days: 30),
        _api.fetchLowStockTop3(),
        _api.fetchActiveCarriersTop3(),
        _api.fetchOpenOccurrencesTop3(),
      ]).then((results) => _DashboardData(
            dashboard: results[0] as DashboardResponse,
            lowStock: results[1] as List<InventoryItem>,
            carriers: results[2] as List<Carrier>,
            ocorrencias: results[3] as List<CarrierOccurrence>,
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      tab: AdminTab.dashboard,
      titulo: 'Painel Administrativo',
      body: RefreshIndicator(
        onRefresh: () async => _carregar(),
        child: FutureBuilder<_DashboardData>(
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
                    mensagem: 'Erro ao carregar o dashboard:\n${snapshot.error}',
                    onRetry: _carregar,
                  ),
                ],
              );
            }
            final data = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _CabecalhoResumo(dashboard: data.dashboard),
                const SizedBox(height: 16),
                _GradeDashboard(dashboard: data.dashboard),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Atividade educacional',
                  subtitle: 'Últimos 30 dias',
                  child: data.dashboard.educational.activityHistory.isEmpty
                      ? const AdminEmptyState(
                          titulo: 'Nenhuma atividade registrada',
                          subtitulo:
                              'A atividade educacional aparecerá aqui assim que houver dados.',
                        )
                      : MiniBarChart(
                          data: {
                            for (final a
                                in data.dashboard.educational.activityHistory)
                              _rotuloData(a.date): a.studyActivities,
                          },
                        ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Estoque baixo',
                  subtitle: 'Produtos com quantidade crítica',
                  trailing: const _TagWebOnly(),
                  child: data.lowStock.isEmpty
                      ? const AdminEmptyState(titulo: 'Nenhum produto em alerta')
                      : Column(
                          children: data.lowStock
                              .map((item) => EstoqueLinhaItem(item: item))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Transportadoras ativas',
                  subtitle: 'Top 3 do período',
                  trailing: const _TagWebOnly(),
                  child: data.carriers.isEmpty
                      ? const AdminEmptyState(titulo: 'Nenhuma transportadora')
                      : Column(
                          children: data.carriers
                              .map((c) => TransportadoraLinhaItem(carrier: c))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Ocorrências abertas',
                  subtitle: 'Aguardando resolução',
                  trailing: const _TagWebOnly(),
                  child: data.ocorrencias.isEmpty
                      ? const AdminEmptyState(titulo: 'Nenhuma ocorrência aberta')
                      : Column(
                          children: data.ocorrencias
                              .map((o) => OcorrenciaLinhaItem(ocorrencia: o))
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

class _DashboardData {
  const _DashboardData({
    required this.dashboard,
    required this.lowStock,
    required this.carriers,
    required this.ocorrencias,
  });

  final DashboardResponse dashboard;
  final List<InventoryItem> lowStock;
  final List<Carrier> carriers;
  final List<CarrierOccurrence> ocorrencias;
}

// ---------------------------------------------------------------------------
// Grade compacta de 7 métricas
// ---------------------------------------------------------------------------

/// Grade 2×N com as sete métricas do dashboard mobile compacto, todas
/// vindas de `GET /dashboard` (educational + operational).
class _GradeDashboard extends StatelessWidget {
  const _GradeDashboard({required this.dashboard});

  final DashboardResponse dashboard;

  @override
  Widget build(BuildContext context) {
    final edu = dashboard.educational;
    final ops = dashboard.operational;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      // Mesma proporção da grade anterior — ver comentário original em
      // _GradeMetricas sobre o motivo de 1.15 e não 1.5.
      childAspectRatio: 1.15,
      children: [
        AdminStatCard(
          icon: Icons.school_outlined,
          label: 'Alunos cadastrados',
          value: '${edu.registeredStudents}',
        ),
        AdminStatCard(
          icon: Icons.person_outline,
          label: 'Alunos ativos',
          value: '${edu.activeStudents}',
        ),
        AdminStatCard(
          icon: Icons.person_add_outlined,
          label: 'Novos cadastros',
          value: '${edu.newRegistrations}',
        ),
        AdminStatCard(
          icon: Icons.warning_amber_outlined,
          label: 'Alunos em risco',
          value: '${edu.inactiveRiskStudents}',
          badge: edu.inactiveRiskStudents > 0 ? 'Atenção' : null,
          badgeColor: AppColors.danger,
        ),
        AdminStatCard(
          icon: Icons.inventory_2_outlined,
          label: 'Estoque baixo',
          value: '${ops.lowStockProducts}',
          badge: ops.lowStockProducts > 0 ? 'Atenção' : null,
          badgeColor: AppColors.danger,
        ),
        AdminStatCard(
          icon: Icons.local_shipping_outlined,
          label: 'Transportadoras ativas',
          value: '${ops.activeCarriers}',
        ),
        AdminStatCard(
          icon: Icons.report_problem_outlined,
          label: 'Ocorrências abertas',
          value: '${ops.openOccurrences}',
          badge: ops.openOccurrences > 0 ? 'Atenção' : null,
          badgeColor: AppColors.danger,
        ),
      ],
    );
  }
}

/// Texto do relatório executivo devolvido por `GET /dashboard`
/// (`executiveSummary`, gerado no backend a partir das métricas do
/// período).
class _CabecalhoResumo extends StatelessWidget {
  const _CabecalhoResumo({required this.dashboard});

  final DashboardResponse dashboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.purple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'RELATÓRIO EXECUTIVO',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            dashboard.executiveSummary,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rótulo curto (`DD/MM`) para o eixo do mini gráfico a partir de uma data
/// `AAAA-MM-DD` (serialização padrão de `LocalDate`).
String _rotuloData(String isoDate) {
  final partes = isoDate.split('-');
  if (partes.length != 3) return isoDate;
  return '${partes[2]}/${partes[1]}';
}
