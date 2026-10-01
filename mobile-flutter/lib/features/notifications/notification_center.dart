import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../core/polling/poller.dart';
import 'data/notification_api.dart';
import 'domain/app_notification.dart';
import 'local_notifier.dart';

/// Enquanto a sessão USER está ativa, consulta as não lidas a cada 30 s,
/// mantém o contador do sino e vira notificação local o que chegou depois da
/// primeira consulta.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter({
    required this._repository,
    required this._notifier,
    required this._onOpen,
    this.interval = const Duration(seconds: 30),
    this.observeLifecycle = true,
  });

  static const summaryId = 0;
  static const summaryPayload = 'list';
  static const _maxSingleNotifications = 3;

  final NotificationRepository _repository;
  final LocalNotifier _notifier;
  final void Function(int? ticketId) _onOpen;
  final Duration interval;
  final bool observeLifecycle;

  final _updates = StreamController<Set<int>>.broadcast();
  Poller<List<AppNotification>>? _poller;
  bool _notifierReady = false;
  int? _baseline;
  int _unreadCount = 0;
  List<AppNotification> _unread = const [];

  /// Ticket aberto na tela de detalhe: novidades dele não viram notificação
  /// local, porque a tela já recarrega.
  int? currentTicketId;

  int get unreadCount => _unreadCount;

  String get badgeLabel => _unreadCount >= 50 ? '50+' : '$_unreadCount';

  bool get isRunning => _poller != null;

  /// Ids dos tickets com novidade; a lista e o detalhe recarregam ao ouvir.
  Stream<Set<int>> get updates => _updates.stream;

  Future<void> start() async {
    if (_poller != null) return;
    _poller = Poller<List<AppNotification>>(
      fetch: () => _repository.list(unreadOnly: true),
      interval: interval,
      onData: _onData,
      onError: (_) {},
      observeLifecycle: observeLifecycle,
    )..start();
    if (_notifierReady) return;
    _notifierReady = true;
    await _safely(
      () => _notifier.initialize((payload) => unawaited(_handleTap(payload))),
    );
    await _safely(_notifier.requestPermission);
  }

  void stop() {
    _poller?.dispose();
    _poller = null;
    _baseline = null;
    _unread = const [];
    currentTicketId = null;
    if (_unreadCount != 0) {
      _unreadCount = 0;
      notifyListeners();
    }
    unawaited(_safely(_notifier.cancelAll));
  }

  Future<void> refreshNow() async => _poller?.refresh();

  /// Abrir o ticket já é ler as novidades dele: limpa as não lidas do sino.
  Future<void> markTicketRead(int ticketId) async {
    final pending = [
      for (final notification in _unread)
        if (notification.ticketId == ticketId) notification,
    ];
    if (pending.isEmpty) return;
    for (final notification in pending) {
      try {
        await _repository.markRead(notification.id);
      } on ApiException {
        // A próxima consulta corrige o contador.
      }
    }
    await refreshNow();
  }

  @override
  void dispose() {
    stop();
    unawaited(_updates.close());
    super.dispose();
  }

  void _onData(List<AppNotification> unread) {
    _unread = unread;
    _unreadCount = unread.length;
    final newest = unread.fold<int>(0, (max, n) => n.id > max ? n.id : max);
    final baseline = _baseline;
    if (baseline == null || newest > baseline) _baseline = newest;
    notifyListeners();
    if (baseline == null) return;

    final fresh = [
      for (final notification in unread)
        if (notification.id > baseline) notification,
    ]..sort((a, b) => a.id.compareTo(b.id));
    if (fresh.isEmpty) return;
    _updates.add({
      for (final notification in fresh)
        if (notification.ticketId != null) notification.ticketId!,
    });

    final toShow = [
      for (final notification in fresh)
        if (notification.ticketId == null ||
            notification.ticketId != currentTicketId)
          notification,
    ];
    if (toShow.isEmpty) return;
    if (toShow.length > _maxSingleNotifications) {
      unawaited(
        _safely(
          () => _notifier.show(
            summaryId,
            'Novas notificações',
            'Você tem ${toShow.length} novas notificações',
            summaryPayload,
          ),
        ),
      );
      return;
    }
    for (final notification in toShow) {
      unawaited(
        _safely(
          () => _notifier.show(
            notification.id,
            notification.title,
            notification.body,
            '${notification.id}:${notification.ticketId ?? ''}',
          ),
        ),
      );
    }
  }

  Future<void> _handleTap(String? payload) async {
    if (payload == null || payload == summaryPayload) {
      _onOpen(null);
      return;
    }
    final parts = payload.split(':');
    final notificationId = int.tryParse(parts.first);
    final ticketId = parts.length > 1 ? int.tryParse(parts[1]) : null;
    // O ticket já está na tela: só marca como lida.
    if (ticketId == null || ticketId != currentTicketId) _onOpen(ticketId);
    if (notificationId == null) return;
    try {
      await _repository.markRead(notificationId);
    } on ApiException {
      // Abrir o ticket importa mais; a próxima consulta corrige o contador.
    }
    await refreshNow();
  }

  static Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Notificação local falhou: $error');
    }
  }
}
