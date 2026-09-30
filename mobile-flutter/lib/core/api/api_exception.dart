enum ApiErrorKind {
  network,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  badRequest,
  unprocessable,
  server,
}

/// Única exceção que os repositórios lançam.
class ApiException implements Exception {
  const ApiException(this.kind, {this.status, this.serverMessage});

  factory ApiException.fromStatus(int status, {String? serverMessage}) {
    final kind = switch (status) {
      400 => ApiErrorKind.badRequest,
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      422 => ApiErrorKind.unprocessable,
      _ => ApiErrorKind.server,
    };
    return ApiException(kind, status: status, serverMessage: serverMessage);
  }

  final ApiErrorKind kind;
  final int? status;

  /// O campo `message` do corpo de erro da API, quando veio.
  final String? serverMessage;

  /// Texto pronto para a tela.
  String get message => switch (kind) {
    ApiErrorKind.network => 'Sem conexão com o servidor.',
    ApiErrorKind.unauthorized => 'Sua sessão expirou. Entre de novo.',
    ApiErrorKind.forbidden => 'Esta conta não tem acesso a esta área.',
    ApiErrorKind.notFound => 'Ticket não encontrado.',
    ApiErrorKind.conflict =>
      'O ticket mudou de situação. A tela foi atualizada.',
    ApiErrorKind.badRequest || ApiErrorKind.unprocessable =>
      serverMessage ?? 'Confira os dados e tente de novo.',
    ApiErrorKind.server => 'Erro no servidor. Tente de novo em instantes.',
  };

  @override
  String toString() => 'ApiException($kind, $status)';
}
