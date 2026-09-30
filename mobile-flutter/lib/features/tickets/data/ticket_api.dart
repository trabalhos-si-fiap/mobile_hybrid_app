import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../../core/attachments/picked_attachment.dart';
import '../domain/ticket_models.dart';

/// Endpoints de tickets do usuário. Lança só ApiException.
abstract interface class TicketRepository {
  Future<List<SegmentOption>> segments();

  Future<List<TicketSummary>> mine();

  Future<TicketDetail> detail(int id);

  Future<List<TicketMessage>> messages(int id);

  Future<TicketDetail> open({
    required String segment,
    required String description,
    required List<PickedAttachment> files,
  });

  Future<TicketMessage> sendMessage(
    int id, {
    required String body,
    required List<PickedAttachment> files,
  });

  Future<TicketDetail> confirm(int id);

  Future<TicketDetail> reopen(int id);

  Future<Uint8List> download(String downloadPath);
}

class HttpTicketRepository implements TicketRepository {
  HttpTicketRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<SegmentOption>> segments() async =>
      decodeList(await _api.getJson('/segments'), SegmentOption.fromJson);

  @override
  Future<List<TicketSummary>> mine() async =>
      decodeList(await _api.getJson('/tickets/mine'), TicketSummary.fromJson);

  @override
  Future<TicketDetail> detail(int id) async =>
      TicketDetail.fromJson(decodeMap(await _api.getJson('/tickets/$id')));

  @override
  Future<List<TicketMessage>> messages(int id) async => decodeList(
    await _api.getJson('/tickets/$id/messages'),
    TicketMessage.fromJson,
  );

  @override
  Future<TicketDetail> open({
    required String segment,
    required String description,
    required List<PickedAttachment> files,
  }) async => TicketDetail.fromJson(
    decodeMap(
      await _api.postMultipart(
        '/tickets',
        fields: {'segment': segment, 'description': description},
        files: files,
      ),
    ),
  );

  @override
  Future<TicketMessage> sendMessage(
    int id, {
    required String body,
    required List<PickedAttachment> files,
  }) async => TicketMessage.fromJson(
    decodeMap(
      await _api.postMultipart(
        '/tickets/$id/messages',
        fields: {'body': body},
        files: files,
      ),
    ),
  );

  @override
  Future<TicketDetail> confirm(int id) async => TicketDetail.fromJson(
    decodeMap(await _api.postJson('/tickets/$id/confirm')),
  );

  @override
  Future<TicketDetail> reopen(int id) async => TicketDetail.fromJson(
    decodeMap(await _api.postJson('/tickets/$id/reopen')),
  );

  @override
  Future<Uint8List> download(String downloadPath) =>
      _api.getBytes(downloadPath);
}
