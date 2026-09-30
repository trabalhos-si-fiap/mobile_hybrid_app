import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

Map<String, dynamic> _attachmentJson() => {
  'id': 3,
  'fileName': 'tela.png',
  'contentType': 'image/png',
  'sizeBytes': 2048,
  'downloadPath': '/tickets/7/attachments/3',
};

void main() {
  test('enums parse the API values', () {
    expect(TicketStatus.fromApi('EM_ATENDIMENTO'), TicketStatus.emAtendimento);
    expect(SlaStatus.fromApi('ESTOURADO'), SlaStatus.estourado);
    expect(SenderType.fromApi('SYSTEM'), SenderType.system);
    expect(() => TicketStatus.fromApi('PERDIDO'), throwsFormatException);
  });

  test('Attachment.fromJson and isImage', () {
    final image = Attachment.fromJson(_attachmentJson());
    expect(image.id, 3);
    expect(image.fileName, 'tela.png');
    expect(image.sizeBytes, 2048);
    expect(image.downloadPath, '/tickets/7/attachments/3');
    expect(image.isImage, isTrue);

    final pdf = Attachment.fromJson({
      ..._attachmentJson(),
      'contentType': 'application/pdf',
    });
    expect(pdf.isImage, isFalse);
  });

  test('SegmentOption.fromJson', () {
    final option = SegmentOption.fromJson({
      'segment': 'DEFEITO_APP',
      'label': 'Defeito no App',
      'queue': 'TECNOLOGIA',
      'skill': 'DESENVOLVEDOR',
      'slaMinutes': 240,
    });
    expect(option.segment, 'DEFEITO_APP');
    expect(option.label, 'Defeito no App');
    expect(option.slaMinutes, 240);
  });

  test('TicketSummary.fromJson with and without the optional fields', () {
    final json = {
      'id': 7,
      'segment': 'DEFEITO_APP',
      'segmentLabel': 'Defeito no App',
      'status': 'EM_FILA',
      'priority': 'ALTA',
      'slaStatus': 'NO_PRAZO',
      'slaDueAt': '2026-09-30T17:00:00.123456Z',
      'requesterName': 'Ana',
      'assigneeName': 'Dev',
      'engineeringAlert': false,
      'createdAt': '2026-09-30T13:00:00Z',
      'updatedAt': '2026-09-30T13:05:00Z',
    };

    final full = TicketSummary.fromJson(json);
    expect(full.id, 7);
    expect(full.segmentLabel, 'Defeito no App');
    expect(full.status, TicketStatus.emFila);
    expect(full.slaStatus, SlaStatus.noPrazo);
    expect(full.slaDueAt, DateTime.utc(2026, 9, 30, 17, 0, 0, 123, 456));
    expect(full.assigneeName, 'Dev');
    expect(full.updatedAt, DateTime.utc(2026, 9, 30, 13, 5));

    final bare = TicketSummary.fromJson({
      ...json,
      'slaDueAt': null,
      'assigneeName': null,
    });
    expect(bare.slaDueAt, isNull);
    expect(bare.assigneeName, isNull);
  });

  test('TicketDetail.fromJson reads the assignee name and the attachments', () {
    final json = {
      'id': 7,
      'segment': 'DEFEITO_APP',
      'segmentLabel': 'Defeito no App',
      'queue': 'TECNOLOGIA',
      'status': 'RESOLVIDO',
      'priority': 'ALTA',
      'channel': 'APP',
      'description': 'O app fecha sozinho.',
      'slaStatus': 'CUMPRIDO',
      'slaDueAt': '2026-09-30T17:00:00Z',
      'requester': {'id': 1, 'name': 'Ana', 'email': 'ana@edu.com'},
      'assignee': {'id': 4, 'name': 'Dev'},
      'engineeringAlert': false,
      'engineeringAlertReason': null,
      'attachments': [_attachmentJson()],
      'createdAt': '2026-09-30T13:00:00Z',
      'updatedAt': '2026-09-30T14:00:00Z',
      'assumedAt': '2026-09-30T13:10:00Z',
      'resolvedAt': '2026-09-30T14:00:00Z',
      'closedAt': null,
    };

    final detail = TicketDetail.fromJson(json);
    expect(detail.segment, 'DEFEITO_APP');
    expect(detail.status, TicketStatus.resolvido);
    expect(detail.description, 'O app fecha sozinho.');
    expect(detail.assigneeName, 'Dev');
    expect(detail.attachments.single.fileName, 'tela.png');

    final unassigned = TicketDetail.fromJson({
      ...json,
      'assignee': null,
      'slaDueAt': null,
    });
    expect(unassigned.assigneeName, isNull);
    expect(unassigned.slaDueAt, isNull);
  });

  test('TicketMessage.fromJson', () {
    final message = TicketMessage.fromJson({
      'id': 11,
      'senderType': 'EMPLOYEE',
      'senderName': 'Dev',
      'body': 'Olá! Já estou vendo.',
      'attachments': [_attachmentJson()],
      'createdAt': '2026-09-30T13:20:00Z',
    });
    expect(message.senderType, SenderType.employee);
    expect(message.senderName, 'Dev');
    expect(message.body, 'Olá! Já estou vendo.');
    expect(message.attachments, hasLength(1));
    expect(message.createdAt, DateTime.utc(2026, 9, 30, 13, 20));
  });
}
