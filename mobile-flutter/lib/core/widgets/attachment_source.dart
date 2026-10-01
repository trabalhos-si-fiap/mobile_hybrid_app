import 'package:flutter/material.dart';

import '../app_services.dart';
import '../attachments/attachment_picker.dart';
import '../attachments/picked_attachment.dart';

const _options = [
  (
    source: AttachmentSource.camera,
    key: 'attach-camera',
    label: 'Câmera',
    icon: Icons.photo_camera_outlined,
  ),
  (
    source: AttachmentSource.gallery,
    key: 'attach-gallery',
    label: 'Galeria',
    icon: Icons.photo_library_outlined,
  ),
  (
    source: AttachmentSource.pdf,
    key: 'attach-pdf',
    label: 'PDF',
    icon: Icons.picture_as_pdf_outlined,
  ),
];

/// Botões Câmera, Galeria e PDF (tela de abertura de ticket).
class AttachmentSourceButtons extends StatelessWidget {
  const AttachmentSourceButtons({
    super.key,
    required this.onPick,
    this.enabled = true,
  });

  final ValueChanged<AttachmentSource> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final option in _options)
        OutlinedButton.icon(
          key: Key(option.key),
          onPressed: enabled ? () => onPick(option.source) : null,
          icon: Icon(option.icon),
          label: Text(option.label),
        ),
    ],
  );
}

/// As mesmas opções numa folha (campo de mensagem do detalhe).
Future<AttachmentSource?> showAttachmentSourceSheet(BuildContext context) =>
    showModalBottomSheet<AttachmentSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in _options)
              ListTile(
                key: Key(option.key),
                leading: Icon(option.icon),
                title: Text(option.label),
                onTap: () => Navigator.pop(sheetContext, option.source),
              ),
          ],
        ),
      ),
    );

/// Chama o seletor; num erro dele, mostra o motivo e devolve nulo.
Future<List<PickedAttachment>?> pickAttachments(
  BuildContext context,
  AttachmentSource source, {
  required int limit,
}) async {
  final picker = AppScope.of(context).picker;
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await picker.pick(source, limit: limit);
  } on AttachmentPickException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return null;
  }
}
