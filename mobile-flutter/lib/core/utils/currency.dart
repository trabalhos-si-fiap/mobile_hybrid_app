/// Formata um valor em Reais no padrão brasileiro (R$ 1.234,56).
///
/// Portado de `formatBRL` do projeto edu-kt (que usava NumberFormat pt-BR).
String formatBRL(double value) {
  final negative = value < 0;
  final cents = (value.abs() * 100).round();
  final intPart = (cents ~/ 100).toString();
  final decPart = (cents % 100).toString().padLeft(2, '0');

  final grouped = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) grouped.write('.');
    grouped.write(intPart[i]);
  }

  return '${negative ? '-' : ''}R\$ $grouped,$decPart';
}
