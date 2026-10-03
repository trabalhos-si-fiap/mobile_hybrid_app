import 'dart:typed_data';

/// Tipos aceitos pela API (AttachmentValidator).
const acceptedContentTypes = {
  'image/png',
  'image/jpeg',
  'image/webp',
  'application/pdf',
};

const _contentTypeByExtension = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'pdf': 'application/pdf',
};

/// Tipo a enviar no multipart, ou nulo se o arquivo deve ser recusado. A
/// extensão só vale quando o seletor não informa um tipo útil.
String? resolveContentType(String fileName, String? mimeType) {
  if (mimeType != null && mimeType != 'application/octet-stream') {
    return acceptedContentTypes.contains(mimeType) ? mimeType : null;
  }
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return _contentTypeByExtension[fileName.substring(dot + 1).toLowerCase()];
}

/// Arquivo escolhido no aparelho, ainda não enviado.
class PickedAttachment {
  PickedAttachment({required this.name, required this.bytes, String? mimeType})
    : contentType = resolveContentType(name, mimeType),
      size = bytes.length;

  /// Arquivo acima do limite: o seletor não chega a ler os bytes, e
  /// fileProblem o recusa pelo tamanho.
  PickedAttachment.tooLarge({
    required this.name,
    required this.size,
    String? mimeType,
  }) : bytes = Uint8List(0),
       contentType = resolveContentType(name, mimeType);

  final String name;
  final Uint8List bytes;

  /// Nulo quando o tipo não é aceito.
  final String? contentType;

  final int size;

  bool get isImage => contentType?.startsWith('image/') ?? false;
}
