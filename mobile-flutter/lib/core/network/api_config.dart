import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Network configuration for talking to the backend.
class ApiConfig {
  const ApiConfig._();

  /// Override at build/run time with:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8080/api/v1`
  ///
  /// Useful for physical devices (which don't share the host machine's
  /// network) or when the API runs on a non-default host/port
  /// (`SERVER_PORT` in `api/.env`).
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Base URL of the Edu Admin API (Spring Boot, `api/`).
  ///
  /// `8080` is the default `SERVER_PORT` and `/api/v1` is the fixed
  /// `server.servlet.context-path` configured in
  /// `api/src/main/resources/application.yml`.
  ///
  /// Auto-detects per platform so `flutter run` works out of the box on
  /// both emulators/simulators without any `--dart-define`:
  /// - Android emulator: `10.0.2.2` is the special alias for the host
  ///   machine's `localhost` (the emulator runs in its own virtualized
  ///   network namespace).
  /// - iOS Simulator: unlike Android, it shares the Mac's network stack
  ///   directly, so `localhost` from inside the simulator already points
  ///   at the Mac itself — no alias needed.
  /// - Web (Chrome, etc.): also `localhost`, same machine.
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8080/api/v1';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080/api/v1';
    // iOS Simulator (and macOS/Linux/Windows desktop builds) — localhost
    // already resolves to this same machine.
    return 'http://localhost:8080/api/v1';
  }

  /// Override for admin-facing endpoints. Useful when the Admin API lives
  /// on a different host/port than [baseUrl] (e.g. pointing a device at a
  /// remote environment while keeping other calls local).
  ///
  /// Override at build/run time with:
  /// `flutter run --dart-define=ADMIN_API_BASE_URL=http://192.168.0.10:8080/api/v1`
  ///
  /// Falls back to [baseUrl] when not set, so existing builds are unaffected.
  static const String _adminOverride =
      String.fromEnvironment('ADMIN_API_BASE_URL');

  static String get adminBaseUrl =>
      _adminOverride.isNotEmpty ? _adminOverride : baseUrl;
}
