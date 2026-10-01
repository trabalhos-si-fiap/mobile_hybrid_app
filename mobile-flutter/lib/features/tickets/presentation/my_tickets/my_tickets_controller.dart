import 'dart:async';

import '../../../../core/api/api_exception.dart';
import '../../../../core/polling/poller.dart';
import '../../../../core/screen_controller.dart';
import '../../../notifications/notification_center.dart';
import '../../data/ticket_api.dart';
import '../../domain/ticket_models.dart';
import '../../domain/ticket_rules.dart';

class MyTicketsController extends ScreenController {
  MyTicketsController({
    required this._repository,
    required this._center,
    Duration interval = const Duration(seconds: 30),
    bool observeLifecycle = true,
  }) {
    _poller = Poller<List<TicketSummary>>(
      fetch: _repository.mine,
      interval: interval,
      onData: _onData,
      onError: _onError,
      observeLifecycle: observeLifecycle,
    );
  }

  final TicketRepository _repository;
  final NotificationCenter _center;
  late final Poller<List<TicketSummary>> _poller;
  StreamSubscription<Set<int>>? _updates;

  /// Nulo enquanto a primeira carga não volta.
  List<TicketSummary>? tickets;

  /// Erro da primeira carga (sem nada na tela).
  String? loadError;

  /// Falha no polling com a lista já na tela.
  bool offline = false;

  void start() {
    _updates = _center.updates.listen((_) => unawaited(_poller.refresh()));
    _poller.start();
  }

  Future<void> reload() => _poller.refresh();

  void _onData(List<TicketSummary> data) {
    tickets = sortForUser(data);
    loadError = null;
    offline = false;
    notify();
  }

  void _onError(Object error) {
    // O 401 já está levando ao login.
    if (error is ApiException && error.kind == ApiErrorKind.unauthorized) {
      return;
    }
    if (tickets == null) {
      loadError = error is ApiException
          ? error.message
          : const ApiException(ApiErrorKind.server).message;
    } else {
      offline = true;
    }
    notify();
  }

  @override
  void dispose() {
    unawaited(_updates?.cancel());
    _poller.dispose();
    super.dispose();
  }
}
