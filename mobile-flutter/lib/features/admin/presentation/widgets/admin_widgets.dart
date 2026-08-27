import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/dashboard.dart';

/// Card de estatística única (ex: "Pedidos criados", "1.284"), no estilo
/// dos cards do mockup de referência.
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.purpleSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.purple, size: 18),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? AppColors.success).withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: badgeColor ?? AppColors.greenDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          // Espaço elástico no lugar de um `SizedBox` fixo: a célula do grid
          // tem altura fechada, e uma folga rígida entre o ícone e o valor
          // era o que sobrava para estourar quando o rótulo quebrava em duas
          // linhas ("BOTTOM OVERFLOWED BY 44 PIXELS", com o número cortado
          // ao meio). Com o `Spacer` a folga cede antes do conteúdo.
          const Spacer(),
          // O valor encolhe em vez de vazar; `scaleDown` só reduz, então em
          // caixa larga ele continua nos 22px do desenho.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Duas linhas no máximo: rótulos como "Ocorrências resolvidas"
          // quebram, e sem o limite a terceira linha volta a estourar.
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Container de seção com título, usado para agrupar cada bloco da tela
/// (gráfico, resumo executivo, estoque, transportadoras...).
class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Mini gráfico de barras verticais construído com widgets simples (sem
/// dependência de chart lib — o pubspec.yaml do projeto não tem nenhuma).
/// Usado tanto na tela inicial ("Tendência") quanto no Painel Analítico.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({super.key, required this.data, this.height = 120});

  /// Rótulo curto -> valor. A barra mais alta vira a cor de destaque.
  final Map<String, int> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'Sem dados suficientes ainda',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      );
    }
    final maxValue = data.values.reduce((a, b) => a > b ? a : b);
    final maxKey = data.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.entries.map((entry) {
          final destaque = entry.key == maxKey;
          final fracao = maxValue == 0 ? 0.0 : entry.value / maxValue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // O `Expanded` é obrigatório, não estilo: um `Column` dá
                  // altura ILIMITADA aos filhos, e infinito vezes o
                  // `heightFactor` continua infinito — o layout estoura com
                  // "BoxConstraints forces an infinite height" e a árvore
                  // inteira do painel deixa de pintar. `Expanded` fecha a
                  // altura no espaço que sobra da coluna, e é sobre ela que
                  // a fração passa a ser calculada. `bottomCenter` mantém a
                  // barra crescendo de baixo para cima (o padrão do
                  // FractionallySizedBox é centralizar).
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: fracao.clamp(0.04, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: destaque
                              ? AppColors.purple
                              : AppColors.purpleSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.key,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Bloco "em desenvolvimento" / "em breve" para seções sem backend ainda
/// (estoque e transportadoras) — deixa claro que é intencional, não um
/// erro de carregamento.
class AdminComingSoon extends StatelessWidget {
  const AdminComingSoon({
    super.key,
    required this.icon,
    required this.mensagem,
    required this.tag,
  });

  final IconData icon;
  final String mensagem;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            mensagem,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            tag,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
/// Estado vazio reutilizado quando uma chamada retorna lista vazia ou
/// resultado sem dados (ex: nenhum evento registrado ainda).
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.titulo,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitulo!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Linhas de lista para estoque, transportadoras e ocorrências
// ---------------------------------------------------------------------------

/// Uma linha de produto com estoque baixo.
class EstoqueLinhaItem extends StatelessWidget {
  const EstoqueLinhaItem({super.key, required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final critico = item.quantity == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: critico
                  ? AppColors.danger.withValues(alpha: 0.12)
                  : AppColors.star.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: critico ? AppColors.danger : AppColors.star,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'SKU ${item.sku}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.quantity} un.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: critico ? AppColors.danger : AppColors.star,
                ),
              ),
              Text(
                'mín. ${item.minimumStock}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Uma linha de transportadora.
class TransportadoraLinhaItem extends StatelessWidget {
  const TransportadoraLinhaItem({super.key, required this.carrier});

  final Carrier carrier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.purpleSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              size: 18,
              color: AppColors.purple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  carrier.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'SLA ${carrier.slaPercentage.toStringAsFixed(1)}%  •  '
                  '${carrier.averageDeliveryDays}d avg',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: AppColors.star),
              const SizedBox(width: 2),
              Text(
                carrier.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Uma linha de ocorrência aberta.
class OcorrenciaLinhaItem extends StatelessWidget {
  const OcorrenciaLinhaItem({super.key, required this.ocorrencia});

  final CarrierOccurrence ocorrencia;

  static const _tipoLabel = {
    'DELIVERY_DELAY': 'Atraso',
    'DAMAGE': 'Avaria',
    'DELIVERY_FAILURE': 'Falha na entrega',
    'OTHER': 'Outro',
  };

  @override
  Widget build(BuildContext context) {
    final label = _tipoLabel[ocorrencia.type] ?? ocorrencia.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.report_problem_outlined,
              size: 18,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ocorrencia.carrierName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ABERTA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado de erro reutilizado quando uma chamada ao analytics-service
/// falha (ex: 403 se o JWT não tiver role=admin).
class AdminErrorState extends StatelessWidget {
  const AdminErrorState({
    super.key,
    required this.mensagem,
    required this.onRetry,
  });

  final String mensagem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}
