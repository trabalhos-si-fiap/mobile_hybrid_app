import 'package:flutter/material.dart';

import '../../../../core/attachments/attachment_rules.dart';
import '../../../../core/attachments/picked_attachment.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/picked_attachment_tile.dart';

/// Campo de mensagem do rodapé. Com [enabled] falso (ticket FECHADO), só o
/// aviso aparece.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.enabled,
    required this.controller,
    required this.files,
    required this.problems,
    required this.sending,
    required this.onAttach,
    required this.onRemove,
    required this.onSend,
  });

  final bool enabled;
  final TextEditingController controller;
  final List<PickedAttachment> files;
  final List<String> problems;
  final bool sending;
  final VoidCallback onAttach;
  final ValueChanged<PickedAttachment> onRemove;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Container(
        key: const Key('composer-closed'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AppColors.inputFill,
        child: const SafeArea(
          top: false,
          child: Text(
            'Ticket fechado. Abra um novo se precisar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (files.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final file in files)
                      PickedAttachmentTile(
                        file: file,
                        onRemove: sending ? null : () => onRemove(file),
                      ),
                  ],
                ),
              ),
            for (final problem in problems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 8),
                child: Text(
                  problem,
                  style: const TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  key: const Key('composer-attach'),
                  tooltip: 'Anexar',
                  icon: const Icon(Icons.attach_file),
                  onPressed: sending || files.length >= maxFiles
                      ? null
                      : onAttach,
                ),
                Expanded(
                  child: TextField(
                    key: const Key('composer-input'),
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Escreva uma mensagem',
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('send-button'),
                  tooltip: 'Enviar',
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: AppColors.purple),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
