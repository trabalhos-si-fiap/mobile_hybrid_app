import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/attachment_source.dart';
import '../../../../core/widgets/attachment_tile.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/ticket_models.dart';
import '../../domain/ticket_rules.dart';
import 'composer.dart';
import 'message_bubble.dart';
import 'resolution_card.dart';
import 'ticket_detail_controller.dart';

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final int ticketId;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late final TicketDetailController _controller;
  final _message = TextEditingController();
  final _scroll = ScrollController();

  /// Rola para a mensagem nova só se o usuário já estava no fim.
  bool _stickToBottom = true;
  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    _controller = TicketDetailController(
      ticketId: widget.ticketId,
      repository: services.tickets,
      center: services.notificationCenter,
    )..addListener(_onChange);
    _scroll.addListener(_trackBottom);
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _trackBottom() {
    final position = _scroll.position;
    _stickToBottom = position.pixels >= position.maxScrollExtent - 48;
  }

  void _onChange() {
    final count = _controller.messages.length;
    if (count == _messageCount) return;
    _messageCount = count;
    if (!_stickToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _message.text;
    final sent = await _controller.send(text);
    // Só apaga se ninguém mudou o texto durante o envio.
    if (sent && mounted && _message.text == text) _message.clear();
  }

  Future<void> _attach() async {
    final source = await showAttachmentSourceSheet(context);
    if (source == null || !mounted) return;
    final picked = await pickAttachments(
      context,
      source,
      limit: _controller.remainingSlots,
    );
    if (!mounted || picked == null || picked.isEmpty) return;
    _controller.attach(picked);
  }

  Future<void> _confirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Encerrar o ticket?'),
        content: const Text(
          'Depois de encerrado, o ticket não pode ser reaberto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-dialog-ok'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.confirm();
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
          title: Text('#${widget.ticketId}', key: const Key('ticket-title')),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.notFound) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ticket não encontrado.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _backToList,
              child: const Text('Voltar para meus tickets'),
            ),
          ],
        ),
      );
    }
    final ticket = _controller.ticket;
    if (ticket == null) {
      final error = _controller.loadError;
      return error == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ErrorBanner(message: error, onRetry: _controller.reload),
              ],
            );
    }
    final actionError = _controller.actionError;
    return Column(
      children: [
        if (_controller.offline)
          const ErrorBanner(
            message: 'Sem conexão. Tentando de novo…',
            subtle: true,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _controller.reload,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _Header(ticket: ticket),
                const SizedBox(height: 12),
                _Request(ticket: ticket),
                const SizedBox(height: 12),
                if (_controller.messages.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Nenhuma mensagem ainda.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                for (final message in _controller.messages)
                  MessageBubble(message: message),
              ],
            ),
          ),
        ),
        if (canAnswerResolution(ticket.status))
          ResolutionCard(
            busy: _controller.acting,
            onConfirm: _confirm,
            onReopen: _controller.reopen,
          ),
        if (actionError != null) ErrorBanner(message: actionError),
        Composer(
          enabled: canSendMessage(ticket.status),
          controller: _message,
          files: _controller.files,
          problems: _controller.fileProblems,
          sending: _controller.sending,
          onAttach: _attach,
          onRemove: _controller.detach,
          onSend: _send,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ticket});

  final TicketDetail ticket;

  @override
  Widget build(BuildContext context) {
    const secondary = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    final deadline = deadlineText(ticket.slaStatus, ticket.slaDueAt);
    return _Card(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                ticket.segmentLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            StatusChip(status: ticket.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(assigneeText(ticket.assigneeName), style: secondary),
        Text('Aberto em ${formatDateTime(ticket.createdAt)}', style: secondary),
        if (deadline != null) Text(deadline, style: secondary),
      ],
    );
  }
}

class _Request extends StatelessWidget {
  const _Request({required this.ticket});

  final TicketDetail ticket;

  @override
  Widget build(BuildContext context) => _Card(
    children: [
      const Text(
        'Sua solicitação',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(ticket.description),
      if (ticket.attachments.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final attachment in ticket.attachments)
              AttachmentTile(attachment: attachment),
          ],
        ),
      ],
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}
