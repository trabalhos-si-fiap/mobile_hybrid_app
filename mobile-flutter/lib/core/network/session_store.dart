import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists lightweight, non-sensitive profile data for the signed-in user
/// (currently just the display name) so screens like Home can greet the user
/// without an extra round-trip. The JWT pair lives in [TokenStore].
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _nameKey = 'user_name';

  Future<void> saveName(String name) =>
      _storage.write(key: _nameKey, value: name);

  Future<String?> readName() => _storage.read(key: _nameKey);

  Future<void> clear() => _storage.delete(key: _nameKey);
}
