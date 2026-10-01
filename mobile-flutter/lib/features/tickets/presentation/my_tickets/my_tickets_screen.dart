import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/user_menu_button.dart';
import '../../../notifications/presentation/bell_button.dart';
import '../../domain/ticket_models.dart';
import '../../domain/ticket_rules.dart';
import 'my_tickets_controller.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> with RouteAware {
  late final MyTicketsController _controller;
  RouteObserver<ModalRoute<void>>? _observer;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    _controller = MyTicketsController(
      repository: services.tickets,
      center: services.notificationCenter,
    )..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_observer != null) return;
    final route = ModalRoute.of(context);
    if (route == null) return;
    _observer = AppScope.of(context).routeObserver..subscribe(this, route);
  }

  @override
  void didPopNext() => unawaited(_controller.reload());

  @override
  void dispose() {
    _observer?.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  void _go(String route) => unawaited(Navigator.of(context).pushNamed(route));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus tickets'),
        actions: const [BellButton(), UserMenuButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-ticket-button'),
        onPressed: () => _go('/tickets/new'),
        icon: const Icon(Icons.add),
        label: const Text('Abrir ticket'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final now = AppScope.of(context).clock();
          final tickets = _controller.tickets;
          final loadError = _controller.loadError;
          return RefreshIndicator(
            onRefresh: _controller.reload,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (_controller.offline)
                  const ErrorBanner(
                    message: 'Sem conexão. Tentando de novo…',
                    subtle: true,
                  ),
                if (loadError != null && _controller.forbidden)
                  ErrorBanner(
                    message: loadError,
                    actionLabel: 'Sair',
                    onRetry: () => unawaited(AppScope.of(context).logout()),
                  )
                else if (loadError != null)
                  ErrorBanner(message: loadError, onRetry: _controller.reload),
                if (tickets == null && loadError == null) const _LoadingCards(),
                if (tickets != null && tickets.isEmpty)
                  _EmptyState(onOpen: () => _go('/tickets/new')),
                for (final ticket in tickets ?? const <TicketSummary>[])
                  _TicketCard(
                    ticket: ticket,
                    now: now,
                    onTap: () => _go('/tickets/${ticket.id}'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.now,
    required this.onTap,
  });

  final TicketSummary ticket;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const secondary = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    return Card(
      key: Key('ticket-card-${ticket.id}'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${ticket.id} · ${ticket.segmentLabel}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusChip(status: ticket.status),
                ],
              ),
              if (ticket.status == TicketStatus.resolvido)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Confirme a solução',
                    style: TextStyle(
                      color: AppColors.greenDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(assigneeText(ticket.assigneeName), style: secondary),
              const SizedBox(height: 4),
              Text(
                'Atualizado ${relativeTime(ticket.updatedAt, now)}',
                style: secondary.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Carregando tickets',
    excludeSemantics: true,
    child: Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            height: 96,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 64, 32, 0),
    child: Column(
      children: [
        const Icon(
          Icons.support_agent,
          size: 56,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 16),
        const Text(
          'Você ainda não abriu tickets',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Toque em "Abrir ticket" para falar com o suporte.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onOpen, child: const Text('Abrir ticket')),
      ],
    ),
  );
}
