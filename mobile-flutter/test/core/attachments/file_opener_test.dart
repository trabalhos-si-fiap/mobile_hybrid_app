import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/attachments/file_opener.dart';

void main() {
  test('tempFileName is unique per attachment and has no path separators', () {
    expect(tempFileName(3, 'nota.pdf'), '3-nota.pdf');
    expect(tempFileName(4, '../../etc/passwd'), '4-.._.._etc_passwd');
    expect(tempFileName(5, r'a\b.pdf'), '5-a_b.pdf');
  });
}
