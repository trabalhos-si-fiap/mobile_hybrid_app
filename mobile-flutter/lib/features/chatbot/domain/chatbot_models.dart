/// Tipos do Mentor Edu no openapi.yaml (/chatbot/conversations).
T _fromApi<T>(List<T> values, String Function(T) apiValue, String value) {
  for (final candidate in values) {
    if (apiValue(candidate) == value) return candidate;
  }
  throw FormatException('Valor desconhecido: $value');
}

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) fromJson) => [
  for (final item in value as List<dynamic>)
    fromJson(item as Map<String, dynamic>),
];

enum ChatbotState {
  inicio('INICIO'),
  segmento('SEGMENTO'),
  confirmacao('CONFIRMACAO'),
  encaminhamento('ENCAMINHAMENTO'),
  resolvida('RESOLVIDA'),
  encaminhada('ENCAMINHADA');

  const ChatbotState(this.apiValue);

  final String apiValue;

  /// Estados em que o bot ainda aceita texto ou opção.
  bool get acceptsReplies =>
      this == inicio || this == segmento || this == confirmacao;

  static ChatbotState fromApi(String value) =>
      _fromApi(values, (state) => state.apiValue, value);
}

enum ChatbotSender {
  bot('BOT'),
  user('USER');

  const ChatbotSender(this.apiValue);

  final String apiValue;

  static ChatbotSender fromApi(String value) =>
      _fromApi(values, (sender) => sender.apiValue, value);
}

class ChatbotMessage {
  const ChatbotMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.createdAt,
  });

  factory ChatbotMessage.fromJson(Map<String, dynamic> json) => ChatbotMessage(
    id: json['id'] as int,
    sender: ChatbotSender.fromApi(json['sender'] as String),
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final int id;
  final ChatbotSender sender;
  final String body;
  final DateTime createdAt;
}

class ChatbotOption {
  const ChatbotOption({required this.id, required this.label});

  factory ChatbotOption.fromJson(Map<String, dynamic> json) =>
      ChatbotOption(id: json['id'] as String, label: json['label'] as String);

  /// `segment:<SEGMENTO>`, `faq:<id>`, `menu`, `human`, `resolved` ou
  /// `not_resolved`.
  final String id;
  final String label;
}

/// Rascunho do ticket na passagem para o atendente.
class ChatbotHandoff {
  const ChatbotHandoff({required this.segment, required this.description});

  factory ChatbotHandoff.fromJson(Map<String, dynamic> json) => ChatbotHandoff(
    segment: json['segment'] as String?,
    description: json['description'] as String,
  );

  /// Nulo quando o usuário não escolheu nenhum segmento.
  final String? segment;
  final String description;
}

/// Um turno: a mensagem do usuário (menos no início) e as respostas do bot.
class ChatbotTurn {
  const ChatbotTurn({
    required this.conversationId,
    required this.state,
    required this.messages,
    required this.options,
    required this.handoff,
  });

  factory ChatbotTurn.fromJson(Map<String, dynamic> json) => ChatbotTurn(
    conversationId: json['conversationId'] as int,
    state: ChatbotState.fromApi(json['state'] as String),
    messages: _list(json['messages'], ChatbotMessage.fromJson),
    options: _list(json['options'], ChatbotOption.fromJson),
    handoff: json['handoff'] == null
        ? null
        : ChatbotHandoff.fromJson(json['handoff'] as Map<String, dynamic>),
  );

  final int conversationId;
  final ChatbotState state;
  final List<ChatbotMessage> messages;
  final List<ChatbotOption> options;

  /// Só na passagem (estado ENCAMINHAMENTO).
  final ChatbotHandoff? handoff;
}

/// O que o usuário manda num turno: um texto ou uma opção, nunca os dois.
class ChatbotReply {
  const ChatbotReply.text(String this.text) : optionId = null;

  const ChatbotReply.option(String this.optionId) : text = null;

  final String? text;
  final String? optionId;

  Map<String, String> toJson() {
    final text = this.text;
    return text != null ? {'text': text} : {'optionId': optionId!};
  }

  @override
  bool operator ==(Object other) =>
      other is ChatbotReply && other.text == text && other.optionId == optionId;

  @override
  int get hashCode => Object.hash(text, optionId);

  @override
  String toString() => 'ChatbotReply(text: $text, optionId: $optionId)';
}
