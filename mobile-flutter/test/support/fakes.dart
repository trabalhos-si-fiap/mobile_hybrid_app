import 'dart:async';
import 'dart:typed_data';

import 'package:mobile_flutter/core/attachments/attachment_picker.dart';
import 'package:mobile_flutter/core/attachments/file_opener.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/features/chatbot/data/chatbot_api.dart';
import 'package:mobile_flutter/features/chatbot/domain/chatbot_models.dart';
import 'package:mobile_flutter/features/notifications/data/notification_api.dart';
import 'package:mobile_flutter/features/notifications/domain/app_notification.dart';
import 'package:mobile_flutter/features/notifications/local_notifier.dart';
import 'package:mobile_flutter/features/tickets/data/ticket_api.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

import 'test_data.dart';

class FakeNotificationRepository implements NotificationRepository {
  /// Respostas de list(unreadOnly: true), uma por chamada; a última se repete.
  final unreadResponses = <List<AppNotification>>[];

  /// Resposta de list() sem filtro.
  List<AppNotification> all = const [];
  Object? listError;
  Object? markReadError;
  final calls = <String>[];

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    calls.add(unreadOnly ? 'list unread' : 'list');
    final error = listError;
    if (error != null) throw error;
    if (!unreadOnly) return all;
    if (unreadResponses.isEmpty) return const [];
    return unreadResponses.length == 1
        ? unreadResponses.first
        : unreadResponses.removeAt(0);
  }

  @override
  Future<void> markRead(int id) async {
    calls.add('read $id');
    final error = markReadError;
    if (error != null) throw error;
  }

  @override
  Future<void> markAllRead() async {
    calls.add('read all');
    final error = markReadError;
    if (error != null) throw error;
  }
}

class FakeLocalNotifier implements LocalNotifier {
  void Function(String? payload)? onTap;
  var permissionRequests = 0;
  var cancelAllCalls = 0;
  final shown = <({int id, String title, String body, String payload})>[];

  /// Quando verdadeiro, todo método lança (plugin quebrado).
  bool failing = false;

  void _maybeFail() {
    if (failing) throw StateError('plugin quebrado');
  }

  @override
  Future<void> initialize(void Function(String? payload) onTap) async {
    _maybeFail();
    this.onTap = onTap;
  }

  @override
  Future<void> requestPermission() async {
    _maybeFail();
    permissionRequests++;
  }

  @override
  Future<void> show(int id, String title, String body, String payload) async {
    _maybeFail();
    shown.add((id: id, title: title, body: body, payload: payload));
  }

  @override
  Future<void> cancelAll() async {
    _maybeFail();
    cancelAllCalls++;
  }
}

class FakeTicketRepository implements TicketRepository {
  List<SegmentOption> segmentsResult = testSegments();
  Object? segmentsError;
  List<TicketSummary> mineResult = const [];
  Object? mineError;
  TicketDetail detailResult = testDetail();

  /// Vale para detail e messages.
  Object? detailError;
  List<TicketMessage> messagesResult = const [];

  /// Nulo: devolve testDetail(id: 12, status: EM_FILA).
  TicketDetail? openResult;

  /// Vale para open, sendMessage, confirm e reopen.
  Object? actionError;
  Uint8List downloadResult = pngBytes;
  Object? downloadError;

  /// Quando não nulo, as ações esperam por ele (requisição lenta).
  Completer<void>? gate;

  /// Quando não nulo, mine, detail e messages esperam por ele (carregando).
  Completer<void>? readGate;

  final calls = <String>[];
  final sentBodies = <String>[];
  final sentFiles = <List<PickedAttachment>>[];

  /// O chatbotConversationId de cada open (nulo quando foi sem conversa).
  final openedConversations = <int?>[];

  static void _throwIf(Object? error) {
    if (error != null) throw error;
  }

  @override
  Future<List<SegmentOption>> segments() async {
    calls.add('segments');
    _throwIf(segmentsError);
    return segmentsResult;
  }

