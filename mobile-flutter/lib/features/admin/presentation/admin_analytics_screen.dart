import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../data/admin_api.dart';
import '../domain/dashboard.dart';
import 'widgets/admin_scaffold.dart';
import 'widgets/admin_widgets.dart';

/// Painel Analítico: KPIs operacionais reais vindos de `GET /carriers`,
/// `GET /carrier-occurrences` e `GET /inventory` (estoque baixo) na Edu
/// Admin API — substitui as antigas anomalias/eventos do
/// analytics-service Python, que não existe neste backend.
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
    // As três chamadas são independentes — busca em paralelo pra tela não
    // demorar o triplo do tempo esperando uma depois da outra.
    final results = await Future.wait([
      _api.fetchCarriers(),
      _api.fetchOccurrences(),
      _api.fetchInventory(lowStock: true),
    ]);
    return _PainelData(
      carriers: results[0] as List<Carrier>,
      occurrences: results[1] as List<CarrierOccurrence>,
      lowStock: results[2] as List<InventoryItem>,
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
            final ativas = data.carriers
                .where((c) => c.status == 'ACTIVE')
                .toList();
            final slaMedio = ativas.isEmpty
                ? 0.0
                : ativas.fold<double>(0, (a, c) => a + c.slaPercentage) /
                      ativas.length;
            final abertas = data.occurrences
                .where((o) => o.status == 'OPEN')
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const _BannerDashboardWeb(),
                const SizedBox(height: 16),
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
                      icon: Icons.local_shipping_outlined,
                      label: 'Transportadoras ativas',
                      value: '${ativas.length}',
                    ),
                    AdminStatCard(
                      icon: Icons.check_circle_outline,
                      label: 'SLA médio',
                      value: '${slaMedio.toStringAsFixed(0)}%',
                      badge: slaMedio >= 90 ? 'Excelente' : null,
                      badgeColor: AppColors.success,
                    ),
                    AdminStatCard(
                      icon: Icons.report_problem_outlined,
                      label: 'Ocorrências abertas',
                      value: '$abertas',
                      badge: abertas > 0 ? 'Atenção' : null,
                      badgeColor: AppColors.danger,
                    ),
                    AdminStatCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Produtos c/ estoque baixo',
                      value: '${data.lowStock.length}',
                      badge: data.lowStock.isNotEmpty ? 'Atenção' : null,
                      badgeColor: AppColors.danger,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Ocorrências por tipo',
                  subtitle: 'Todas as transportadoras',
                  child: data.occurrences.isEmpty
                      ? const AdminEmptyState(
                          titulo: 'Nenhuma ocorrência registrada',
                          subtitulo:
                              'As ocorrências aparecerão aqui assim que forem criadas.',
                        )
                      : MiniBarChart(
                          height: 160,
                          data: _contarPorTipo(data.occurrences),
                        ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Transportadoras',
                  subtitle: 'Rating, SLA e prazo médio de entrega',
                  child: data.carriers.isEmpty
                      ? const AdminEmptyState(
                          titulo: 'Nenhuma transportadora cadastrada.',
                          subtitulo:
                              'As transportadoras cadastradas aparecerão aqui.',
                        )
                      : Column(
                          children: data.carriers
                              .map((c) => _LinhaTransportadora(carrier: c))
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
    required this.carriers,
    required this.occurrences,
    required this.lowStock,
  });

  final List<Carrier> carriers;
  final List<CarrierOccurrence> occurrences;
  final List<InventoryItem> lowStock;
}

class _LinhaTransportadora extends StatelessWidget {
  const _LinhaTransportadora({required this.carrier});

  final Carrier carrier;

  @override
  Widget build(BuildContext context) {
    final ativa = carrier.status == 'ACTIVE';
    final cor = ativa ? AppColors.success : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            ativa ? Icons.local_shipping : Icons.local_shipping_outlined,
            color: cor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  carrier.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Rating: ${carrier.rating.toStringAsFixed(1)} · '
                  'Prazo médio: ${carrier.averageDeliveryDays} dias',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'SLA ${carrier.slaPercentage.toStringAsFixed(0)}%',
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

/// Agrupa as ocorrências por [OccurrenceType] e devolve rótulo curto ->
/// contagem, para alimentar o `MiniBarChart`.
Map<String, int> _contarPorTipo(List<CarrierOccurrence> occurrences) {
  final contagem = <String, int>{};
  for (final o in occurrences) {
    final rotulo = _rotuloTipoOcorrencia(o.type);
    contagem[rotulo] = (contagem[rotulo] ?? 0) + 1;
  }
  return contagem;
}

String _rotuloTipoOcorrencia(String type) {
  // Valores reais de api/src/main/java/com/edu/api/occurrence/entity/OccurrenceType.java.
  const rotulos = {
    'DELIVERY_DELAY': 'Atraso',
    'DAMAGE': 'Avaria',
    'DELIVERY_FAILURE': 'Falha entrega',
    'OTHER': 'Outro',
  };
  return rotulos[type] ?? type;
}

class _BannerDashboardWeb extends StatelessWidget {
  const _BannerDashboardWeb();

  static const _url = 'http://localhost:4200';

  Future<void> _abrir() async {
    if (_url.isEmpty) return;
    final uri = Uri.parse(_url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.purple,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _abrir,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.open_in_browser, color: AppColors.white, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard administrativo completo',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Acesse a versão web para gestão completa',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
