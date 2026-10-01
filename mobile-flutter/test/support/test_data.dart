import 'dart:convert';
import 'dart:typed_data';

import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/features/notifications/domain/app_notification.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

import 'json_fixtures.dart';

/// Relógio fixo dos testes de tela.
final testNow = DateTime.utc(2026, 9, 30, 13);

/// PNG 1x1 válido.
final pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF\n'));

PickedAttachment pickedPng({String name = 'tela.png'}) =>
    PickedAttachment(name: name, bytes: pngBytes);

PickedAttachment pickedPdf({String name = 'nota.pdf'}) =>
    PickedAttachment(name: name, bytes: pdfBytes);

AppNotification testNotification({
  int id = 21,
  int? ticketId = 7,
  bool read = false,
  String title = 'Nova mensagem',
  String body = 'Dev respondeu no ticket #7.',
}) => AppNotification.fromJson(
  notificationJson(
    id: id,
    ticketId: ticketId,
    read: read,
    title: title,
    body: body,
  ),
);

Attachment testAttachment({
  int id = 3,
  String fileName = 'tela.png',
  String contentType = 'image/png',
  int sizeBytes = 2048,
}) => Attachment(
  id: id,
  fileName: fileName,
  contentType: contentType,
  sizeBytes: sizeBytes,
  downloadPath: '/tickets/7/attachments/$id',
);

List<SegmentOption> testSegments() => const [
  SegmentOption(
    segment: 'DEFEITO_APP',
    label: 'Defeito no App',
    slaMinutes: 240,
  ),
  SegmentOption(
    segment: 'PROBLEMA_PEDIDO',
    label: 'Problemas com pedido',
    slaMinutes: 480,
  ),
  SegmentOption(
    segment: 'FEEDBACK_SUGESTAO',
    label: 'Feedback / Sugestões',
    slaMinutes: 2880,
  ),
];

TicketSummary testSummary({
  int id = 7,
  TicketStatus status = TicketStatus.emFila,
  String? assigneeName,
  DateTime? updatedAt,
}) => TicketSummary(
  id: id,
  segmentLabel: 'Defeito no App',
  status: status,
  slaStatus: SlaStatus.noPrazo,
  slaDueAt: DateTime.utc(2026, 9, 30, 17),
  assigneeName: assigneeName,
  createdAt: DateTime.utc(2026, 9, 30, 12),
  updatedAt: updatedAt ?? DateTime.utc(2026, 9, 30, 12, 55),
);

TicketDetail testDetail({
  int id = 7,
  TicketStatus status = TicketStatus.emAtendimento,
  SlaStatus slaStatus = SlaStatus.noPrazo,
  DateTime? slaDueAt,
  String? assigneeName = 'Dev',
  String description = 'O app fecha sozinho ao abrir o carrinho.',
  List<Attachment> attachments = const [],
}) => TicketDetail(
  id: id,
  segment: 'DEFEITO_APP',
  segmentLabel: 'Defeito no App',
  status: status,
  slaStatus: slaStatus,
  slaDueAt: slaDueAt ?? DateTime.utc(2026, 9, 30, 17),
  description: description,
  assigneeName: assigneeName,
  attachments: attachments,
  createdAt: DateTime.utc(2026, 9, 30, 12),
  updatedAt: DateTime.utc(2026, 9, 30, 12, 55),
);

TicketMessage testMessage({
  int id = 11,
  SenderType senderType = SenderType.employee,
  String senderName = 'Dev',
  String body = 'Olá! Já estou vendo.',
  List<Attachment> attachments = const [],
  DateTime? createdAt,
}) => TicketMessage(
  id: id,
  senderType: senderType,
  senderName: senderName,
  body: body,
  attachments: attachments,
  createdAt: createdAt ?? DateTime.utc(2026, 9, 30, 12, 20),
);

/// JWT sem assinatura válida, só para o app ler role e exp.
String fakeJwt({String role = 'USER', DateTime? expiresAt}) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp =
      (expiresAt ?? testNow.add(const Duration(hours: 2)))
          .millisecondsSinceEpoch ~/
      1000;
  return '${part({'alg': 'HS256'})}.'
      '${part({'sub': 'ana@edu.com', 'role': role, 'exp': exp})}.assinatura';
}
