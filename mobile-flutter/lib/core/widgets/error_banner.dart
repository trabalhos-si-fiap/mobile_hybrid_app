import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Faixa de erro. [subtle] é a variante discreta do polling sem conexão.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.subtle = false,
    this.actionLabel = 'Tentar de novo',
  });

  final String message;
  final VoidCallback? onRetry;
  final bool subtle;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final color = subtle ? AppColors.textSecondary : AppColors.danger;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: subtle ? AppColors.inputFill : const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              subtle ? Icons.cloud_off_outlined : Icons.error_outline,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 13, color: color),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(actionLabel),
              ),
          ],
        ),
      ),
    );
  }
}
