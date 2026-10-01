import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/screen_controller.dart';

class _Controller extends ScreenController {
  void ping() => notify();
}

void main() {
  test('notify is a no-op after dispose', () {
    final controller = _Controller();
    var calls = 0;
    controller.addListener(() => calls++);

    controller.ping();
    controller.dispose();
    controller.ping();

    expect(calls, 1);
    expect(controller.isDisposed, isTrue);
  });
}
