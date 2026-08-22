import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/admin_api.dart';
import '../domain/dashboard.dart';
import 'widgets/admin_scaffold.dart';
import 'widgets/admin_widgets.dart';

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
  late Future<DashboardResponse> _dataFuture;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _dataFuture = _api.fetchDashboard(days: 30);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      tab: AdminTab.dashboard,
      titulo: 'Painel Administrativo',
      body: RefreshIndicator(
        onRefresh: () async => _carregar(),
        child: FutureBuilder<DashboardResponse>(
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
                _CabecalhoResumo(dashboard: data),
                const SizedBox(height: 16),
                _GradeDashboard(dashboard: data),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Atividade educacional',
                  subtitle: 'Últimos 30 dias',
                  child: data.educational.activityHistory.isEmpty
                      ? const AdminEmptyState(
                          titulo: 'Nenhuma atividade registrada',
                          subtitulo:
                              'A atividade educacional aparecerá aqui assim que houver dados.',
                        )
                      : MiniBarChart(
                          data: {
                            for (final a in data.educational.activityHistory)
                              _rotuloData(a.date): a.studyActivities,
                          },
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
