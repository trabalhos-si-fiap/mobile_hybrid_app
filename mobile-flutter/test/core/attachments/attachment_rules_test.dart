import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/attachments/attachment_rules.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';

PickedAttachment _file(String name, int size) =>
    PickedAttachment(name: name, bytes: Uint8List(size));

void main() {
  group('fileProblem', () {
    test('accepts PNG, JPEG, WEBP and PDF up to exactly 5 MB', () {
      expect(fileProblem(_file('a.png', 1)), isNull);
      expect(fileProblem(_file('a.jpg', 1)), isNull);
      expect(fileProblem(_file('a.webp', 1)), isNull);
      expect(fileProblem(_file('a.pdf', maxFileBytes)), isNull);
    });

    test('refuses other types, empty files and more than 5 MB', () {
      expect(
        fileProblem(_file('a.heic', 1)),
        'a.heic: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.',
      );
      expect(fileProblem(_file('a.png', 0)), 'a.png: arquivo vazio.');
      expect(
        fileProblem(_file('a.png', maxFileBytes + 1)),
        'a.png: maior que 5 MB.',
      );
    });
  });

  group('addFiles', () {
    test('adds the valid files and reports the invalid ones', () {
      final result = addFiles(
        [_file('um.png', 1)],
        [_file('dois.pdf', 1), _file('ruim.heic', 1), _file('tres.jpg', 1)],
      );
      expect(result.files.map((f) => f.name), [
        'um.png',
        'dois.pdf',
        'tres.jpg',
      ]);
      expect(result.problems, [
        'ruim.heic: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.',
      ]);
    });

    test('stops at 5 files', () {
      final current = [for (var i = 1; i <= 4; i++) _file('$i.png', 1)];
      final result = addFiles(current, [_file('5.png', 1), _file('6.png', 1)]);
      expect(result.files, hasLength(5));
      expect(result.files.last.name, '5.png');
      expect(result.problems, ['Anexe no máximo 5 arquivos por envio.']);
    });
  });

  group('textProblem', () {
    test('requires text after trimming', () {
      expect(
        textProblem('   ', whenEmpty: 'Escreva uma mensagem.'),
        'Escreva uma mensagem.',
      );
      expect(textProblem(' oi ', whenEmpty: 'Escreva uma mensagem.'), isNull);
    });

    test('accepts exactly 2000 characters and refuses 2001', () {
      expect(textProblem('a' * maxTextLength, whenEmpty: '-'), isNull);
      expect(
        textProblem('a' * (maxTextLength + 1), whenEmpty: '-'),
        'O texto passa de 2000 caracteres.',
      );
    });
  });

  test('formatBytes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(1536 * 1024), '1,5 MB');
  });
}
