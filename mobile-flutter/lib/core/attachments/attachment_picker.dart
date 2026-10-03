import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'attachment_rules.dart';
import 'picked_attachment.dart';

enum AttachmentSource { camera, gallery, pdf }

class AttachmentPickException implements Exception {
  const AttachmentPickException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AttachmentPicker {
  /// Devolve os arquivos escolhidos (lista vazia se o usuário desistiu).
  /// [limit] é quantos ainda cabem no envio.
  Future<List<PickedAttachment>> pick(
    AttachmentSource source, {
    required int limit,
  });
}

class DeviceAttachmentPicker implements AttachmentPicker {
  DeviceAttachmentPicker({ImagePicker? imagePicker})
    : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;

  // Reduz a foto para caber folgada nos 5 MB; o image_picker grava JPEG.
  static const _maxWidth = 1920.0;
  static const _quality = 85;

  static const _pdf = XTypeGroup(
    label: 'PDF',
    extensions: ['pdf'],
    mimeTypes: ['application/pdf'],
  );

  @override
  Future<List<PickedAttachment>> pick(
    AttachmentSource source, {
    required int limit,
  }) async {
    try {
      switch (source) {
        case AttachmentSource.camera:
          return _single(ImageSource.camera);
        case AttachmentSource.gallery:
          // pickMultiImage exige limit >= 2.
          if (limit < 2) return _single(ImageSource.gallery);
          final photos = await _images.pickMultiImage(
            maxWidth: _maxWidth,
            imageQuality: _quality,
            limit: limit,
          );
          return [for (final photo in photos) await _fromXFile(photo)];
        case AttachmentSource.pdf:
          final files = limit > 1
              ? await openFiles(acceptedTypeGroups: const [_pdf])
              : [
                  ?await openFile(acceptedTypeGroups: const [_pdf]),
                ];
          return [for (final file in files) await _fromXFile(file)];
      }
    } on PlatformException catch (error) {
      if (error.code == 'camera_access_denied' ||
          error.code == 'photo_access_denied') {
        throw const AttachmentPickException(
          'Permita o acesso à câmera nas configurações do aparelho.',
        );
      }
      throw const AttachmentPickException('Não foi possível anexar o arquivo.');
    } on AttachmentPickException {
      rethrow;
    } on Exception {
      throw const AttachmentPickException('Não foi possível anexar o arquivo.');
    }
  }

  Future<List<PickedAttachment>> _single(ImageSource source) async {
    final photo = await _images.pickImage(
      source: source,
      maxWidth: _maxWidth,
      imageQuality: _quality,
    );
    return photo == null ? const [] : [await _fromXFile(photo)];
  }

  Future<PickedAttachment> _fromXFile(XFile file) async {
    // Para arquivo com caminho (câmera, galeria, PDF no iOS), o tamanho basta
    // para recusar sem ler os bytes. No Android, o file_selector já entrega o
    // PDF lido.
    final size = await file.length();
    if (size > maxFileBytes) {
      return PickedAttachment.tooLarge(
        name: file.name,
        size: size,
        mimeType: file.mimeType,
      );
    }
    return PickedAttachment(
      name: file.name,
      bytes: await file.readAsBytes(),
      mimeType: file.mimeType,
    );
  }
}
