import '../utils/jwt_utils.dart';

enum UserRole { user, employee, admin }

UserRole? parseRole(String? value) => switch (value) {
  'USER' => UserRole.user,
  'EMPLOYEE' => UserRole.employee,
  'ADMIN' => UserRole.admin,
  _ => null,
};

/// Tela inicial de cada papel: o USER usa os tickets; staff, o dashboard.
String homeRouteFor(UserRole role) =>
    role == UserRole.user ? '/tickets' : '/home';

/// Papel do token, se ele ainda vale em [now]. A assinatura não é conferida:
/// a API valida o token em cada chamada.
UserRole? readSession(String token, DateTime now) {
  try {
    final payload = decodeJwtPayload(token);
    final role = parseRole(payload['role'] as String?);
    final exp = payload['exp'];
    if (role == null || exp is! int) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    );
    return expiresAt.isAfter(now) ? role : null;
  } catch (_) {
    // Token ilegível: sem sessão.
    return null;
  }
}
