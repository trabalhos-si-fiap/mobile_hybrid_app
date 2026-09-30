import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';

void main() {
  group('resolveContentType', () {
    test('keeps an accepted MIME type from the picker', () {
      expect(resolveContentType('foto', 'image/jpeg'), 'image/jpeg');
      expect(resolveContentType('x.bin', 'application/pdf'), 'application/pdf');
    });

    test('falls back to the extension when the picker has no MIME type', () {
      expect(resolveContentType('tela.PNG', null), 'image/png');
      expect(resolveContentType('foto.jpg', null), 'image/jpeg');
      expect(resolveContentType('foto.jpeg', null), 'image/jpeg');
      expect(resolveContentType('foto.webp', null), 'image/webp');
      expect(resolveContentType('nota.pdf', null), 'application/pdf');
      expect(
        resolveContentType('nota.pdf', 'application/octet-stream'),
        'application/pdf',
      );
    });

    test('refuses other types', () {
      expect(resolveContentType('foto.heic', 'image/heic'), isNull);
      expect(resolveContentType('foto.heic', null), isNull);
      expect(resolveContentType('sem-extensao', null), isNull);
      expect(resolveContentType('planilha.xlsx', null), isNull);
    });
  });

  test('PickedAttachment resolves the type and exposes size and isImage', () {
    final png = PickedAttachment(name: 'tela.png', bytes: Uint8List(10));
    expect(png.contentType, 'image/png');
    expect(png.size, 10);
    expect(png.isImage, isTrue);

    final pdf = PickedAttachment(
      name: 'nota.pdf',
      bytes: Uint8List(3),
      mimeType: 'application/pdf',
    );
    expect(pdf.isImage, isFalse);

    final heic = PickedAttachment(name: 'foto.heic', bytes: Uint8List(3));
    expect(heic.contentType, isNull);
    expect(heic.isImage, isFalse);
  });
}
