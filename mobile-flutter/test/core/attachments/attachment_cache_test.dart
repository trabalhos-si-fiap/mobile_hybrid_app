import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/attachments/attachment_cache.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

const _attachment = Attachment(
  id: 3,
  fileName: 'tela.png',
  contentType: 'image/png',
  sizeBytes: 2,
  downloadPath: '/tickets/7/attachments/3',
);

void main() {
  test(
    'concurrent loads share one download, and the result is cached',
    () async {
      final paths = <String>[];
      final pending = Completer<Uint8List>();
      final cache = AttachmentCache((path) {
        paths.add(path);
        return pending.future;
      });

      final first = cache.load(_attachment);
      final second = cache.load(_attachment);
      pending.complete(Uint8List.fromList([1, 2]));

      expect(await first, [1, 2]);
      expect(await second, [1, 2]);
      expect(await cache.load(_attachment), [1, 2]);
      expect(paths, ['/tickets/7/attachments/3']);
    },
  );

  test('a failed download is tried again on the next load', () async {
    var calls = 0;
    final cache = AttachmentCache((_) async {
      if (calls++ == 0) throw const ApiException(ApiErrorKind.network);
      return Uint8List.fromList([9]);
    });

    await expectLater(cache.load(_attachment), throwsA(isA<ApiException>()));
    expect(await cache.load(_attachment), [9]);
    expect(calls, 2);
  });

  test('clear forgets everything', () async {
    var calls = 0;
    final cache = AttachmentCache((_) async {
      calls++;
      return Uint8List(1);
    });

    await cache.load(_attachment);
    cache.clear();
    await cache.load(_attachment);

    expect(calls, 2);
  });
}
