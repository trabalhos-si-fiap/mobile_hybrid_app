/// Tipos do openapi.yaml usados pelo app do usuário. Campos que a tela não
/// usa (prioridade, fila, solicitante) ficam de fora de propósito.
T _fromApi<T>(List<T> values, String Function(T) apiValue, String value) {
  for (final candidate in values) {
    if (apiValue(candidate) == value) return candidate;
  }
  throw FormatException('Valor desconhecido: $value');
}

DateTime? _dateOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

List<Attachment> _attachments(Object? value) => [
  for (final item in (value as List<dynamic>? ?? const []))
    Attachment.fromJson(item as Map<String, dynamic>),
];

enum TicketStatus {
  aberto('ABERTO'),
  emFila('EM_FILA'),
  emAtendimento('EM_ATENDIMENTO'),
  escalado('ESCALADO'),
  resolvido('RESOLVIDO'),
  fechado('FECHADO');

  const TicketStatus(this.apiValue);

  final String apiValue;

  static TicketStatus fromApi(String value) =>
      _fromApi(values, (status) => status.apiValue, value);
}

enum SlaStatus {
  noPrazo('NO_PRAZO'),
  emRisco('EM_RISCO'),
  estourado('ESTOURADO'),
  cumprido('CUMPRIDO'),
  violado('VIOLADO');

  const SlaStatus(this.apiValue);

  final String apiValue;

  static SlaStatus fromApi(String value) =>
      _fromApi(values, (sla) => sla.apiValue, value);
}

enum SenderType {
  user('USER'),
  employee('EMPLOYEE'),
  system('SYSTEM');

  const SenderType(this.apiValue);

  final String apiValue;

  static SenderType fromApi(String value) =>
      _fromApi(values, (sender) => sender.apiValue, value);
}

class Attachment {
  const Attachment({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.downloadPath,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    id: json['id'] as int,
    fileName: json['fileName'] as String,
    contentType: json['contentType'] as String,
    sizeBytes: json['sizeBytes'] as int,
    downloadPath: json['downloadPath'] as String,
  );

  final int id;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  /// Relativo à base da API, ex. /tickets/7/attachments/3.
  final String downloadPath;

  bool get isImage => contentType.startsWith('image/');
}

class SegmentOption {
  const SegmentOption({
    required this.segment,
    required this.label,
    required this.slaMinutes,
  });

  factory SegmentOption.fromJson(Map<String, dynamic> json) => SegmentOption(
    segment: json['segment'] as String,
    label: json['label'] as String,
    slaMinutes: json['slaMinutes'] as int,
  );

  final String segment;
  final String label;
  final int slaMinutes;
}

class TicketSummary {
  const TicketSummary({
    required this.id,
    required this.segmentLabel,
    required this.status,
    required this.slaStatus,
    required this.slaDueAt,
    required this.assigneeName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TicketSummary.fromJson(Map<String, dynamic> json) => TicketSummary(
    id: json['id'] as int,
    segmentLabel: json['segmentLabel'] as String,
    status: TicketStatus.fromApi(json['status'] as String),
    slaStatus: SlaStatus.fromApi(json['slaStatus'] as String),
    slaDueAt: _dateOrNull(json['slaDueAt']),
    assigneeName: json['assigneeName'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final int id;
  final String segmentLabel;
  final TicketStatus status;
  final SlaStatus slaStatus;
  final DateTime? slaDueAt;
  final String? assigneeName;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TicketDetail {
  const TicketDetail({
    required this.id,
    required this.segment,
    required this.segmentLabel,
    required this.status,
    required this.slaStatus,
    required this.slaDueAt,
    required this.description,
    required this.assigneeName,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TicketDetail.fromJson(Map<String, dynamic> json) => TicketDetail(
    id: json['id'] as int,
    segment: json['segment'] as String,
    segmentLabel: json['segmentLabel'] as String,
    status: TicketStatus.fromApi(json['status'] as String),
    slaStatus: SlaStatus.fromApi(json['slaStatus'] as String),
    slaDueAt: _dateOrNull(json['slaDueAt']),
    description: json['description'] as String,
    assigneeName:
        (json['assignee'] as Map<String, dynamic>?)?['name'] as String?,
    attachments: _attachments(json['attachments']),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final int id;
  final String segment;
  final String segmentLabel;
  final TicketStatus status;
  final SlaStatus slaStatus;
  final DateTime? slaDueAt;
  final String description;
  final String? assigneeName;

  /// Anexos da abertura.
  final List<Attachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TicketMessage {
  const TicketMessage({
    required this.id,
    required this.senderType,
    required this.senderName,
    required this.body,
    required this.attachments,
    required this.createdAt,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) => TicketMessage(
    id: json['id'] as int,
    senderType: SenderType.fromApi(json['senderType'] as String),
    senderName: json['senderName'] as String,
    body: json['body'] as String,
    attachments: _attachments(json['attachments']),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final int id;
  final SenderType senderType;
  final String senderName;
  final String body;
  final List<Attachment> attachments;
  final DateTime createdAt;
}
