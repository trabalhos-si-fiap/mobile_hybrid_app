import 'package:flutter/material.dart';

import '../../../core/app_services.dart';

/// Sino da AppBar com o contador de não lidas do NotificationCenter.
class BellButton extends StatelessWidget {
  const BellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final center = AppScope.of(context).notificationCenter;
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) {
        final count = center.unreadCount;
        final label = switch (count) {
          0 => 'Notificações',
          1 => '1 notificação não lida',
          _ => '${center.badgeLabel} notificações não lidas',
        };
        return Semantics(
          label: label,
          button: true,
          excludeSemantics: true,
          child: IconButton(
            key: const Key('bell'),
            tooltip: 'Notificações',
            onPressed: () => Navigator.of(context).pushNamed('/notifications'),
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text(center.badgeLabel, key: const Key('unread-count')),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        );
      },
    );
  }
}
