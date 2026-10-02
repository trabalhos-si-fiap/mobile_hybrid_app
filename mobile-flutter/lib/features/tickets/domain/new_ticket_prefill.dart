/// O que o Mentor Edu passa ao formulário "Abrir ticket" na passagem para o
/// atendente. Segmento e descrição continuam editáveis.
class NewTicketPrefill {
  const NewTicketPrefill({
    required this.conversationId,
    required this.segment,
    required this.description,
  });

  final int conversationId;

  /// Nulo quando o usuário não escolheu nenhum segmento na conversa.
  final String? segment;
  final String description;

  @override
  bool operator ==(Object other) =>
      other is NewTicketPrefill &&
      other.conversationId == conversationId &&
      other.segment == segment &&
      other.description == description;

  @override
  int get hashCode => Object.hash(conversationId, segment, description);

  @override
  String toString() =>
      'NewTicketPrefill($conversationId, $segment, $description)';
}
