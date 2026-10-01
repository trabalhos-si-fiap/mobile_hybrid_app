import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/error_banner.dart';
import '../domain/app_notification.dart';
import 'notifications_controller.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsController _controller;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    _controller = NotificationsController(
      repository: services.notifications,
      center: services.notificationCenter,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(AppNotification notification) async {
    final result = await _controller.open(notification);
    final ticketId = result.ticketId;
    if (!mounted || !result.ok || ticketId == null) return;
    await Navigator.of(context).pushNamed('/tickets/$ticketId');
    if (mounted) unawaited(_controller.load());
  }

  @override
  Widget build(BuildContext context) {
    final now = AppScope.of(context).clock();
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final items = _controller.items;
        final loadError = _controller.loadError;
        final actionError = _controller.actionError;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notificações'),
            actions: [
              TextButton(
                key: const Key('mark-all-read'),
                onPressed: _controller.hasUnread && !_controller.busy
                    ? _controller.markAllRead
                    : null,
                child: const Text('Marcar todas como lidas'),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _controller.load,
            child: ListView(
              children: [
                if (actionError != null) ErrorBanner(message: actionError),
                if (loadError != null)
                  ErrorBanner(message: loadError, onRetry: _controller.load),
                if (items == null && loadError == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (items != null && items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Nenhuma notificação.')),
                  ),
                for (final notification in items ?? const <AppNotification>[])
                  _NotificationTile(
                    key: Key('notification-${notification.id}'),
                    notification: notification,
                    now: now,
                    onTap: () => _open(notification),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    super.key,
    required this.notification,
    required this.now,
    required this.onTap,
  });

  final AppNotification notification;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    return ListTile(
      tileColor: unread ? AppColors.purpleSoft : AppColors.white,
      leading: Icon(
        unread ? Icons.mark_email_unread_outlined : Icons.drafts_outlined,
        color: unread ? AppColors.purple : AppColors.textSecondary,
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      subtitle: Text(notification.body),
      trailing: Text(
        relativeTime(notification.createdAt, now),
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      onTap: onTap,
    );
  }
}
