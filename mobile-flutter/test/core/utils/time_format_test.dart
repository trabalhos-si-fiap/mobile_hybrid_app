import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/utils/time_format.dart';

void main() {
  group('formatDateTime', () {
    test('shows day, month, hour and minute with two digits', () {
      expect(formatDateTime(DateTime(2026, 9, 3, 4, 5)), '03/09 04:05');
      expect(formatDateTime(DateTime(2026, 12, 30, 14, 45)), '30/12 14:45');
    });

    test('converts UTC to the device time zone', () {
      final utc = DateTime.utc(2026, 9, 30, 13);
      expect(formatDateTime(utc), formatDateTime(utc.toLocal()));
    });
  });

  group('relativeTime', () {
    final now = DateTime.utc(2026, 9, 30, 13);

    test('less than a minute, or in the future, is "agora"', () {
      expect(
        relativeTime(now.subtract(const Duration(seconds: 59)), now),
        'agora',
      );
      expect(relativeTime(now.add(const Duration(minutes: 3)), now), 'agora');
    });

    test('minutes, hours and days', () {
      expect(
        relativeTime(now.subtract(const Duration(minutes: 5)), now),
        'há 5 min',
      );
      expect(
        relativeTime(now.subtract(const Duration(minutes: 59)), now),
        'há 59 min',
      );
      expect(
        relativeTime(now.subtract(const Duration(hours: 2)), now),
        'há 2 h',
      );
      expect(
        relativeTime(now.subtract(const Duration(hours: 23)), now),
        'há 23 h',
      );
      expect(
        relativeTime(now.subtract(const Duration(days: 1)), now),
        'há 1 dia',
      );
      expect(
        relativeTime(now.subtract(const Duration(days: 3)), now),
        'há 3 dias',
      );
    });
  });
}
