import 'dart:convert';

/// Decodifica o payload de um JWT sem verificar a assinatura.
///
/// Uso legítimo aqui: o token já veio de uma resposta HTTPS confiável do
/// Auth + Users Service; só precisamos ler o claim `role` localmente para
/// decidir a navegação pós-login. A validação de assinatura/expiração
/// continua sendo feita pelo backend em cada request autenticado (e o
/// `AuthHttpClient` já cuida do refresh em caso de expiração).
Map<String, dynamic> decodeJwtPayload(String token) {
  final partes = token.split('.');
  if (partes.length != 3) {
    throw const FormatException('Token JWT inválido');
  }

  final payload = base64Url.normalize(partes[1]);
  final decoded = utf8.decode(base64Url.decode(payload));
  return jsonDecode(decoded) as Map<String, dynamic>;
}

/// Extrai o papel do usuário (`student`, `admin`, `separador`, `entregador`)
/// de um access token. Retorna `null` se o token não puder ser decodificado.
String? extrairRoleDoToken(String token) {
  try {
    final payload = decodeJwtPayload(token);
    return payload['role'] as String?;
  } catch (_) {
    return null;
  }
}
