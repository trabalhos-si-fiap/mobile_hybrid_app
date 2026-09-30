/// Respostas da API no formato do openapi.yaml, para os testes.
Map<String, dynamic> attachmentJson({
  int id = 3,
  int ticketId = 7,
  String fileName = 'tela.png',
  String contentType = 'image/png',
  int sizeBytes = 2048,
}) => {
  'id': id,
  'fileName': fileName,
  'contentType': contentType,
  'sizeBytes': sizeBytes,
  'downloadPath': '/tickets/$ticketId/attachments/$id',
};

Map<String, dynamic> segmentJson({
  String segment = 'DEFEITO_APP',
  String label = 'Defeito no App',
  int slaMinutes = 240,
}) => {
  'segment': segment,
  'label': label,
  'queue': 'TECNOLOGIA',
  'skill': 'DESENVOLVEDOR',
  'slaMinutes': slaMinutes,
};

Map<String, dynamic> summaryJson({
  int id = 7,
  String status = 'EM_FILA',
  String slaStatus = 'NO_PRAZO',
  String? assigneeName,
  String updatedAt = '2026-09-30T12:55:00Z',
}) => {
  'id': id,
  'segment': 'DEFEITO_APP',
  'segmentLabel': 'Defeito no App',
  'status': status,
  'priority': 'ALTA',
  'slaStatus': slaStatus,
  'slaDueAt': '2026-09-30T17:00:00Z',
  'requesterName': 'Ana',
  'assigneeName': assigneeName,
  'engineeringAlert': false,
  'createdAt': '2026-09-30T12:00:00Z',
  'updatedAt': updatedAt,
};

Map<String, dynamic> detailJson({
  int id = 7,
  String status = 'EM_ATENDIMENTO',
  String slaStatus = 'NO_PRAZO',
  String? slaDueAt = '2026-09-30T17:00:00Z',
  String? assigneeName = 'Dev',
  String description = 'O app fecha sozinho ao abrir o carrinho.',
  List<Map<String, dynamic>> attachments = const [],
}) => {
  'id': id,
  'segment': 'DEFEITO_APP',
  'segmentLabel': 'Defeito no App',
  'queue': 'TECNOLOGIA',
  'status': status,
  'priority': 'ALTA',
  'channel': 'APP',
  'description': description,
  'slaStatus': slaStatus,
  'slaDueAt': slaDueAt,
  'requester': {'id': 1, 'name': 'Ana', 'email': 'ana@edu.com'},
  'assignee': assigneeName == null ? null : {'id': 4, 'name': assigneeName},
  'engineeringAlert': false,
  'engineeringAlertReason': null,
  'attachments': attachments,
  'createdAt': '2026-09-30T12:00:00Z',
  'updatedAt': '2026-09-30T12:55:00Z',
  'assumedAt': null,
  'resolvedAt': null,
  'closedAt': null,
};

Map<String, dynamic> messageJson({
  int id = 11,
  String senderType = 'EMPLOYEE',
  String senderName = 'Dev',
  String body = 'Olá! Já estou vendo.',
  List<Map<String, dynamic>> attachments = const [],
  String createdAt = '2026-09-30T12:20:00Z',
}) => {
  'id': id,
  'senderType': senderType,
  'senderName': senderName,
  'body': body,
  'attachments': attachments,
  'createdAt': createdAt,
};

Map<String, dynamic> notificationJson({
  int id = 21,
  int? ticketId = 7,
  bool read = false,
  String title = 'Nova mensagem',
  String body = 'Dev respondeu no ticket #7.',
}) => {
  'id': id,
  'ticketId': ticketId,
  'type': 'NOVA_MENSAGEM',
  'title': title,
  'body': body,
  'read': read,
  'createdAt': '2026-09-30T12:50:00Z',
};
