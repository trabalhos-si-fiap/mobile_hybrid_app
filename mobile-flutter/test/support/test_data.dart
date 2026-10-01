import 'package:mobile_flutter/features/notifications/domain/app_notification.dart';

import 'json_fixtures.dart';

/// Relógio fixo dos testes de tela.
final testNow = DateTime.utc(2026, 9, 30, 13);

AppNotification testNotification({
  int id = 21,
  int? ticketId = 7,
  bool read = false,
  String title = 'Nova mensagem',
  String body = 'Dev respondeu no ticket #7.',
}) => AppNotification.fromJson(
  notificationJson(
    id: id,
    ticketId: ticketId,
    read: read,
    title: title,
    body: body,
  ),
);
