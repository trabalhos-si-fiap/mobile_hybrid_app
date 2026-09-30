import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/notifications/domain/app_notification.dart';

void main() {
  final json = {
    'id': 21,
    'ticketId': 7,
    'type': 'NOVA_MENSAGEM',
    'title': 'Nova mensagem',
    'body': 'Dev respondeu no ticket #7.',
    'read': false,
    'createdAt': '2026-09-30T13:20:00Z',
  };

  test('fromJson', () {
    final notification = AppNotification.fromJson(json);
    expect(notification.id, 21);
    expect(notification.ticketId, 7);
    expect(notification.title, 'Nova mensagem');
    expect(notification.body, 'Dev respondeu no ticket #7.');
    expect(notification.read, isFalse);
    expect(notification.createdAt, DateTime.utc(2026, 9, 30, 13, 20));
  });

  test('ticketId may be null', () {
    final notification = AppNotification.fromJson({...json, 'ticketId': null});
    expect(notification.ticketId, isNull);
  });

  test('copyWith changes only read', () {
    final read = AppNotification.fromJson(json).copyWith(read: true);
    expect(read.read, isTrue);
    expect(read.id, 21);
    expect(read.title, 'Nova mensagem');
  });
}
