import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/network/auth_http_client.dart';
import 'package:mobile_flutter/core/network/token_refresher.dart';
import 'package:mobile_flutter/core/network/token_store.dart';

void main() {
  late TokenStore tokenStore;
  late List<http.Request> refreshCalls;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    tokenStore = TokenStore();
    await tokenStore.save(accessToken: 'abc', refreshToken: '');
    refreshCalls = [];
  });

  TokenRefresher refresher() => TokenRefresher(
    client: MockClient((request) async {
      refreshCalls.add(request);
      return http.Response('', 404);
    }),
    tokenStore: tokenStore,
  );

  test('an empty refresh token gives up without calling the API', () async {
    expect(await refresher().refresh(), isFalse);
    expect(refreshCalls, isEmpty);
  });

  test('sends the bearer token', () async {
    late http.BaseRequest seen;
    final client = AuthHttpClient(
      inner: MockClient((request) async {
        seen = request;
        return http.Response('ok', 200);
      }),
      tokenStore: tokenStore,
      refresher: refresher(),
      onSessionExpired: () => fail('não expirou'),
    );

    final response = await client.get(Uri.parse('http://api.test/x'));

    expect(response.statusCode, 200);
    expect(seen.headers['Authorization'], 'Bearer abc');
  });

  test('a 401 clears the session and reports it once', () async {
    var expired = 0;
    final client = AuthHttpClient(
      inner: MockClient((_) async => http.Response('', 401)),
      tokenStore: tokenStore,
      refresher: refresher(),
      onSessionExpired: () => expired++,
    );

    final response = await client.get(Uri.parse('http://api.test/x'));

    expect(response.statusCode, 401);
    expect(expired, 1);
    expect(await tokenStore.readAccessToken(), isNull);
    expect(refreshCalls, isEmpty);
  });
}
