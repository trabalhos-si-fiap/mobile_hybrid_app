import 'picked_attachment.dart';

/// Espelha a API (AttachmentValidator e o limite dos textos); ela continua
/// sendo a autoridade.
const maxFiles = 5;
const maxFileBytes = 5 * 1024 * 1024;
const maxTextLength = 2000;

const _tooManyFiles = 'Anexe no máximo $maxFiles arquivos por envio.';

String? fileProblem(PickedAttachment file) {
  if (file.contentType == null) {
    return '${file.name}: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.';
  }
  if (file.size == 0) return '${file.name}: arquivo vazio.';
  if (file.size > maxFileBytes) return '${file.name}: maior que 5 MB.';
  return null;
}

/// Junta os escolhidos aos que já estão no envio, recusando os inválidos e o
/// excesso.
({List<PickedAttachment> files, List<String> problems}) addFiles(
  List<PickedAttachment> current,
  List<PickedAttachment> picked,
) {
  final files = [...current];
  final problems = <String>[];
  for (final file in picked) {
    final problem = fileProblem(file);
    if (problem != null) {
      problems.add(problem);
      continue;
    }
    if (files.length >= maxFiles) {
      problems.add(_tooManyFiles);
      break;
    }
    files.add(file);
  }
  return (files: files, problems: problems);
}

String? textProblem(String text, {required String whenEmpty}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return whenEmpty;
  if (trimmed.length > maxTextLength) {
    return 'O texto passa de $maxTextLength caracteres.';
  }
  return null;
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final megabytes = (bytes / (1024 * 1024)).toStringAsFixed(1);
  return '${megabytes.replaceAll('.', ',')} MB';
}
