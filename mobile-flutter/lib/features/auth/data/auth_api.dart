import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';
import '../../../core/network/session_store.dart';
import '../../../core/network/token_store.dart';

/// Raised when authentication fails; carries a user-facing message.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin client for the backend auth endpoints.
class AuthApi {
  AuthApi({
    http.Client? client,
    TokenStore? tokenStore,
    SessionStore? sessionStore,
  }) : _client = client ?? http.Client(),
       _tokenStore = tokenStore ?? TokenStore(),
       _sessionStore = sessionStore ?? SessionStore();

  final http.Client _client;
  final TokenStore _tokenStore;
  final SessionStore _sessionStore;

  /// Creates an account via `POST /auth/register` and persists the JWT pair.
  ///
  /// [educationLevel] must be one of the backend `EducationLevel` values and
  /// [birthDate] is sent as `DD/MM/AAAA` (parsed server-side).
  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String birthDate,
    required String educationLevel,
    required String password,
  }) async {
    final http.Response res;
    try {
      res = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'birth_date': birthDate,
          'education_level': educationLevel,
          'password': password,
        }),
      );
    } on Exception {
      throw AuthException('Não foi possível conectar ao servidor');
    }

    if (res.statusCode == 409) {
      throw AuthException('Este e-mail já está cadastrado');
    }
    if (res.statusCode == 422) {
      throw AuthException('Verifique os dados informados');
    }
    if (res.statusCode == 429) {
      throw AuthException('Muitas tentativas. Tente novamente mais tarde');
    }
    if (res.statusCode != 201) {
      throw AuthException('Falha ao cadastrar (código ${res.statusCode})');
    }

    await _persistAuth(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Authenticates against `POST /auth/login` and persists the JWT pair.
  Future<void> login({required String email, required String password}) async {
    final http.Response res;
    try {
      res = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
    } on Exception {
      throw AuthException('Não foi possível conectar ao servidor');
    }

    if (res.statusCode == 401) {
      throw AuthException('E-mail ou senha inválidos');
    }
    if (res.statusCode == 429) {
      throw AuthException('Muitas tentativas. Tente novamente mais tarde');
    }
    if (res.statusCode != 200) {
      throw AuthException('Falha ao entrar (código ${res.statusCode})');
    }

    await _persistAuth(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Requests a password reset code via `POST /auth/password-reset/request`.
  ///
  /// The backend always responds 200 (anti-enumeration), so a successful
  /// return reveals nothing about whether the email exists.
  Future<void> requestPasswordReset({required String email}) async {
    final http.Response res;
    try {
      res = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/password-reset/request'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
    } on Exception {
      throw AuthException('Não foi possível conectar ao servidor');
    }

    if (res.statusCode == 429) {
      throw AuthException('Muitas tentativas. Tente novamente mais tarde');
    }
    if (res.statusCode == 422) {
      throw AuthException('Verifique os dados informados');
    }
    if (res.statusCode != 200) {
      throw AuthException(
        'Falha ao solicitar o código (código ${res.statusCode})',
      );
    }
  }

  /// Confirms a reset code and sets a new password via
  /// `POST /auth/password-reset/confirm`. The backend returns a generic 400 for
  /// any verification failure (wrong/expired/locked code, unknown email).
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final http.Response res;
    try {
      res = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/password-reset/confirm'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'new_password': newPassword,
        }),
      );
    } on Exception {
      throw AuthException('Não foi possível conectar ao servidor');
    }

    if (res.statusCode == 400) {
      throw AuthException('Código inválido ou expirado');
    }
    if (res.statusCode == 422) {
      throw AuthException('Verifique os dados informados');
    }
    if (res.statusCode != 200) {
      throw AuthException(
        'Falha ao redefinir a senha (código ${res.statusCode})',
      );
    }
  }

  /// Ends the session locally: drops the JWT pair and the cached profile data.
  Future<void> logout() async {
    await _tokenStore.clear();
    await _sessionStore.clear();
  }

  /// Saves the JWT pair and caches the user's display name from an
  /// `AuthResponse` body (`{user, tokens}`).
  Future<void> _persistAuth(Map<String, dynamic> body) async {
    final tokens = body['tokens'] as Map<String, dynamic>;
    await _tokenStore.save(
      accessToken: tokens['access_token'] as String,
      refreshToken: tokens['refresh_token'] as String,
    );
    final user = body['user'] as Map<String, dynamic>?;
    final name = user?['name'] as String?;
    if (name != null && name.isNotEmpty) {
      await _sessionStore.saveName(name);
    }
  }

  /// Display name of the signed-in user: the cached value when present, else
  /// fetched from `GET /auth/me` and cached. Returns `null` when unavailable
  /// (no session or the request fails) so callers can fall back to a neutral
  /// greeting.
  Future<String?> currentDisplayName() async {
    final cached = await _sessionStore.readName();
    if (cached != null && cached.isNotEmpty) return cached;

    final access = await _tokenStore.readAccessToken();
    if (access == null) return null;

    final http.Response res;
    try {
      res = await _client.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $access'},
      );
    } on Exception {
      return null;
    }
    if (res.statusCode != 200) return null;

    final user = jsonDecode(res.body) as Map<String, dynamic>;
    final name = user['name'] as String?;
    if (name != null && name.isNotEmpty) {
      await _sessionStore.saveName(name);
    }
    return name;
  }
}
