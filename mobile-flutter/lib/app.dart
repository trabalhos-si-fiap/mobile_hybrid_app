import 'package:flutter/material.dart';

import 'core/app_services.dart';
import 'core/session/session_gate.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/admin_dashboard_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'features/notifications/presentation/notifications_screen.dart';
import 'features/tickets/presentation/my_tickets/my_tickets_screen.dart';
import 'features/tickets/presentation/new_ticket/new_ticket_screen.dart';
import 'features/tickets/presentation/ticket_detail/ticket_detail_screen.dart';

class EduApp extends StatelessWidget {
  const EduApp({super.key, required this.services});

  final AppServices services;

  static final _ticketRoute = RegExp(r'^/tickets/(\d+)$');

  /// Rotas com parâmetro: `/tickets/<id>`.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final match = _ticketRoute.firstMatch(settings.name ?? '');
    if (match == null) return null;
    final ticketId = int.parse(match.group(1)!);
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => TicketDetailScreen(ticketId: ticketId),
    );
  }

  @override
  Widget build(BuildContext context) => AppScope(
    services: services,
    child: MaterialApp(
      title: 'Edu Admin',
      theme: AppTheme.light,
      navigatorKey: services.navigatorKey,
      navigatorObservers: [services.routeObserver],
      initialRoute: '/',
      routes: {
        '/': (_) => const SessionGate(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/forgot-password': (_) => ForgotPasswordScreen(),
        '/reset-password': (_) => ResetPasswordScreen(),
        '/home': (_) => const AdminDashboardScreen(),
        '/tickets': (_) => const MyTicketsScreen(),
        '/tickets/new': (_) => const NewTicketScreen(),
        '/notifications': (_) => const NotificationsScreen(),
      },
      onGenerateRoute: onGenerateRoute,
    ),
  );
}