  @override
  Future<List<TicketSummary>> mine() async {
    calls.add('mine');
    await readGate?.future;
    _throwIf(mineError);
    return mineResult;
  }

  @override
  Future<TicketDetail> detail(int id) async {
    calls.add('detail $id');
    await readGate?.future;
    _throwIf(detailError);
    return detailResult;
  }

  @override
  Future<List<TicketMessage>> messages(int id) async {
    calls.add('messages $id');
    await readGate?.future;
    _throwIf(detailError);
    return messagesResult;
  }

  @override
  Future<TicketDetail> open({
    required String segment,
    required String description,
    required List<PickedAttachment> files,
    int? chatbotConversationId,
  }) async {
    calls.add('open $segment');
    sentBodies.add(description);
    sentFiles.add(List.of(files));
    openedConversations.add(chatbotConversationId);
    await gate?.future;
    _throwIf(actionError);
    return openResult ??
        testDetail(id: 12, status: TicketStatus.emFila, assigneeName: null);
  }

  @override
  Future<TicketMessage> sendMessage(
    int id, {
    required String body,
    required List<PickedAttachment> files,
  }) async {
    calls.add('send $id');
    sentBodies.add(body);
    sentFiles.add(List.of(files));
    await gate?.future;
    _throwIf(actionError);
    return testMessage(
      id: 99,
      senderType: SenderType.user,
      senderName: 'Ana',
      body: body,
    );
  }

  /// Como a API: depois de confirmar, o detalhe passa a vir FECHADO.
  @override
  Future<TicketDetail> confirm(int id) async {
    calls.add('confirm $id');
    await gate?.future;
    _throwIf(actionError);
    return detailResult = testDetail(id: id, status: TicketStatus.fechado);
  }

  /// Como a API: depois de reabrir, o detalhe passa a vir EM_ATENDIMENTO.
  @override
  Future<TicketDetail> reopen(int id) async {
    calls.add('reopen $id');
    await gate?.future;
    _throwIf(actionError);
    return detailResult = testDetail(
      id: id,
      status: TicketStatus.emAtendimento,
    );
  }

  @override
  Future<Uint8List> download(String downloadPath) async {
    calls.add('download $downloadPath');
    _throwIf(downloadError);
    return downloadResult;
  }
}

class FakeAttachmentPicker implements AttachmentPicker {
  List<PickedAttachment> next = const [];
  Object? error;
  final requests = <({AttachmentSource source, int limit})>[];

  @override
  Future<List<PickedAttachment>> pick(
    AttachmentSource source, {
    required int limit,
  }) async {
    requests.add((source: source, limit: limit));
    final failure = error;
    if (failure != null) throw failure;
    return next;
  }
}

class FakeFileOpener implements FileOpener {
  final opened = <String>[];
  Object? error;

  @override
  Future<void> openPdf(
    int attachmentId,
    String fileName,
    Uint8List bytes,
  ) async {
    opened.add(fileName);
    final failure = error;
    if (failure != null) throw failure;
  }
}

class FakeChatbotRepository implements ChatbotRepository {
  ChatbotTurn startResult = greetingTurn();
  Object? startError;

  /// Respostas de send(), uma por chamada; a última se repete.
  final sendResults = <ChatbotTurn>[];
  Object? sendError;

  /// Quando não nulo, start e send esperam por ele (requisição lenta).
  Completer<void>? gate;

  final calls = <String>[];
  final sent = <ChatbotReply>[];

  @override
  Future<ChatbotTurn> start() async {
    calls.add('start');
    await gate?.future;
    final error = startError;
    if (error != null) throw error;
    return startResult;
  }

  @override
  Future<ChatbotTurn> send(int conversationId, ChatbotReply reply) async {
    calls.add('send $conversationId');
    sent.add(reply);
    await gate?.future;
    final error = sendError;
    if (error != null) throw error;
    return sendResults.length == 1
        ? sendResults.first
        : sendResults.removeAt(0);
  }
}
