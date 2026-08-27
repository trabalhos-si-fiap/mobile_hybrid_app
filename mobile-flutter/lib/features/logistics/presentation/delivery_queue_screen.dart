import 'package:flutter/material.dart';

/// Tela de fila do entregador — não implementada nesta versão.
/// Exibida após login de usuários com role `entregador`.
class EntregadorFilaScreen extends StatelessWidget {
  const EntregadorFilaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fila de Entregas')),
      body: const Center(
        child: Text('Módulo de entregas em desenvolvimento.'),
      ),
    );
  }
}
