import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/attachments/file_opener.dart';

void main() {
  test('tempFileName is unique per attachment and has no path separators', () {
    expect(tempFileName(3, 'nota.pdf'), '3-nota.pdf');
    expect(tempFileName(4, '../../etc/passwd'), '4-.._.._etc_passwd');
    expect(tempFileName(5, r'a\b.pdf'), '5-a_b.pdf');
  });

  test('clear deletes only the PDF folder and tolerates it missing', () async {
    final base = await Directory.systemTemp.createTemp('opener');
    addTearDown(() => base.delete(recursive: true));
    final opener = OpenFilexOpener(baseDirectory: () async => base);

    await opener.clear();
    final pdf = File('${base.path}/$pdfFolder/3-nota.pdf');
    await pdf.create(recursive: true);
    final other = File('${base.path}/outro.txt');
    await other.create();

    await opener.clear();

    expect(await Directory('${base.path}/$pdfFolder').exists(), isFalse);
    expect(await other.exists(), isTrue);
  });
}
