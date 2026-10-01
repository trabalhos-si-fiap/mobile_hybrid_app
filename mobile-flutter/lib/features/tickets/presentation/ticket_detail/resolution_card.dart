import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Pergunta ao usuário se o problema foi resolvido (status RESOLVIDO).
class ResolutionCard extends StatelessWidget {
  const ResolutionCard({
    super.key,
    required this.busy,
    required this.onConfirm,
    required this.onReopen,
  });

  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('resolution-card'),
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.greenSoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'O atendente marcou como resolvido. Seu problema foi resolvido?',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                key: const Key('confirm-resolution'),
                onPressed: busy ? null : onConfirm,
                child: const Text('Sim, encerrar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const Key('reopen-ticket'),
                onPressed: busy ? null : onReopen,
                child: const Text('Não, reabrir'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
