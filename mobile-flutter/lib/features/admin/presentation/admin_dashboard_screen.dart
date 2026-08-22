import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/admin_api.dart';
import '../domain/analytics.dart';
import 'widgets/admin_scaffold.dart';
import 'widgets/admin_widgets.dart';

/// Tela inicial do modo Admin: relatório executivo (GET
/// /analytics/executive-summary), grade compacta de 7 métricas, mini
/// gráfico de pedidos por status, e placeholders para seções sem API ainda
/// (alunos, estoque baixo, transportadoras — aguardando Admin API Java).
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
      _dataFuture = _carregarDados();
    });
  }

  Future<_DashboardData> _carregarDados() async {
    // As duas chamadas são independentes — busca em paralelo pra tela não
    // demorar o dobro do tempo esperando uma depois da outra.
    final resumo = await _api.fetchResumoExecutivo(dias: 7);
    final entregas = await _api.fetchEntregasPorStatus();
    return _DashboardData(resumo: resumo, entregasPorStatus: entregas);
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
                _CabecalhoResumo(resumo: data.resumo),
                const SizedBox(height: 16),
                _GradeDashboard(resumo: data.resumo),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Pedidos por status',
                  subtitle: 'Últimos 7 dias',
                  child: data.entregasPorStatus.isEmpty
                      ? const AdminEmptyState(
                          titulo: 'Nenhum pedido registrado',
                          subtitulo: 'Os pedidos aparecerão aqui assim que forem criados.',
                        )
                      : MiniBarChart(
                          data: {
                            for (final s in data.entregasPorStatus)
                              _rotuloStatus(s.status): s.total,
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

class _DashboardData {
  const _DashboardData({required this.resumo, required this.entregasPorStatus});

  final ResumoExecutivo resumo;
  final List<StatusContagem> entregasPorStatus;
}

// ---------------------------------------------------------------------------
// Grade compacta de 7 métricas
// ---------------------------------------------------------------------------

/// Grade 2×N com as sete métricas do dashboard mobile compacto.
///
/// Métricas provenientes do analytics-service (Python) são populadas em
/// tempo real. Métricas que dependem da Admin API Java (alunos, estoque
/// baixo, transportadoras) exibem '--' com badge 'Aguard. API' até a
/// integração ser feita.
class _GradeDashboard extends StatelessWidget {
  const _GradeDashboard({required this.resumo});

  final ResumoExecutivo resumo;

  @override
  Widget build(BuildContext context) {
    final m = resumo.metricas;
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
        // ── Métricas educacionais (Admin API Java — pendente) ──────────────
        AdminStatCard(
          icon: Icons.school_outlined,
          label: 'Alunos cadastrados',
          value: '--',
          badge: 'Aguard. API',
          badgeColor: AppColors.textSecondary,
        ),
        AdminStatCard(
          icon: Icons.person_outline,
          label: 'Alunos ativos',
          value: '--',
          badge: 'Aguard. API',
          badgeColor: AppColors.textSecondary,
        ),
        AdminStatCard(
          icon: Icons.person_add_outlined,
          label: 'Novos cadastros',
          value: '--',
          badge: 'Aguard. API',
          badgeColor: AppColors.textSecondary,
        ),
        AdminStatCard(
          icon: Icons.warning_amber_outlined,
          label: 'Alunos em risco',
          value: '--',
          badge: 'Aguard. API',
          badgeColor: AppColors.textSecondary,
        ),
        // ── Métricas de estoque/logística (Admin API Java — pendente) ──────
        AdminStatCard(
          icon: Icons.inventory_2_outlined,
          label: 'Estoque baixo',
          value: '--',
          badge: 'Aguard. API',
          badgeColor: AppColors.textSecondary,
        ),
        AdminStatCard(
          icon: Icons.local_shipping_outlined,
          label: 'Transportadoras ativas',
          value: '--',
          badge: 'Aguard. API',
          badgeColor: AppColors.textSecondary,
        ),
        // ── Ocorrências abertas — analytics-service (real) ─────────────────
        AdminStatCard(
          icon: Icons.report_problem_outlined,
          label: 'Ocorrências abertas',
          value: '${m.ocorrenciasAbertas}',
          badge: m.ocorrenciasAbertas > 0 ? 'Atenção' : null,
          badgeColor: AppColors.danger,
        ),
      ],
    );
  }
}

/// Texto do relatório executivo, gerado por LLM no backend
/// (analytics-service/app/services/resumo_ia.py) a partir das métricas do
/// período.
class _CabecalhoResumo extends StatelessWidget {
  const _CabecalhoResumo({required this.resumo});

  final ResumoExecutivo resumo;

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
          Row(
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
              const Spacer(),
              Text(
                'Últimos ${resumo.periodoDias} dias',
                style: const TextStyle(color: AppColors.background, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            resumo.resumoExecutivo,
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

String _rotuloStatus(String status) {
  // Valores reais de back-end/commerce-service/app/services/status_pedido.py
  // (StatusPedido enum) — string, maiúscula, sem tradução pro Flutter
  // porque o analytics-service não serve o app do aluno.
  const rotulos = {
    'CRIADO': 'Criado',
    'AGUARDANDO_SEPARACAO': 'Ag. separ.',
    'EM_SEPARACAO': 'Separando',
    'SEPARADO': 'Separado',
    'AGUARDANDO_COLETA': 'Ag. coleta',
    'EM_TRANSITO': 'Trânsito',
    'ENTREGUE': 'Entregue',
    'CANCELADO': 'Cancelado',
  };
  return rotulos[status] ?? status;
}
