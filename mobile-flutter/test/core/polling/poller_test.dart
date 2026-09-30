import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/polling/poller.dart';

const _interval = Duration(seconds: 10);

class _Harness {
  _Harness(this.fetch);

  final Future<String> Function() fetch;
  final data = <String>[];
  final errors = <Object>[];
  var calls = 0;

  late final poller = Poller<String>(
    fetch: () {
      calls++;
      return fetch();
    },
    interval: _interval,
    onData: data.add,
    onError: errors.add,
    observeLifecycle: false,
  );
}

void main() {
  test('fetches at once and then every interval', () {
    fakeAsync((async) {
      var n = 0;
      final h = _Harness(() async => 'r${n++}');

      h.poller.start();
      async.flushMicrotasks();
      expect(h.data, ['r0']);

      async.elapse(_interval);
      expect(h.data, ['r0', 'r1']);

      async.elapse(_interval * 2);
      expect(h.data, ['r0', 'r1', 'r2', 'r3']);
      h.poller.dispose();
    });
  });

  test('a tick does not start a second fetch while one is running', () {
    fakeAsync((async) {
      final pending = Completer<String>();
      final h = _Harness(() => pending.future);

      h.poller.start();
      async.elapse(_interval * 3);
      expect(h.calls, 1);

      pending.complete('late');
      async.flushMicrotasks();
      expect(h.data, ['late']);
      h.poller.dispose();
    });
  });

  test('refresh fetches now and restarts the interval', () {
    fakeAsync((async) {
      var n = 0;
      final h = _Harness(() async => 'r${n++}');

      h.poller.start();
      async.elapse(const Duration(seconds: 6));
      h.poller.refresh();
      async.flushMicrotasks();
      expect(h.calls, 2);

      async.elapse(const Duration(seconds: 6));
      expect(h.calls, 2, reason: 'o próximo tique é 10 s depois do refresh');

      async.elapse(const Duration(seconds: 4));
      expect(h.calls, 3);
      h.poller.dispose();
    });
  });

  test('a response superseded by a newer fetch is discarded', () {
    fakeAsync((async) {
      final first = Completer<String>();
      var call = 0;
      final h = _Harness(
        () => call++ == 0 ? first.future : Future.value('new'),
      );

      h.poller.start();
      h.poller.refresh();
      async.flushMicrotasks();
      first.complete('old');
      async.flushMicrotasks();

      expect(h.data, ['new']);
      h.poller.dispose();
    });
  });

  test('errors go to onError and polling goes on', () {
    fakeAsync((async) {
      var call = 0;
      final h = _Harness(() async {
        if (call++ == 0) throw StateError('falhou');
        return 'ok';
      });

      h.poller.start();
      async.flushMicrotasks();
      expect(h.errors, hasLength(1));
      expect(h.data, isEmpty);

      async.elapse(_interval);
      expect(h.data, ['ok']);
      h.poller.dispose();
    });
  });

  test('pauses in the background and fetches at once when resumed', () {
    fakeAsync((async) {
      final h = _Harness(() async => 'x');

      h.poller.start();
      async.flushMicrotasks();
      expect(h.calls, 1);

      h.poller.didChangeAppLifecycleState(AppLifecycleState.hidden);
      h.poller.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.elapse(_interval * 3);
      expect(h.calls, 1);

      h.poller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(h.calls, 2);

      async.elapse(_interval);
      expect(h.calls, 3);
      h.poller.dispose();
    });
  });

  test('inactive does not pause', () {
    fakeAsync((async) {
      final h = _Harness(() async => 'x');

      h.poller.start();
      h.poller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      async.elapse(_interval);

      expect(h.calls, 2);
      h.poller.dispose();
    });
  });

  test('stop drops the response in flight and cancels the timer', () {
    fakeAsync((async) {
      final pending = Completer<String>();
      final h = _Harness(() => pending.future);

      h.poller.start();
      h.poller.stop();
      pending.complete('late');
      async.elapse(_interval * 3);

      expect(h.data, isEmpty);
      expect(h.calls, 1);
      expect(h.poller.isRunning, isFalse);
    });
  });

  test('start after stop works again', () {
    fakeAsync((async) {
      final first = Completer<String>();
      var call = 0;
      final h = _Harness(
        () => call++ == 0 ? first.future : Future.value('again'),
      );

      h.poller.start();
      h.poller.stop();
      h.poller.start();
      async.flushMicrotasks();

      expect(h.data, ['again']);
      h.poller.dispose();
    });
  });
}
