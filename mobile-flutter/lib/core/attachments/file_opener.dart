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

  /// Apaga os PDFs gravados; chamado no fim da sessão.
  Future<void> clear();
}

/// Pasta dos PDFs dentro do diretório temporário; o fim da sessão a apaga.
const pdfFolder = 'pdfs';

/// Nome no disco: único por anexo e sem separadores de caminho.
String tempFileName(int attachmentId, String fileName) =>
    '$attachmentId-${fileName.replaceAll(RegExp(r'[/\\]'), '_')}';

class OpenFilexOpener implements FileOpener {
  const OpenFilexOpener({
    Future<Directory> Function() baseDirectory = getTemporaryDirectory,
    // ignore: prefer_initializing_formals
  }) : _baseDirectory = baseDirectory;

  final Future<Directory> Function() _baseDirectory;

  Future<Directory> _pdfDirectory() async =>
      Directory('${(await _baseDirectory()).path}/$pdfFolder');

  @override
  Future<void> openPdf(
    int attachmentId,
    String fileName,
    Uint8List bytes,
  ) async {
    final directory = await _pdfDirectory();
    await directory.create(recursive: true);
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

  @override
  Future<void> clear() async {
    final directory = await _pdfDirectory();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
