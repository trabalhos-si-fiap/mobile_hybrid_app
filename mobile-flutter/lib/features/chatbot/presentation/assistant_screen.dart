import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/user_menu_button.dart';
import '../domain/chatbot_models.dart';
import 'assistant_controller.dart';

/// Limite do texto livre na API.
const assistantMaxLength = 500;

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  late final AssistantController _controller;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  double _keyboardHeight = 0;

  @override
  void initState() {
    super.initState();
    _controller = AssistantController(repository: AppScope.of(context).chatbot)
      ..addListener(_scrollToEnd);
    unawaited(_controller.start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // O teclado encolhe a lista; sem rolar, a última mensagem fica atrás dele.
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardHeight > _keyboardHeight) _scrollToEnd();
    _keyboardHeight = keyboardHeight;
  }

  @override
  void dispose() {
    _controller.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // jumpTo, e não animateTo: um toque durante a animação da rolagem seria
  // ignorado (a lista ignora toques enquanto rola sozinha).
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text;
    final sent = await _controller.sendText(text);
    if (sent && mounted && _input.text == text) _input.clear();
  }

  Future<void> _retry() async {
    final sent = (await _controller.retry())?.text;
    if (sent != null && mounted && _input.text.trim() == sent) _input.clear();
  }

  void _continue() {
    final prefill = _controller.prefill;
    if (prefill == null) return;
    unawaited(
      Navigator.of(
        context,
      ).pushReplacementNamed('/tickets/new', arguments: prefill),
    );
  }

  void _backToList() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      unawaited(navigator.pushReplacementNamed('/tickets'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Mentor Edu'),
          actions: const [UserMenuButton()],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.state == null) {
      final error = _controller.startError;
      return error == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ErrorBanner(message: error, onRetry: _controller.start),
              ],
            );
    }
    final sendError = _controller.sendError;
    final sending = _controller.sending;
    // Conversa curta (a API encerra na 30ª mensagem do usuário): tudo
    // construído de uma vez, para a rolagem até o fim ser exata.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final message in _controller.messages)
                  _Bubble(key: ValueKey(message.id), message: message),
                if (sending)
                  const _Typing()
                else if (_controller.acceptsReplies)
                  _Options(
                    options: _controller.options,
                    onChoose: _controller.choose,
                  ),
              ],
            ),
          ),
        ),
        if (_controller.closed)
          const ErrorBanner(message: 'Esta conversa foi encerrada.'),
        if (sendError != null) ErrorBanner(message: sendError, onRetry: _retry),
        if (_controller.handedOff)
          _FooterButton(
            buttonKey: const Key('assistant-continue'),
            label: 'Continuar para o ticket',
            onPressed: _continue,
          )
        else if (_controller.acceptsReplies)
          _InputBar(controller: _input, sending: sending, onSend: _send)
        else
          _FooterButton(
            buttonKey: const Key('assistant-done'),
            label: 'Voltar aos meus tickets',
            onPressed: _backToList,
          ),
      ],
    );
  }
}

/// Bot à esquerda, com o nome; usuário à direita. Mesmo estilo do chat do
/// ticket (MessageBubble).
class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message});

  final ChatbotMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.sender == ChatbotSender.user;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mine ? AppColors.purpleSoft : AppColors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                const Text(
                  'Mentor Edu',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.purple,
                  ),
                ),
              Text(message.body),
              const SizedBox(height: 4),
              Text(
                formatDateTime(message.createdAt),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Text(
      'Mentor Edu está digitando…',
      style: TextStyle(
        fontSize: 13,
        fontStyle: FontStyle.italic,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

class _Options extends StatelessWidget {
  const _Options({required this.options, required this.onChoose});

  final List<ChatbotOption> options;
  final ValueChanged<ChatbotOption> onChoose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          OutlinedButton(
            key: Key('assistant-option-${option.id}'),
            onPressed: () => onChoose(option),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.purple,
              side: const BorderSide(color: AppColors.purple),
            ),
            child: Text(option.label),
          ),
      ],
    ),
  );
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.white,
    padding: const EdgeInsets.all(8),
    child: SafeArea(
      top: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('assistant-input'),
              controller: controller,
              enabled: !sending,
              minLines: 1,
              maxLines: 4,
              maxLength: assistantMaxLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Digite sua dúvida',
                counterText: '',
              ),
            ),
          ),
          IconButton(
            key: const Key('assistant-send'),
            tooltip: 'Enviar',
            color: AppColors.purple,
            onPressed: sending ? null : onSend,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    ),
  );
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.white,
    padding: const EdgeInsets.all(16),
    child: SafeArea(
      top: false,
      child: ElevatedButton(
        key: buttonKey,
        onPressed: onPressed,
        child: Text(label),
      ),
    ),
  );
}
