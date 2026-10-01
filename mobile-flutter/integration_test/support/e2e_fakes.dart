import 'dart:convert';

import 'package:mobile_flutter/core/attachments/attachment_picker.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/features/notifications/local_notifier.dart';

/// PNG 1x1 válido.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

final _pdf = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

/// Não dá para dirigir a câmera nem a galeria do sistema: devolve arquivos
/// fixos. Câmera e galeria dão tela.png; PDF dá comprovante.pdf.
class E2eAttachmentPicker implements AttachmentPicker {
  @override
  Future<List<PickedAttachment>> pick(
    AttachmentSource source, {
    required int limit,
  }) async => switch (source) {
    AttachmentSource.camera || AttachmentSource.gallery => [
      PickedAttachment(name: 'tela.png', bytes: _png, mimeType: 'image/png'),
    ],
    AttachmentSource.pdf => [
      PickedAttachment(
        name: 'comprovante.pdf',
        bytes: _pdf,
        mimeType: 'application/pdf',
      ),
    ],
  };
}

/// O plugin real, sem pedir a permissão: o diálogo do sistema ficaria por
/// cima do app durante o teste.
class E2eLocalNotifier extends PluginLocalNotifier {
  @override
  Future<void> requestPermission() async {}
}
