import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/admin/presentation/admin_dashboard_screen.dart';

void main() {
  runApp(const MyApp());
}

/// Ponto de entrada do app. Abre direto o dashboard administrativo — o
/// fluxo de login/autenticação está fora de escopo por agora.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edu Admin',
      theme: AppTheme.light,
      home: const AdminDashboardScreen(),
    );
  }
}
