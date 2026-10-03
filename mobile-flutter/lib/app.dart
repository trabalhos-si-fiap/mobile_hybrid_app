import 'package:flutter/material.dart';

import 'core/app_services.dart';
import 'core/session/session_gate.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/admin_dashboard_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/chatbot/presentation/assistant_screen.dart';
import 'features/notifications/presentation/notifications_screen.dart';
import 'features/tickets/domain/new_ticket_prefill.dart';
import 'features/tickets/presentation/my_tickets/my_tickets_screen.dart';
import 'features/tickets/presentation/new_ticket/new_ticket_screen.dart';
import 'features/tickets/presentation/ticket_detail/ticket_detail_screen.dart';

class EduApp extends StatelessWidget {
  const EduApp({super.key, required this.services});

  final AppServices services;

  static final _ticketRoute = RegExp(r'^/tickets/(\d+)$');

  /// Rotas com parâmetro: `/tickets/<id>` e `/tickets/new`, que recebe nos
  /// argumentos o preenchimento do Mentor Edu.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == '/tickets/new') {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) =>
            NewTicketScreen(prefill: settings.arguments as NewTicketPrefill?),
      );
    }
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
        '/home': (_) => const AdminDashboardScreen(),
        '/tickets': (_) => const MyTicketsScreen(),
        '/assistant': (_) => const AssistantScreen(),
        '/notifications': (_) => const NotificationsScreen(),
      },
      onGenerateRoute: onGenerateRoute,
    ),
  );
}
