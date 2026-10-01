import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class OpenFileException implements Exception {
  const OpenFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class FileOpener {
  /// Grava o PDF no diretório temporário e abre no app padrão do aparelho.
  Future<void> openPdf(int attachmentId, String fileName, Uint8List bytes);
}

/// Nome no disco: único por anexo e sem separadores de caminho.
String tempFileName(int attachmentId, String fileName) =>
    '$attachmentId-${fileName.replaceAll(RegExp(r'[/\\]'), '_')}';

class OpenFilexOpener implements FileOpener {
  const OpenFilexOpener();

  @override
  Future<void> openPdf(
    int attachmentId,
    String fileName,
    Uint8List bytes,
  ) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/${tempFileName(attachmentId, fileName)}',
    );
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type == ResultType.done) return;
    if (result.type == ResultType.noAppToOpen) {
      throw const OpenFileException('Nenhum app instalado abre PDF.');
    }
    throw const OpenFileException('Não foi possível abrir o arquivo.');
  }
}
