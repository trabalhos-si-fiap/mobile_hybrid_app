import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/utils/jwt_utils.dart';

String _token(Map<String, dynamic> payload) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(payload)}.assinatura';
}

void main() {
  test('decodes the payload of a token', () {
    final payload = decodeJwtPayload(
      _token({'sub': 'ana@edu.com', 'role': 'USER'}),
    );

    expect(payload['sub'], 'ana@edu.com');
    expect(payload['role'], 'USER');
  });

  test('rejects a token without three parts', () {
    expect(() => decodeJwtPayload('abc.def'), throwsFormatException);
  });
}
