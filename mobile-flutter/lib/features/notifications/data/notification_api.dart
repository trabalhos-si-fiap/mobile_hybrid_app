import '../../../core/api/api_client.dart';
import '../domain/app_notification.dart';

/// Notificações do usuário logado. Lança só ApiException.
abstract interface class NotificationRepository {
  /// Mais recentes primeiro; a API devolve no máximo 50.
  Future<List<AppNotification>> list({bool unreadOnly = false});

  Future<void> markRead(int id);

  Future<void> markAllRead();
}

class HttpNotificationRepository implements NotificationRepository {
  HttpNotificationRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async =>
      decodeList(
        await _api.getJson(
          '/notifications',
          query: unreadOnly ? const {'unreadOnly': 'true'} : null,
        ),
        AppNotification.fromJson,
      );

  @override
  Future<void> markRead(int id) => _api.postJson('/notifications/$id/read');

  @override
  Future<void> markAllRead() => _api.postJson('/notifications/read-all');
}
