/// Stub do serviço de notificações push.
///
/// O registro de dispositivo não está implementado nesta versão da API —
/// este stub evita erros de compilação nas telas que chamam [syncToken].
class MessagingService {
  /// Registra o token de push notification no backend.
  /// No momento é uma no-op: a API ainda não possui esse endpoint.
  Future<void> syncToken() async {
    // TODO: implementar quando o backend expor POST /notifications/token
  }
}
