import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'token_store.dart';

/// Exchanges the stored refresh token for a fresh JWT pair via
/// `POST /auth/refresh` and persists it.
///
/// Uses a plain [http.Client] (never the authenticated wrapper) to avoid
/// recursing back into the 401 refresh flow.
class TokenRefresher {
  TokenRefresher({http.Client? client, TokenStore? tokenStore})
    : _client = client ?? http.Client(),
      _tokenStore = tokenStore ?? TokenStore();

  final http.Client _client;
  final TokenStore _tokenStore;

  /// Returns `true` when a new token pair was obtained and saved.
  Future<bool> refresh() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null) return false;

    final http.Response res;
    try {
      res = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
    } on Exception {
      return false;
    }

    if (res.statusCode != 200) return false;

    final tokens = jsonDecode(res.body) as Map<String, dynamic>;
    await _tokenStore.save(
      accessToken: tokens['access_token'] as String,
      refreshToken: tokens['refresh_token'] as String,
    );
    return true;
  }
}
