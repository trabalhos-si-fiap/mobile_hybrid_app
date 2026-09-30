import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_config.dart';

void main() {
  test('uses localhost on every platform (adb reverse on devices)', () {
    expect(ApiConfig.baseUrl, 'http://localhost:8080/api/v1');
    expect(ApiConfig.adminBaseUrl, 'http://localhost:8080/api/v1');
  });
}
