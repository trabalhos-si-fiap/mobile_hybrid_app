import 'dart:async';

import '../../../../core/api/api_exception.dart';
import '../../../../core/attachments/attachment_rules.dart' as rules;
import '../../../../core/attachments/picked_attachment.dart';
import '../../../../core/polling/poller.dart';
import '../../../../core/screen_controller.dart';
import '../../../notifications/notification_center.dart';
import '../../data/ticket_api.dart';
import '../../domain/ticket_models.dart';

typedef _Snapshot = ({TicketDetail ticket, List<TicketMessage> messages});

class TicketDetailController extends ScreenController {
  TicketDetailController({
    required this.ticketId,
    required this._repository,
    required this._center,
    Duration interval = const Duration(seconds: 10),
    bool observeLifecycle = true,
  }) {
    _poller = Poller<_Snapshot>(
      fetch: _fetch,
      interval: interval,
      onData: _onData,
      onError: _onError,
      observeLifecycle: observeLifecycle,
    );
  }

  final int ticketId;
  final TicketRepository _repository;
  final NotificationCenter _center;
  late final Poller<_Snapshot> _poller;
  StreamSubscription<Set<int>>? _updates;

  /// Nulo enquanto a primeira carga não volta.
  TicketDetail? ticket;
  List<TicketMessage> messages = const [];
  bool notFound = false;
  String? loadError;
  bool offline = false;

  List<PickedAttachment> files = const [];
  List<String> fileProblems = const [];
  bool sending = false;

  /// Confirmar ou reabrir em andamento.
  bool acting = false;
  String? actionError;

  int get remainingSlots => rules.maxFiles - files.length;

  void start() {
    _center.currentTicketId = ticketId;
    _updates = _center.updates.listen((ids) {
      if (ids.contains(ticketId)) unawaited(_poller.refresh());
    });
    _poller.start();
  }

  Future<void> reload() => _poller.refresh();

  Future<_Snapshot> _fetch() async {
    // Future.wait trata o erro das duas buscas; await em sequência deixaria
    // o erro da segunda sem ninguém ouvindo.
    final results = await Future.wait<Object>([
      _repository.detail(ticketId),
      _repository.messages(ticketId),
    ]);
    return (
      ticket: results[0] as TicketDetail,
      messages: results[1] as List<TicketMessage>,
    );
  }

  void _onData(_Snapshot snapshot) {
    ticket = snapshot.ticket;
    messages = snapshot.messages;
    notFound = false;
    loadError = null;
    offline = false;
    notify();
  }

  void _onError(Object error) {
    if (error is ApiException) {
      if (error.kind == ApiErrorKind.unauthorized) return;
      if (error.kind == ApiErrorKind.notFound) {
        _markNotFound();
        return;
      }
    }
    if (ticket == null) {
      loadError = error is ApiException
          ? error.message
          : const ApiException(ApiErrorKind.server).message;
    } else {
      offline = true;
    }
    notify();
  }

  void attach(List<PickedAttachment> picked) {
    final result = rules.addFiles(files, picked);
    files = result.files;
    fileProblems = result.problems;
    notify();
  }

  void detach(PickedAttachment file) {
    files = [
      for (final current in files)
        if (!identical(current, file)) current,
    ];
    fileProblems = const [];
    notify();
  }

  /// Envia [body] com os anexos atuais. Verdadeiro se a API aceitou.
  Future<bool> send(String body) async {
    if (sending) return false;
    final problem = rules.textProblem(body, whenEmpty: 'Escreva uma mensagem.');
    if (problem != null) {
      actionError = problem;
      notify();
      return false;
    }
    final sent = files;
    sending = true;
    actionError = null;
    notify();
    try {
      await _repository.sendMessage(ticketId, body: body.trim(), files: sent);
      files = [
        for (final file in files)
          if (!sent.contains(file)) file,
      ];
      fileProblems = const [];
      unawaited(_poller.refresh());
      return true;
    } on ApiException catch (error) {
      _handleActionError(error);
      return false;
    } finally {
      sending = false;
      notify();
    }
  }

  Future<void> confirm() => _act(() => _repository.confirm(ticketId));

  Future<void> reopen() => _act(() => _repository.reopen(ticketId));

  Future<void> _act(Future<TicketDetail> Function() action) async {
    if (acting) return;
    acting = true;
    actionError = null;
    notify();
    try {
      ticket = await action();
      unawaited(_poller.refresh());
    } on ApiException catch (error) {
      _handleActionError(error);
    } finally {
      acting = false;
      notify();
    }
  }

  void _handleActionError(ApiException error) {
    switch (error.kind) {
      case ApiErrorKind.unauthorized:
        return;
      case ApiErrorKind.notFound:
        _markNotFound();
      case ApiErrorKind.conflict:
        actionError = error.message;
        unawaited(_poller.refresh());
      default:
        actionError = error.message;
    }
  }

  void _markNotFound() {
    notFound = true;
    _poller.stop();
    notify();
  }

  @override
  void dispose() {
    if (_center.currentTicketId == ticketId) _center.currentTicketId = null;
    unawaited(_updates?.cancel());
    _poller.dispose();
    super.dispose();
  }
}
