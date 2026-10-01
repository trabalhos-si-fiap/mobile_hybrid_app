import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/session/session.dart';

import '../../support/test_data.dart';

void main() {
  test('parseRole', () {
    expect(parseRole('USER'), UserRole.user);
    expect(parseRole('EMPLOYEE'), UserRole.employee);
    expect(parseRole('ADMIN'), UserRole.admin);
    expect(parseRole('admin'), isNull);
    expect(parseRole(null), isNull);
  });

  test('homeRouteFor', () {
    expect(homeRouteFor(UserRole.user), '/tickets');
    expect(homeRouteFor(UserRole.employee), '/home');
    expect(homeRouteFor(UserRole.admin), '/home');
  });

  group('readSession', () {
    test('returns the role of a valid token', () {
      expect(readSession(fakeJwt(role: 'USER'), testNow), UserRole.user);
      expect(readSession(fakeJwt(role: 'ADMIN'), testNow), UserRole.admin);
    });

    test('an expired token has no session', () {
      final token = fakeJwt(
        expiresAt: testNow.subtract(const Duration(seconds: 1)),
      );
      expect(readSession(token, testNow), isNull);
    });

    test('an unknown role or a broken token has no session', () {
      expect(readSession(fakeJwt(role: 'OUTRO'), testNow), isNull);
      expect(readSession('nao-e-jwt', testNow), isNull);
      expect(readSession('a.b.c', testNow), isNull);
    });
  });
}
