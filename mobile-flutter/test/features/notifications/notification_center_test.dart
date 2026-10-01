import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/features/notifications/notification_center.dart';

import '../../support/fakes.dart';
import '../../support/test_data.dart';

const _interval = Duration(seconds: 30);

class _Harness {
  final repository = FakeNotificationRepository();
  final notifier = FakeLocalNotifier();
  final opened = <int?>[];
  final updates = <Set<int>>[];

  late final center = NotificationCenter(
    repository: repository,
    notifier: notifier,
    onOpen: opened.add,
    observeLifecycle: false,
  )..updates.listen(updates.add);
}

void main() {
  test('the first poll is only the baseline', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.add([testNotification(id: 21)]);

      h.center.start();
      async.flushMicrotasks();

      expect(h.center.unreadCount, 1);
      expect(h.center.badgeLabel, '1');
      expect(h.notifier.shown, isEmpty);
      expect(h.updates, isEmpty);
      h.center.stop();
    });
  });

  test('new unread notifications become local notifications', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.addAll([
        [testNotification(id: 21)],
        [
          testNotification(
            id: 22,
            ticketId: 8,
            body: 'Dev respondeu no ticket #8.',
          ),
          testNotification(id: 21),
        ],
      ]);

      h.center.start();
      async.flushMicrotasks();
      async.elapse(_interval);

      expect(h.center.unreadCount, 2);
      expect(h.notifier.shown, hasLength(1));
      expect(h.notifier.shown.single.id, 22);
      expect(h.notifier.shown.single.title, 'Nova mensagem');
      expect(h.notifier.shown.single.body, 'Dev respondeu no ticket #8.');
      expect(h.notifier.shown.single.payload, '22:8');
      expect(h.updates, [
        {8},
      ]);
      h.center.stop();
    });
  });

  test('the same unread notifications do not notify twice', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.addAll([
        [],
        [testNotification(id: 22)],
      ]);

      h.center.start();
      async.flushMicrotasks();
      async.elapse(_interval * 3);

      expect(h.notifier.shown, hasLength(1));
      h.center.stop();
    });
  });

  test('more than three at once become one summary', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.addAll([
        [],
        [
          for (var id = 31; id <= 34; id++)
            testNotification(id: id, ticketId: id),
        ],
      ]);

      h.center.start();
      async.flushMicrotasks();
      async.elapse(_interval);

      expect(h.notifier.shown, hasLength(1));
      expect(h.notifier.shown.single.id, NotificationCenter.summaryId);
      expect(h.notifier.shown.single.body, 'Você tem 4 novas notificações');
      expect(
        h.notifier.shown.single.payload,
        NotificationCenter.summaryPayload,
      );
      expect(h.updates.single, {31, 32, 33, 34});
      h.center.stop();
    });
  });

  test(
    'the ticket open on screen gets an update, not a local notification',
    () {
      fakeAsync((async) {
        final h = _Harness();
        h.repository.unreadResponses.addAll([
          [],
          [testNotification(id: 22, ticketId: 7)],
        ]);
        h.center.currentTicketId = 7;

        h.center.start();
        async.flushMicrotasks();
        async.elapse(_interval);

        expect(h.notifier.shown, isEmpty);
        expect(h.updates, [
          {7},
        ]);
        h.center.stop();
      });
    },
  );

  test('a notification without ticket is still shown', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.addAll([
        [],
        [testNotification(id: 40, ticketId: null)],
      ]);
      h.center.currentTicketId = 7;

      h.center.start();
      async.flushMicrotasks();
      async.elapse(_interval);

      expect(h.notifier.shown.single.payload, '40:');
      h.center.stop();
    });
  });

  test('the badge caps at 50+', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.add([
        for (var id = 1; id <= 50; id++) testNotification(id: id),
      ]);

      h.center.start();
      async.flushMicrotasks();

      expect(h.center.badgeLabel, '50+');
      h.center.stop();
    });
  });

  test('stop resets the baseline and the counter', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.add([testNotification(id: 21)]);

      h.center.start();
      async.flushMicrotasks();
      h.center.currentTicketId = 7;
      h.center.stop();

      expect(h.center.unreadCount, 0);
      expect(h.center.isRunning, isFalse);
      expect(h.center.currentTicketId, isNull);
      async.flushMicrotasks();
      expect(h.notifier.cancelAllCalls, 1);

      // Outra conta entra: o que já existe vira linha de base de novo.
      h.repository.unreadResponses
        ..clear()
        ..add([testNotification(id: 90)]);
      h.center.start();
      async.flushMicrotasks();
      expect(h.center.unreadCount, 1);
      expect(h.notifier.shown, isEmpty);
      h.center.stop();
    });
  });

  test('permission is asked once, even after a restart', () {
    fakeAsync((async) {
      final h = _Harness();

      h.center.start();
      async.flushMicrotasks();
      h.center.stop();
      h.center.start();
      async.flushMicrotasks();

      expect(h.notifier.permissionRequests, 1);
      h.center.stop();
    });
  });

  test('tapping a notification opens the ticket and marks it read', () {
    fakeAsync((async) {
      final h = _Harness();
      h.center.start();
      async.flushMicrotasks();

      h.notifier.onTap!('22:8');
      async.flushMicrotasks();

      expect(h.opened, [8]);
      expect(h.repository.calls, contains('read 22'));
      h.center.stop();
    });
  });

  test('tapping the ticket already on screen does not open it again', () {
    fakeAsync((async) {
      final h = _Harness();
      h.center.start();
      async.flushMicrotasks();
      h.center.currentTicketId = 8;

      h.notifier.onTap!('22:8');
      async.flushMicrotasks();

      expect(h.opened, isEmpty);
      expect(h.repository.calls, contains('read 22'));
      h.center.stop();
    });
  });

  test("markTicketRead marks only that ticket's unread notifications", () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.add([
        testNotification(id: 21, ticketId: 7),
        testNotification(id: 22, ticketId: 8),
        testNotification(id: 23, ticketId: 7),
      ]);
      h.center.start();
      async.flushMicrotasks();

      h.center.markTicketRead(7);
      async.flushMicrotasks();

      final reads = h.repository.calls.where((c) => c.startsWith('read'));
      expect(reads, ['read 21', 'read 23']);
      h.center.markTicketRead(99);
      async.flushMicrotasks();
      expect(
        h.repository.calls.where((c) => c.startsWith('read')),
        hasLength(2),
      );
      h.center.stop();
    });
  });

  test('tapping the summary opens the list', () {
    fakeAsync((async) {
      final h = _Harness();
      h.center.start();
      async.flushMicrotasks();

      h.notifier.onTap!(NotificationCenter.summaryPayload);
      async.flushMicrotasks();

      expect(h.opened, [null]);
      expect(h.repository.calls.where((c) => c.startsWith('read')), isEmpty);
      h.center.stop();
    });
  });

  test('a failed mark-as-read still opens the ticket', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.markReadError = const ApiException(ApiErrorKind.network);
      h.center.start();
      async.flushMicrotasks();

      h.notifier.onTap!('22:8');
      async.flushMicrotasks();

      expect(h.opened, [8]);
      h.center.stop();
    });
  });

  test('a broken plugin never breaks the counter', () {
    fakeAsync((async) {
      final h = _Harness();
      h.notifier.failing = true;
      h.repository.unreadResponses.addAll([
        [],
        [testNotification(id: 22)],
      ]);

      h.center.start();
      async.flushMicrotasks();
      async.elapse(_interval);
      expect(h.center.unreadCount, 1);

      h.center.stop();
      async.flushMicrotasks();
      expect(h.center.isRunning, isFalse);
    });
  });

  test('a polling error keeps the last count', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.add([testNotification(id: 21)]);

      h.center.start();
      async.flushMicrotasks();
      h.repository.listError = const ApiException(ApiErrorKind.network);
      async.elapse(_interval);

      expect(h.center.unreadCount, 1);
      h.center.stop();
    });
  });
}
