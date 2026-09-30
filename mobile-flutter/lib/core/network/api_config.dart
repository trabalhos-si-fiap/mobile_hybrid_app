/// Network configuration for talking to the backend.
class ApiConfig {
  const ApiConfig._();

  /// Override at build/run time with:
  /// `--dart-define=API_BASE_URL=http://192.168.0.10:8080/api/v1`
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Base URL of the Edu Admin API (Spring Boot, `api/`).
  ///
  /// `8080` is the default `SERVER_PORT` and `/api/v1` is the fixed
  /// `server.servlet.context-path` configured in
  /// `api/src/main/resources/application.yml`.
  ///
  /// `localhost` also works on a phone or an emulator connected by USB after
  /// `adb reverse tcp:8080 tcp:8080`: the device's port 8080 then reaches the
  /// API on the development machine, with no LAN IP or firewall involved.
  static String get baseUrl =>
      _override.isNotEmpty ? _override : 'http://localhost:8080/api/v1';

  /// Override for admin-facing endpoints. Useful when the Admin API lives
  /// on a different host/port than [baseUrl].
  ///
  /// Override at build/run time with:
  /// `--dart-define=ADMIN_API_BASE_URL=http://192.168.0.10:8080/api/v1`
  ///
  /// Falls back to [baseUrl] when not set, so existing builds are unaffected.
  static const String _adminOverride = String.fromEnvironment(
    'ADMIN_API_BASE_URL',
  );

  static String get adminBaseUrl =>
      _adminOverride.isNotEmpty ? _adminOverride : baseUrl;
}
