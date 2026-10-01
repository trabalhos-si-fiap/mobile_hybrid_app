import 'package:mobile_flutter/features/notifications/data/notification_api.dart';
import 'package:mobile_flutter/features/notifications/domain/app_notification.dart';
import 'package:mobile_flutter/features/notifications/local_notifier.dart';

class FakeNotificationRepository implements NotificationRepository {
  /// Respostas de list(unreadOnly: true), uma por chamada; a última se repete.
  final unreadResponses = <List<AppNotification>>[];

  /// Resposta de list() sem filtro.
  List<AppNotification> all = const [];
  Object? listError;
  Object? markReadError;
  final calls = <String>[];

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    calls.add(unreadOnly ? 'list unread' : 'list');
    final error = listError;
    if (error != null) throw error;
    if (!unreadOnly) return all;
    if (unreadResponses.isEmpty) return const [];
    return unreadResponses.length == 1
        ? unreadResponses.first
        : unreadResponses.removeAt(0);
  }

  @override
  Future<void> markRead(int id) async {
    calls.add('read $id');
    final error = markReadError;
    if (error != null) throw error;
  }

  @override
  Future<void> markAllRead() async {
    calls.add('read all');
    final error = markReadError;
    if (error != null) throw error;
  }
}

class FakeLocalNotifier implements LocalNotifier {
  void Function(String? payload)? onTap;
  var permissionRequests = 0;
  var cancelAllCalls = 0;
  final shown = <({int id, String title, String body, String payload})>[];

  /// Quando verdadeiro, todo método lança (plugin quebrado).
  bool failing = false;

  void _maybeFail() {
    if (failing) throw StateError('plugin quebrado');
  }

  @override
  Future<void> initialize(void Function(String? payload) onTap) async {
    _maybeFail();
    this.onTap = onTap;
  }

  @override
  Future<void> requestPermission() async {
    _maybeFail();
    permissionRequests++;
  }

  @override
  Future<void> show(int id, String title, String body, String payload) async {
    _maybeFail();
    shown.add((id: id, title: title, body: body, payload: payload));
  }

  @override
  Future<void> cancelAll() async {
    _maybeFail();
    cancelAllCalls++;
  }
}
