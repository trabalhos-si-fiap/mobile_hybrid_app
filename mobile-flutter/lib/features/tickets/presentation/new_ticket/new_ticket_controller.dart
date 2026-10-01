import 'dart:async';

import '../../../../core/api/api_exception.dart';
import '../../../../core/attachments/attachment_rules.dart' as rules;
import '../../../../core/attachments/picked_attachment.dart';
import '../../../../core/screen_controller.dart';
import '../../data/ticket_api.dart';
import '../../domain/ticket_models.dart';

class NewTicketController extends ScreenController {
  NewTicketController({required this._repository});

  final TicketRepository _repository;

  /// Nulo enquanto carrega.
  List<SegmentOption>? segments;
  String? segmentsError;
  String? selectedSegment;
  List<PickedAttachment> files = const [];
  List<String> fileProblems = const [];
  bool submitting = false;
  String? error;

  int get remainingSlots => rules.maxFiles - files.length;

  Future<void> loadSegments() async {
    segmentsError = null;
    notify();
    try {
      final loaded = await _repository.segments();
      segments = loaded;
      if (!loaded.any((option) => option.segment == selectedSegment)) {
        selectedSegment = null;
      }
    } on ApiException catch (failure) {
      if (failure.kind != ApiErrorKind.unauthorized) {
        segmentsError = failure.message;
      }
    }
    notify();
  }

  void selectSegment(String segment) {
    selectedSegment = segment;
    error = null;
    notify();
  }

  void attach(List<PickedAttachment> picked) {
    final result = rules.addFiles(files, picked);
    files = result.files;
    fileProblems = result.problems;
    notify();
  }

  void detach(PickedAttachment file) {
    files = [
      for (final current in files)
        if (!identical(current, file)) current,
    ];
    fileProblems = const [];
    notify();
  }

  /// Abre o ticket. Devolve o criado, ou nulo (o motivo fica em [error]).
  Future<TicketDetail?> submit(String description) async {
    if (submitting) return null;
    final problem = selectedSegment == null
        ? 'Escolha o tipo do problema.'
        : rules.textProblem(description, whenEmpty: 'Descreva o problema.');
    if (problem != null) {
      error = problem;
      notify();
      return null;
    }
    submitting = true;
    error = null;
    notify();
    try {
      return await _repository.open(
        segment: selectedSegment!,
        description: description.trim(),
        files: files,
      );
    } on ApiException catch (failure) {
      if (failure.kind != ApiErrorKind.unauthorized) error = failure.message;
      if (failure.kind == ApiErrorKind.unprocessable) {
        unawaited(loadSegments());
      }
      return null;
    } finally {
      submitting = false;
      notify();
    }
  }
}
