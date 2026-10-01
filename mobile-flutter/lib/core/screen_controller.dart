import 'package:flutter/foundation.dart';

/// Base dos controllers de tela. Uma resposta da API pode chegar depois de o
/// usuário sair da tela; aí notify() não faz nada, em vez de lançar.
class ScreenController extends ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @protected
  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
