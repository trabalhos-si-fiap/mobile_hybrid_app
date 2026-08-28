import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'auth_http_client.dart';
import 'token_refresher.dart';
import 'token_store.dart';

/// Global navigator key so non-widget code (the auth client) can route the
/// user back to login when the session expires.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app-wide authenticated HTTP client.
///
/// A single shared instance is intentional: the 401 refresh is de-duplicated
/// across every data service, so concurrent requests (e.g. order polling plus a
/// user action) trigger at most one refresh.
final AuthHttpClient appAuthClient = AuthHttpClient(
  inner: http.Client(),
  tokenStore: TokenStore(),
  refresher: TokenRefresher(),
  onSessionExpired: _goToLogin,
);

void _goToLogin() {
  rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
    '/login',
    (_) => false,
  );
}
