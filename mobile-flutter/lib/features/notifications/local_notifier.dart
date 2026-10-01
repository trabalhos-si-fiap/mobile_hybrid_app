import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificações locais do sistema. Interface para os testes trocarem o plugin.
abstract interface class LocalNotifier {
  Future<void> initialize(void Function(String? payload) onTap);

  Future<void> requestPermission();

  Future<void> show(int id, String title, String body, String payload);

  Future<void> cancelAll();
}

class PluginLocalNotifier implements LocalNotifier {
  PluginLocalNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'tickets',
      'Tickets',
      channelDescription: 'Respostas e mudanças nos seus tickets',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  @override
  Future<void> initialize(void Function(String? payload) onTap) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> show(int id, String title, String body, String payload) =>
      _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details,
        payload: payload,
      );

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
