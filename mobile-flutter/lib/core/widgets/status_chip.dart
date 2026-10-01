import 'package:flutter/material.dart';

import '../../features/tickets/domain/ticket_models.dart';
import '../../features/tickets/domain/ticket_rules.dart';
import '../theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (statusTone(status)) {
      StatusTone.waiting => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      StatusTone.priority => (const Color(0xFFFFEDD5), const Color(0xFF9A3412)),
      StatusTone.active => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      StatusTone.resolved => (AppColors.greenSoft, AppColors.greenDark),
      StatusTone.closed => (const Color(0xFFE5E7EB), const Color(0xFF374151)),
    };
    return Container(
      key: const Key('status-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
