import 'package:http/http.dart' as http;

import 'token_refresher.dart';
import 'token_store.dart';

/// An [http.Client] that authenticates every request and transparently
/// recovers from an expired access token.
///
/// On each request it injects `Authorization: Bearer <access>`. When the
/// backend answers `401`, it refreshes the token pair once (sharing a single
/// in-flight refresh across concurrent requests) and replays the original
/// request with the new token. If the refresh fails, it clears the session and
/// invokes [onSessionExpired] so the app can route back to login.
///
/// [AuthApi] (login/register/reset) must NOT use this client: those calls have
/// no token yet and a `401` there means bad credentials, not expiry.
class AuthHttpClient extends http.BaseClient {
  AuthHttpClient({
    required http.Client inner,
    required TokenStore tokenStore,
    required TokenRefresher refresher,
    required void Function() onSessionExpired,
  }) : _inner = inner,
       _tokenStore = tokenStore,
       _refresher = refresher,
       _onSessionExpired = onSessionExpired;

  final http.Client _inner;
  final TokenStore _tokenStore;
  final TokenRefresher _refresher;
  final void Function() _onSessionExpired;

  Future<bool>? _refreshing;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Capture what we need to replay before the request is finalized on send.
    final replayable = request is http.Request ? request : null;
    final bodyBytes = replayable?.bodyBytes;

    await _authorize(request);
    final response = await _inner.send(request);
    if (response.statusCode != 401) return response;

    final refreshed = await _refreshOnce();
    if (!refreshed) {
      await _tokenStore.clear();
      _onSessionExpired();
      return response;
    }

    // Refresh succeeded but the request can't be replayed (e.g. streamed body).
    if (replayable == null) return response;

    await response.stream.drain<void>();
    final retry = _copy(replayable, bodyBytes!);
    await _authorize(retry);
    return _inner.send(retry);
  }

  @override
  void close() => _inner.close();

  Future<void> _authorize(http.BaseRequest request) async {
    final access = await _tokenStore.readAccessToken();
    if (access != null) {
      request.headers['Authorization'] = 'Bearer $access';
    }
  }

  /// Shares one refresh across concurrent 401s so they don't stampede.
  Future<bool> _refreshOnce() {
    return _refreshing ??= _refresher.refresh().whenComplete(() {
      _refreshing = null;
    });
  }

  http.Request _copy(http.Request src, List<int> bodyBytes) {
    final copy = http.Request(src.method, src.url)
      ..encoding = src.encoding
      ..bodyBytes = bodyBytes
      ..followRedirects = src.followRedirects
      ..maxRedirects = src.maxRedirects
      ..persistentConnection = src.persistentConnection;
    copy.headers.addAll(src.headers);
    return copy;
  }
}
