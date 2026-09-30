import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../attachments/picked_attachment.dart';
import 'api_exception.dart';

/// Chamadas à API com timeout, corpo em UTF-8 e status traduzido em
/// [ApiException]. O [http.Client] recebido é o que põe o token (AuthHttpClient).
class ApiClient {
  ApiClient({
    required this._client,
    required this._baseUrl,
    this.jsonTimeout = const Duration(seconds: 15),
    this.uploadTimeout = const Duration(seconds: 60),
  });

  final http.Client _client;
  final String _baseUrl;
  final Duration jsonTimeout;

  /// Vale para envios com anexo e para baixar anexos (até 5 MB).
  final Duration uploadTimeout;

  Future<Object?> getJson(String path, {Map<String, String>? query}) async =>
      _decode(await _run(() => _client.get(_uri(path, query)), jsonTimeout));

  Future<Object?> postJson(String path, {Object? body}) async => _decode(
    await _run(
      () => _client.post(
        _uri(path),
        headers: body == null
            ? null
            : const {'Content-Type': 'application/json'},
        body: body == null ? null : jsonEncode(body),
      ),
      jsonTimeout,
    ),
  );

  /// [files] precisam ter passado pelas regras de anexo: o tipo já é aceito.
  Future<Object?> postMultipart(
    String path, {
    required Map<String, String> fields,
    required List<PickedAttachment> files,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..fields.addAll(fields);
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          file.bytes,
          filename: file.name,
          // Explícito: sem ele o pacote http manda application/octet-stream,
          // que a API recusa (P2A-01).
          contentType: MediaType.parse(file.contentType!),
        ),
      );
    }
    return _decode(
      await _run(
        () async => http.Response.fromStream(await _client.send(request)),
        uploadTimeout,
      ),
    );
  }

  Future<Uint8List> getBytes(String path) async =>
      (await _run(() => _client.get(_uri(path)), uploadTimeout)).bodyBytes;

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<http.Response> _run(
    Future<http.Response> Function() call,
    Duration timeout,
  ) async {
    final http.Response response;
    try {
      response = await call().timeout(timeout);
    } on Exception {
      // TimeoutException, ClientException, SocketException...
      throw const ApiException(ApiErrorKind.network);
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) return response;
    throw ApiException.fromStatus(
      status,
      serverMessage: _serverMessage(response),
    );
  }

  // Decodifica os bytes como UTF-8: sem charset no Content-Type, o pacote
  // http usaria latin1 em response.body.
  static Object? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException(ApiErrorKind.server);
    }
  }

  static String? _serverMessage(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        final message = body['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    } on FormatException {
      // Corpo de erro que não é JSON (proxy, HTML).
    }
    return null;
  }
}

/// Repositories throw only [ApiException], even for a malformed success body.
List<T> decodeList<T>(
  Object? json,
  T Function(Map<String, dynamic> json) fromJson,
) {
  try {
    return [
      for (final item in json as List<dynamic>)
        fromJson(item as Map<String, dynamic>),
    ];
  } on FormatException {
    throw const ApiException(ApiErrorKind.server);
  } on TypeError {
    throw const ApiException(ApiErrorKind.server);
  }
}

/// Repositories throw only [ApiException], even for a malformed success body.
T decodeObject<T>(
  Object? json,
  T Function(Map<String, dynamic> json) fromJson,
) {
  try {
    return fromJson(json as Map<String, dynamic>);
  } on FormatException {
    throw const ApiException(ApiErrorKind.server);
  } on TypeError {
    throw const ApiException(ApiErrorKind.server);
  }
}
