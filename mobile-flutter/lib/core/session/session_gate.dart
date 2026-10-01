import 'dart:async';

import 'package:flutter/material.dart';

import '../app_services.dart';
import 'session.dart';

/// Rota inicial: quem já entrou (JWT ainda válido) vai direto para a sua
/// tela; os outros, para o login.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  @override
  void initState() {
    super.initState();
    unawaited(_decide());
  }

  Future<void> _decide() async {
    final services = AppScope.of(context);
    final token = await services.tokenStore.readAccessToken();
    final role = token == null ? null : readSession(token, services.clock());
    if (role == null) {
      await services.tokenStore.clear();
      await services.sessionStore.clear();
    } else if (role == UserRole.user) {
      unawaited(services.startUserSession());
    }
    if (!mounted) return;
    unawaited(
      Navigator.of(
        context,
      ).pushReplacementNamed(role == null ? '/login' : homeRouteFor(role)),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
