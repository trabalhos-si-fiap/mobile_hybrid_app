import '../../../core/api/api_exception.dart';
import '../../../core/screen_controller.dart';
import '../../tickets/domain/new_ticket_prefill.dart';
import '../data/chatbot_api.dart';
import '../domain/chatbot_models.dart';

/// Conversa com o Mentor Edu. A API conduz os estados; a tela só mostra o
/// último turno e manda o texto ou a opção escolhida.
class AssistantController extends ScreenController {
  AssistantController({required this._repository});

  final ChatbotRepository _repository;

  int? _conversationId;
  ChatbotReply? _failed;

  /// Nulo até a conversa começar.
  ChatbotState? state;
  List<ChatbotMessage> messages = const [];

  /// Respostas rápidas do último turno.
  List<ChatbotOption> options = const [];

  /// Só na passagem para o atendente.
  ChatbotHandoff? handoff;

  /// Falha ao começar a conversa (nada na tela).
  String? startError;
  bool sending = false;

  /// Falha ao enviar; [retry] reenvia o mesmo texto ou opção.
  String? sendError;

  /// A API recusou a mensagem com 409: a conversa acabou em outra tela.
  bool closed = false;

  bool get acceptsReplies => !closed && (state?.acceptsReplies ?? false);

  bool get handedOff => !closed && handoff != null;

  /// Acabou sem passagem: resolvida, encerrada ou num estado final.
  bool get finished => state != null && !acceptsReplies && !handedOff;

  NewTicketPrefill? get prefill {
    final id = _conversationId;
    final handoff = this.handoff;
    if (id == null || handoff == null || closed) return null;
    return NewTicketPrefill(
      conversationId: id,
      segment: handoff.segment,
      description: handoff.description,
    );
  }

  Future<void> start() async {
    startError = null;
    notify();
    try {
      _apply(await _repository.start());
    } on ApiException catch (failure) {
      if (failure.kind != ApiErrorKind.unauthorized) {
        startError = failure.message;
      }
    }
    notify();
  }

  /// Verdadeiro se a API aceitou. Texto em branco não sai.
  Future<bool> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return _send(ChatbotReply.text(trimmed));
  }

  Future<bool> choose(ChatbotOption option) =>
      _send(ChatbotReply.option(option.id));

  /// Reenvia o que falhou. Devolve o que foi aceito, ou nulo.
  Future<ChatbotReply?> retry() async {
    final failed = _failed;
    if (failed == null) return null;
    return await _send(failed) ? failed : null;
  }

  Future<bool> _send(ChatbotReply reply) async {
    final id = _conversationId;
    if (sending || id == null || !acceptsReplies) return false;
    sending = true;
    sendError = null;
    _failed = null;
    notify();
    try {
      _apply(await _repository.send(id, reply));
      return true;
    } on ApiException catch (failure) {
      switch (failure.kind) {
        case ApiErrorKind.unauthorized:
          break;
        // 404 também: a conversa não existe mais para este usuário.
        case ApiErrorKind.conflict || ApiErrorKind.notFound:
          closed = true;
        default:
          sendError = failure.message;
          _failed = reply;
      }
      return false;
    } finally {
      sending = false;
      notify();
    }
  }

  void _apply(ChatbotTurn turn) {
    _conversationId = turn.conversationId;
    state = turn.state;
    messages = [...messages, ...turn.messages];
    options = turn.options;
    handoff = turn.handoff;
  }
}
