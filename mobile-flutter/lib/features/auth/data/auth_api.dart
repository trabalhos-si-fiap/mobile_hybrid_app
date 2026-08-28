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

  /// Solicita redefinição de senha via `POST /auth/password-reset/request`.
  /// Endpoint ainda não disponível na API — lança [AuthException] informativo.
  Future<void> requestPasswordReset({required String email}) async {
    throw AuthException(
      'Redefinição de senha indisponível. Entre em contato com o administrador.',
    );
  }

  /// Confirma o código e redefine a senha via `POST /auth/password-reset/confirm`.
  /// Endpoint ainda não disponível na API — lança [AuthException] informativo.
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    throw AuthException(
      'Redefinição de senha indisponível. Entre em contato com o administrador.',
    );
  }

  /// Ends the session locally: drops the JWT pair and the cached profile data.
  Future<void> logout() async {
    await _tokenStore.clear();
    await _sessionStore.clear();
  }

  /// Salva o token de acesso e o nome do usuário a partir da resposta da API.
  ///
  /// A API retorna: `{ accessToken, tokenType, user: { id, name, email, role } }`
  /// Não há refresh token no momento — o TokenStore salva uma string vazia como
  /// placeholder para manter a interface estável.
  Future<void> _persistAuth(Map<String, dynamic> body) async {
    final accessToken = body['accessToken'] as String;
    await _tokenStore.save(
      accessToken: accessToken,
      refreshToken: '',
    );
    final user = body['user'] as Map<String, dynamic>?;
    final name = user?['name'] as String?;
    if (name != null && name.isNotEmpty) {
      await _sessionStore.saveName(name);
    }
  }

  /// Nome do usuário logado: lido do cache local (salvo no login).
  /// Retorna `null` se não houver sessão.
  Future<String?> currentDisplayName() async {
    return _sessionStore.readName();
  }
}
