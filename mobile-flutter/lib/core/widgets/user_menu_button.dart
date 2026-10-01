import 'dart:async';

import 'package:flutter/material.dart';

import '../app_services.dart';

/// Menu da conta nas telas do usuário, com "Sair".
class UserMenuButton extends StatelessWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return PopupMenuButton<void>(
      key: const Key('user-menu'),
      tooltip: 'Conta',
      icon: const Icon(Icons.account_circle_outlined),
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          key: const Key('logout'),
          onTap: () => unawaited(services.logout()),
          child: const Text('Sair'),
        ),
      ],
    );
  }
}
