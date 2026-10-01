import 'dart:async';

import '../../../core/api/api_exception.dart';
import '../../../core/screen_controller.dart';
import '../data/notification_api.dart';
import '../domain/app_notification.dart';
import '../notification_center.dart';

class NotificationsController extends ScreenController {
  NotificationsController({required this._repository, required this._center});

  final NotificationRepository _repository;
  final NotificationCenter _center;

  /// Nulo enquanto carrega.
  List<AppNotification>? items;
  String? loadError;
  String? actionError;
  bool busy = false;

  bool get hasUnread => items?.any((n) => !n.read) ?? false;

  Future<void> load() async {
    loadError = null;
    notify();
    try {
      items = await _repository.list();
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.unauthorized) loadError = error.message;
    }
    notify();
  }

  /// Marca como lida (otimista) e diz qual ticket abrir. Se a marcação
  /// falhar, o item volta a não lido e nada é aberto.
  Future<({bool ok, int? ticketId})> open(AppNotification notification) async {
    actionError = null;
    if (notification.read) return (ok: true, ticketId: notification.ticketId);
    _replace(notification.copyWith(read: true));
    notify();
    try {
      await _repository.markRead(notification.id);
      unawaited(_center.refreshNow());
      return (ok: true, ticketId: notification.ticketId);
    } on ApiException catch (error) {
      _replace(notification);
      if (error.kind != ApiErrorKind.unauthorized) {
        actionError = 'Não foi possível marcar como lida. ${error.message}';
      }
      notify();
      return (ok: false, ticketId: null);
    }
  }

  Future<void> markAllRead() async {
    if (busy || !hasUnread) return;
    busy = true;
    actionError = null;
    notify();
    try {
      await _repository.markAllRead();
      items = [
        for (final n in items ?? const <AppNotification>[])
          n.copyWith(read: true),
      ];
      unawaited(_center.refreshNow());
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.unauthorized) actionError = error.message;
    } finally {
      busy = false;
      notify();
    }
  }

  void _replace(AppNotification updated) {
    items = [
      for (final n in items ?? const <AppNotification>[])
        n.id == updated.id ? updated : n,
    ];
  }
}
