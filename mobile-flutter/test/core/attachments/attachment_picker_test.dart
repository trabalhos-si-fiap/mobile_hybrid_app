import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_flutter/core/attachments/attachment_picker.dart';
import 'package:mobile_flutter/core/attachments/attachment_rules.dart';

/// Câmera falsa: devolve sempre o mesmo arquivo.
class _FakeImagePicker extends ImagePicker {
  _FakeImagePicker(this.file);

  final XFile file;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => file;
}

/// Arquivo acima do limite que registra se alguém leu os bytes.
class _HugeFile extends XFile {
  _HugeFile()
    : super.fromData(
        Uint8List(0),
        name: 'enorme.jpg',
        path: 'enorme.jpg',
        mimeType: 'image/jpeg',
      );

  var read = false;

  @override
  Future<int> length() async => maxFileBytes + 1;

  @override
  Future<Uint8List> readAsBytes() async {
    read = true;
    return Uint8List(0);
  }
}

void main() {
  test('a file over 5 MB is refused by its size, without being read', () async {
    final huge = _HugeFile();
    final picker = DeviceAttachmentPicker(imagePicker: _FakeImagePicker(huge));

    final picked = await picker.pick(AttachmentSource.camera, limit: 5);

    expect(huge.read, isFalse);
    expect(picked.single.size, maxFileBytes + 1);
    expect(fileProblem(picked.single), 'enorme.jpg: maior que 5 MB.');
  });

  test('a file within the limit is read', () async {
    final photo = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'foto.jpg',
      path: 'foto.jpg',
      mimeType: 'image/jpeg',
    );
    final picker = DeviceAttachmentPicker(imagePicker: _FakeImagePicker(photo));

    final picked = await picker.pick(AttachmentSource.camera, limit: 5);

    expect(picked.single.bytes, [1, 2, 3]);
    expect(picked.single.size, 3);
    expect(fileProblem(picked.single), isNull);
  });
}
