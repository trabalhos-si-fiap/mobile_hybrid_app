import 'dart:typed_data';

import '../../features/tickets/domain/ticket_models.dart';

/// Anexos baixados, em memória, por id. Pedidos simultâneos do mesmo anexo
/// dividem um só download; um download que falhou é tentado de novo.
class AttachmentCache {
  AttachmentCache(this._download);

  final Future<Uint8List> Function(String downloadPath) _download;
  final _cache = <int, Future<Uint8List>>{};

  Future<Uint8List> load(Attachment attachment) {
    final cached = _cache[attachment.id];
    if (cached != null) return cached;
    final future = _download(attachment.downloadPath);
    _cache[attachment.id] = future;
    future.then(
      (_) {},
      onError: (Object _) {
        _cache.remove(attachment.id);
      },
    );
    return future;
  }

  /// Ao sair: a próxima conta não vê anexos da anterior.
  void clear() => _cache.clear();
}
