import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile_flutter/core/network/api_config.dart';

const userEmail = 'e2e.usuario@edu.com';
const userPassword = 'usuario123';
const devEmail = 'e2e.dev@edu.com';
const devPassword = 'atendente123';

/// Chamadas diretas à API do e2e, para o lado do atendente e para preparar
/// cenários. Usa o mesmo localhost:8080 do app (adb reverse).
class E2eApi {
  E2eApi._(this._token);

  final String _token;

  static String get _base => ApiConfig.baseUrl;

  static Future<E2eApi> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = _check(response) as Map<String, dynamic>;
    return E2eApi._(body['accessToken'] as String);
  }

  Map<String, String> get _auth => {'Authorization': 'Bearer $_token'};

  Future<void> setPresence(String presence) async => _check(
    await http.put(
      Uri.parse('$_base/employees/me/presence'),
      headers: {..._auth, 'Content-Type': 'application/json'},
      body: jsonEncode({'presence': presence}),
    ),
  );

  Future<int> openTicket(String segment, String description) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/tickets'))
      ..headers.addAll(_auth)
      ..fields['segment'] = segment
      ..fields['description'] = description;
    final body =
        _check(await http.Response.fromStream(await request.send()))
            as Map<String, dynamic>;
    return body['id'] as int;
  }

  Future<void> assume(int id) async => _check(
    await http.post(Uri.parse('$_base/tickets/$id/assume'), headers: _auth),
  );

  Future<void> resolve(int id) async => _check(
    await http.post(Uri.parse('$_base/tickets/$id/resolve'), headers: _auth),
  );

  Future<void> sendMessage(int id, String body) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_base/tickets/$id/messages'))
          ..headers.addAll(_auth)
          ..fields['body'] = body;
    _check(await http.Response.fromStream(await request.send()));
  }

  Future<Map<String, dynamic>> ticket(int id) async =>
      _check(await http.get(Uri.parse('$_base/tickets/$id'), headers: _auth))
          as Map<String, dynamic>;

  Future<List<dynamic>> messages(int id) async =>
      _check(
            await http.get(
              Uri.parse('$_base/tickets/$id/messages'),
              headers: _auth,
            ),
          )
          as List<dynamic>;

  Future<List<dynamic>> unreadNotifications() async =>
      _check(
            await http.get(
              Uri.parse('$_base/notifications?unreadOnly=true'),
              headers: _auth,
            ),
          )
          as List<dynamic>;

  Future<void> markAllRead() async => _check(
    await http.post(Uri.parse('$_base/notifications/read-all'), headers: _auth),
  );

  static Object? _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        '${response.request?.method} ${response.request?.url} -> '
        '${response.statusCode}: ${utf8.decode(response.bodyBytes)}',
      );
    }
    return response.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
  }
}
