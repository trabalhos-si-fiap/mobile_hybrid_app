import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_services.dart';
import '../../../../core/attachments/attachment_picker.dart';
import '../../../../core/attachments/attachment_rules.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/attachment_source.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/picked_attachment_tile.dart';
import '../../domain/ticket_models.dart';
import '../../domain/ticket_rules.dart';
import 'new_ticket_controller.dart';

class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  late final NewTicketController _controller;
  final _description = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = NewTicketController(repository: AppScope.of(context).tickets);
    unawaited(_controller.loadSegments());
  }

  @override
  void dispose() {
    _controller.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick(AttachmentSource source) async {
    final picked = await pickAttachments(
      context,
      source,
      limit: _controller.remainingSlots,
    );
    if (!mounted || picked == null || picked.isEmpty) return;
    _controller.attach(picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final created = await _controller.submit(_description.text);
    if (created == null || !mounted) return;
    unawaited(
      Navigator.of(context).pushReplacementNamed('/tickets/${created.id}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abrir ticket')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final segments = _controller.segments;
          final segmentsError = _controller.segmentsError;
          final error = _controller.error;
          final busy = _controller.submitting;
          // Formulário curto: tudo construído de uma vez (um ListView
          // preguiçoso deixaria o botão Enviar fora da árvore).
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionTitle('Tipo do problema'),
                if (segmentsError != null)
                  ErrorBanner(
                    message: segmentsError,
                    onRetry: _controller.loadSegments,
                  ),
                if (segments == null && segmentsError == null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                for (final option in segments ?? const <SegmentOption>[])
                  _SegmentCard(
                    option: option,
                    selected: option.segment == _controller.selectedSegment,
                    onTap: busy
                        ? null
                        : () => _controller.selectSegment(option.segment),
                  ),
                const SizedBox(height: 16),
                const _SectionTitle('Descrição'),
                TextField(
                  key: const Key('description-input'),
                  controller: _description,
                  enabled: !busy,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: maxTextLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Conte o que aconteceu',
                  ),
                ),
                const SizedBox(height: 8),
                const _SectionTitle('Anexos (opcional)'),
                const Text(
                  'PNG, JPEG, WEBP ou PDF, até 5 MB cada, no máximo 5.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                AttachmentSourceButtons(
                  onPick: _pick,
                  enabled: !busy && _controller.remainingSlots > 0,
                ),
                for (final problem in _controller.fileProblems)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      problem,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                if (_controller.files.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final file in _controller.files)
                        PickedAttachmentTile(
                          file: file,
                          onRemove: busy
                              ? null
                              : () => _controller.detach(file),
                        ),
                    ],
                  ),
                ],
                if (error != null) ErrorBanner(message: error),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('submit-ticket'),
                  onPressed: busy ? null : _submit,
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text('Enviar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SegmentOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    inMutuallyExclusiveGroup: true,
    child: Card(
      key: Key('segment-${option.segment}'),
      color: AppColors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.purple : AppColors.inputBorder,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          option.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(segmentDeadlineText(option.slaMinutes)),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? AppColors.purple : AppColors.textSecondary,
        ),
      ),
    ),
  );
}
