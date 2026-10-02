import '../../../core/api/api_client.dart';
import '../domain/chatbot_models.dart';

/// Conversa com o Mentor Edu. Lança só ApiException.
abstract interface class ChatbotRepository {
  /// Começa uma conversa nova; o turno traz a saudação.
  Future<ChatbotTurn> start();

  Future<ChatbotTurn> send(int conversationId, ChatbotReply reply);
}

class HttpChatbotRepository implements ChatbotRepository {
  HttpChatbotRepository(this._api);

  final ApiClient _api;

  @override
  Future<ChatbotTurn> start() async => decodeObject(
    await _api.postJson('/chatbot/conversations'),
    ChatbotTurn.fromJson,
  );

  @override
  Future<ChatbotTurn> send(int conversationId, ChatbotReply reply) async =>
      decodeObject(
        await _api.postJson(
          '/chatbot/conversations/$conversationId/messages',
          body: reply.toJson(),
        ),
        ChatbotTurn.fromJson,
      );
}
