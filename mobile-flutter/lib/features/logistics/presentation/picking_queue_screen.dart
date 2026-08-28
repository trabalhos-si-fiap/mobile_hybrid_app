import 'package:flutter/material.dart';

/// Tela de fila do separador — não implementada nesta versão.
/// Exibida após login de usuários com role `separador`.
class SeparadorFilaScreen extends StatelessWidget {
  const SeparadorFilaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fila de Separação')),
      body: const Center(
        child: Text('Módulo de separação em desenvolvimento.'),
      ),
    );
  }
}
