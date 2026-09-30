import 'dart:async';

import 'package:flutter/widgets.dart';

/// Consulta periódica. Busca na hora e a cada [interval]; para com o app em
/// segundo plano e busca de novo ao voltar. Uma resposta superada por outra
/// busca, ou que chegue depois do stop, é descartada.
class Poller<T> with WidgetsBindingObserver {
  Poller({
    required this.fetch,
    required this.interval,
    required this.onData,
    required this.onError,
    this.observeLifecycle = true,
  });

  final Future<T> Function() fetch;
  final Duration interval;
  final void Function(T data) onData;
  final void Function(Object error) onError;

  /// Falso nos testes de unidade, que chamam didChangeAppLifecycleState direto.
  final bool observeLifecycle;

  Timer? _timer;
  int _generation = 0;
  bool _running = false;
  bool _paused = false;
  bool _inFlight = false;

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    _paused = false;
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    unawaited(_fetch(force: true));
    _schedule();
  }

  /// Busca agora e reinicia o intervalo; completa quando a busca termina.
  Future<void> refresh() async {
    if (!_running || _paused) return;
    _schedule();
    await _fetch(force: true);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    _generation++;
    _inFlight = false;
    if (observeLifecycle) WidgetsBinding.instance.removeObserver(this);
  }

  void dispose() => stop();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_paused) return;
        _paused = false;
        unawaited(_fetch(force: true));
        _schedule();
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _paused = true;
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(_fetch()));
  }

  Future<void> _fetch({bool force = false}) async {
    if (_inFlight && !force) return;
    final generation = ++_generation;
    _inFlight = true;
    try {
      final data = await fetch();
      if (generation == _generation && _running) onData(data);
    } catch (error) {
      if (generation == _generation && _running) onError(error);
    } finally {
      if (generation == _generation) _inFlight = false;
    }
  }
}
