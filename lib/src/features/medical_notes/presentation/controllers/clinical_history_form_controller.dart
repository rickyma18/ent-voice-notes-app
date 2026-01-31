import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/medical_note_type.dart';
import '../../domain/entities/note_status.dart';
import '../../presentation/controllers/medical_notes_controller.dart';
import '../../presentation/models/ai_suggestion_models.dart';

import '../../application/vital_signs_parser.dart';

part 'clinical_history_form_controller.g.dart';

/// Arguments to initialize the form
class ClinicalHistoryFormArgs {
  final String patientId;
  final String doctorId;
  final MedicalNoteEntity? existingNote;
  final String? initialRawTranscript;
  final String sessionId;

  const ClinicalHistoryFormArgs({
    required this.patientId,
    required this.doctorId,
    this.existingNote,
    this.initialRawTranscript,
    required this.sessionId,
  });

  bool get isEditMode => existingNote != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClinicalHistoryFormArgs &&
          runtimeType == other.runtimeType &&
          patientId == other.patientId &&
          doctorId == other.doctorId &&
          existingNote == other.existingNote &&
          initialRawTranscript == other.initialRawTranscript &&
          sessionId == other.sessionId;

  @override
  int get hashCode =>
      patientId.hashCode ^
      doctorId.hashCode ^
      existingNote.hashCode ^
      initialRawTranscript.hashCode ^
      sessionId.hashCode;
}

/// State of the form
class ClinicalHistoryFormState {
  final TextEditingController motivoController;
  final TextEditingController antecedentesHeredofamiliaresController;
  final TextEditingController antecedentesNoPatologicosController;
  final TextEditingController antecedentesPatologicosController;
  final TextEditingController padecimientoActualController;
  final TextEditingController diagnosticoController;
  final TextEditingController planController;
  final TextEditingController prognosisController;

  // ORL Controllers
  final Map<String, TextEditingController> orlControllers;

  // Vitals Controllers
  final TextEditingController weightController;
  final TextEditingController heightController;
  final TextEditingController bpSystolicController;
  final TextEditingController bpDiastolicController;
  final TextEditingController heartRateController;
  final TextEditingController respiratoryRateController;
  final TextEditingController temperatureController;
  final TextEditingController spo2Controller;

  final List<AttachmentEntity> attachments;
  final bool isUploading;
  final bool isSaving;
  final String tempNoteId;
  final DateTime noteDate;

  // To detect changes
  final String? initialSignature;

  // Raw transcript for the note
  final String rawTranscript;

  ClinicalHistoryFormState({
    required this.motivoController,
    required this.antecedentesHeredofamiliaresController,
    required this.antecedentesNoPatologicosController,
    required this.antecedentesPatologicosController,
    required this.padecimientoActualController,
    required this.diagnosticoController,
    required this.planController,
    required this.prognosisController,
    required this.orlControllers,
    required this.weightController,
    required this.heightController,
    required this.bpSystolicController,
    required this.bpDiastolicController,
    required this.heartRateController,
    required this.respiratoryRateController,
    required this.temperatureController,
    required this.spo2Controller,
    this.attachments = const [],
    this.isUploading = false,
    this.isSaving = false,
    required this.tempNoteId,
    required this.noteDate,
    this.initialSignature,
    this.rawTranscript = '',
  });

  ClinicalHistoryFormState copyWith({
    List<AttachmentEntity>? attachments,
    bool? isUploading,
    bool? isSaving,
    String? initialSignature,
    String? rawTranscript,
    DateTime? noteDate,
  }) {
    return ClinicalHistoryFormState(
      motivoController: motivoController,
      antecedentesHeredofamiliaresController:
          antecedentesHeredofamiliaresController,
      antecedentesNoPatologicosController: antecedentesNoPatologicosController,
      antecedentesPatologicosController: antecedentesPatologicosController,
      padecimientoActualController: padecimientoActualController,
      diagnosticoController: diagnosticoController,
      planController: planController,
      prognosisController: prognosisController,
      orlControllers: orlControllers,
      weightController: weightController,
      heightController: heightController,
      bpSystolicController: bpSystolicController,
      bpDiastolicController: bpDiastolicController,
      heartRateController: heartRateController,
      respiratoryRateController: respiratoryRateController,
      temperatureController: temperatureController,
      spo2Controller: spo2Controller,
      attachments: attachments ?? this.attachments,
      isUploading: isUploading ?? this.isUploading,
      isSaving: isSaving ?? this.isSaving,
      tempNoteId: tempNoteId, // Should not change often
      noteDate: noteDate ?? this.noteDate,
      initialSignature: initialSignature ?? this.initialSignature,
      rawTranscript: rawTranscript ?? this.rawTranscript,
    );
  }
}

@riverpod
class ClinicalHistoryForm extends _$ClinicalHistoryForm {
  @override
  ClinicalHistoryFormState build(ClinicalHistoryFormArgs args) {
    // Initialize controllers
    final motivo = TextEditingController();
    final heredo = TextEditingController();
    final noPato = TextEditingController();
    final pato = TextEditingController();
    final padecimiento = TextEditingController();
    final diagnostico = TextEditingController();
    final plan = TextEditingController();
    final prognosis = TextEditingController();

    final orlControllers = {
      'otoscopia': TextEditingController(),
      'otomicroscopia': TextEditingController(),
      'rinoscopia': TextEditingController(),
      'endoscopiaNasal': TextEditingController(),
      'orofaringe': TextEditingController(),
      'cuello': TextEditingController(),
      'laringoscopia': TextEditingController(),
    };

    final weight = TextEditingController();
    final height = TextEditingController();
    final bpSys = TextEditingController();
    final bpDia = TextEditingController();
    final hr = TextEditingController();
    final rr = TextEditingController();
    final temp = TextEditingController();
    final spo2 = TextEditingController();

    // Dispose all controllers when provider is disposed
    ref.onDispose(() {
      motivo.dispose();
      heredo.dispose();
      noPato.dispose();
      pato.dispose();
      padecimiento.dispose();
      diagnostico.dispose();
      plan.dispose();
      prognosis.dispose();
      for (final c in orlControllers.values) c.dispose();
      weight.dispose();
      height.dispose();
      bpSys.dispose();
      bpDia.dispose();
      hr.dispose();
      rr.dispose();
      temp.dispose();
      spo2.dispose();
    });

    final tempNoteId = args.existingNote?.id ?? const Uuid().v4();
    final noteDate = args.existingNote?.createdAt ?? DateTime.now();
    final rawTranscript =
        args.existingNote?.rawTranscript ?? args.initialRawTranscript ?? '';

    // Initial state
    final initialState = ClinicalHistoryFormState(
      motivoController: motivo,
      antecedentesHeredofamiliaresController: heredo,
      antecedentesNoPatologicosController: noPato,
      antecedentesPatologicosController: pato,
      padecimientoActualController: padecimiento,
      diagnosticoController: diagnostico,
      planController: plan,
      prognosisController: prognosis,
      orlControllers: orlControllers,
      weightController: weight,
      heightController: height,
      bpSystolicController: bpSys,
      bpDiastolicController: bpDia,
      heartRateController: hr,
      respiratoryRateController: rr,
      temperatureController: temp,
      spo2Controller: spo2,
      attachments: args.existingNote?.attachments ?? [],
      tempNoteId: tempNoteId,
      noteDate: noteDate,
      rawTranscript: rawTranscript,
    );

    // Prefill if editing
    if (args.existingNote != null) {
      _prefillFromExistingNote(initialState, args.existingNote!);
    } else if (args.initialRawTranscript != null &&
        args.initialRawTranscript!.isNotEmpty) {
      // Parse vitals if new note with transcript
      // Defer to post-frame or just run it synchronously since controllers are just created
      _parseAndApplyVitalSigns(initialState, args.initialRawTranscript!);
    }

    // Compute initial signature after prefill
    return initialState.copyWith(
      initialSignature: _computeSignature(initialState),
    );
  }

  void _prefillFromExistingNote(
    ClinicalHistoryFormState s,
    MedicalNoteEntity note,
  ) {
    s.motivoController.text = note.motivoConsulta;
    s.diagnosticoController.text = note.diagnostico;
    s.planController.text = note.planTratamiento;

    _parseAntecedentes(s, note.antecedentes);
    _parseExploracion(s, note.exploracionFisicaOrl);

    if (note.weightKg != null)
      s.weightController.text = note.weightKg!.toString();
    if (note.heightCm != null)
      s.heightController.text = note.heightCm!.toString();
    if (note.bpSystolic != null)
      s.bpSystolicController.text = note.bpSystolic!.toString();
    if (note.bpDiastolic != null)
      s.bpDiastolicController.text = note.bpDiastolic!.toString();
    if (note.heartRate != null)
      s.heartRateController.text = note.heartRate!.toString();
    if (note.respiratoryRate != null)
      s.respiratoryRateController.text = note.respiratoryRate!.toString();
    if (note.temperatureC != null)
      s.temperatureController.text = note.temperatureC!.toString();
    if (note.spo2 != null) s.spo2Controller.text = note.spo2!.toString();
    if (note.prognosis != null) s.prognosisController.text = note.prognosis!;
  }

  void _parseAntecedentes(ClinicalHistoryFormState s, String antecedentes) {
    if (antecedentes.isEmpty) return;

    final hasStructuredFormat = RegExp(
      r'(HEREDOFAMILIARES?|NO PATOL[OÓ]GICOS?|PATOL[OÓ]GICOS?|PADECIMIENTO ACTUAL):',
      caseSensitive: false,
    ).hasMatch(antecedentes);

    if (!hasStructuredFormat) {
      s.antecedentesHeredofamiliaresController.text = antecedentes;
      return;
    }

    final heredoMatch = RegExp(
      r'HEREDOFAMILIARES?:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
      caseSensitive: false,
    ).firstMatch(antecedentes);
    final noPatoMatch = RegExp(
      r'NO PATOL[OÓ]GICOS?:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
      caseSensitive: false,
    ).firstMatch(antecedentes);
    final patoMatch = RegExp(
      r'(?<!NO )PATOL[OÓ]GICOS?:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
      caseSensitive: false,
    ).firstMatch(antecedentes);
    final padecimientoMatch = RegExp(
      r'PADECIMIENTO ACTUAL:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
      caseSensitive: false,
    ).firstMatch(antecedentes);

    if (heredoMatch != null)
      s.antecedentesHeredofamiliaresController.text =
          heredoMatch.group(1)?.trim() ?? '';
    if (noPatoMatch != null)
      s.antecedentesNoPatologicosController.text =
          noPatoMatch.group(1)?.trim() ?? '';
    if (patoMatch != null)
      s.antecedentesPatologicosController.text =
          patoMatch.group(1)?.trim() ?? '';
    if (padecimientoMatch != null)
      s.padecimientoActualController.text =
          padecimientoMatch.group(1)?.trim() ?? '';
  }

  void _parseExploracion(ClinicalHistoryFormState s, String exploracion) {
    if (exploracion.isEmpty) return;

    final hasStructuredFormat = RegExp(
      r'(OTOSCOPIA|RINOSCOPIA|OROFARINGE|CUELLO|LARINGOSCOPIA):',
      caseSensitive: false,
    ).hasMatch(exploracion);

    if (!hasStructuredFormat) {
      s.orlControllers['otoscopia']?.text = exploracion;
      return;
    }

    // Use hardcoded known keys from OrlSection default (simulated here)
    // OTOMICROSCOPIA/ENDOSCOPIANASAL defined in Page but maybe not in regex?
    // Actually the regex in Page uses explicit set.

    // We'll mimic the exact regex loop from the Page.
    // Assuming OrlSection.defaultSections map.
    // Since we don't have access to OrlSection static easily without importing the widget file (which we did),
    // let's assume we can map them.

    // NOTE: In the original Page code:
    // final regex = RegExp('${section.title.toUpperCase()}:\\s*([\\s\\S]*?)(?=(?:OTOSCOPIA|RINOSCOPIA|OROFARINGE|CUELLO|LARINGOSCOPIA):|\\Z)', caseSensitive: false);

    // I'll assume the same IDs as in initial map.
    final sections = [
      ('otoscopia', 'Otoscopia'),
      ('otomicroscopia', 'Otomicroscopia'),
      ('rinoscopia', 'Rinoscopia'),
      ('endoscopiaNasal', 'Endoscopia nasal'),
      ('orofaringe', 'Orofaringe'),
      ('cuello', 'Cuello'),
      ('laringoscopia', 'Laringoscopia'),
    ];

    for (final section in sections) {
      final regex = RegExp(
        '${section.$2.toUpperCase()}:\\s*([\\s\\S]*?)(?=(?:OTOSCOPIA|RINOSCOPIA|OROFARINGE|CUELLO|LARINGOSCOPIA):|\\Z)',
        caseSensitive: false,
      );
      final match = regex.firstMatch(exploracion);
      if (match != null && match.group(1) != null) {
        s.orlControllers[section.$1]?.text = match.group(1)!.trim();
      }
    }
  }

  void _parseAndApplyVitalSigns(ClinicalHistoryFormState s, String transcript) {
    final parsed = VitalSignsParser.parse(transcript);
    if (!parsed.hasAnyValue) return;

    if (parsed.weightKg != null && s.weightController.text.trim().isEmpty)
      s.weightController.text = parsed.weightKg!.toString();
    if (parsed.heightCm != null && s.heightController.text.trim().isEmpty)
      s.heightController.text = parsed.heightCm!.toString();
    if (parsed.bpSystolic != null && s.bpSystolicController.text.trim().isEmpty)
      s.bpSystolicController.text = parsed.bpSystolic!.toString();
    if (parsed.bpDiastolic != null &&
        s.bpDiastolicController.text.trim().isEmpty)
      s.bpDiastolicController.text = parsed.bpDiastolic!.toString();
    if (parsed.heartRate != null && s.heartRateController.text.trim().isEmpty)
      s.heartRateController.text = parsed.heartRate!.toString();
    if (parsed.respiratoryRate != null &&
        s.respiratoryRateController.text.trim().isEmpty)
      s.respiratoryRateController.text = parsed.respiratoryRate!.toString();
    if (parsed.temperatureC != null &&
        s.temperatureController.text.trim().isEmpty)
      s.temperatureController.text = parsed.temperatureC!.toString();
    if (parsed.spo2 != null && s.spo2Controller.text.trim().isEmpty)
      s.spo2Controller.text = parsed.spo2!.toString();
    if (parsed.prognosis != null && s.prognosisController.text.trim().isEmpty)
      s.prognosisController.text = parsed.prognosis!;
  }

  // Public method to be called from UI when dictation updates
  void parseAndApplyVitalSignsFromTranscript(String transcript) {
    _parseAndApplyVitalSigns(state, transcript);
  }

  String _computeSignature(ClinicalHistoryFormState s) {
    final parts = <String>[
      s.motivoController.text.trim(),
      s.antecedentesHeredofamiliaresController.text.trim(),
      s.antecedentesNoPatologicosController.text.trim(),
      s.antecedentesPatologicosController.text.trim(),
      s.padecimientoActualController.text.trim(),
      s.diagnosticoController.text.trim(),
      s.planController.text.trim(),
      ...s.orlControllers.values.map((c) => c.text.trim()),
      s.weightController.text.trim(),
      s.heightController.text.trim(),
      s.bpSystolicController.text.trim(),
      s.bpDiastolicController.text.trim(),
      s.heartRateController.text.trim(),
      s.respiratoryRateController.text.trim(),
      s.temperatureController.text.trim(),
      s.spo2Controller.text.trim(),
      s.prognosisController.text.trim(),
      s.attachments.length.toString(),
      ...s.attachments.map((a) => a.id),
      // Also include date in signature if relevant, usually just content
    ];
    return parts.join('|');
  }

  String get currentSignature => _computeSignature(state);

  bool get hasUnsavedChanges {
    if (state.initialSignature == null) return false;
    return currentSignature != state.initialSignature;
  }

  void setNoteDate(DateTime date) {
    state = state.copyWith(noteDate: date);
  }

  // --- Helpers for Save ---

  String buildAntecedentes() {
    final s = state;
    final buffer = StringBuffer();
    if (s.antecedentesHeredofamiliaresController.text.trim().isNotEmpty) {
      buffer.writeln('HEREDOFAMILIARES:');
      buffer.writeln(s.antecedentesHeredofamiliaresController.text.trim());
      buffer.writeln();
    }
    if (s.antecedentesNoPatologicosController.text.trim().isNotEmpty) {
      buffer.writeln('NO PATOLOGICOS:');
      buffer.writeln(s.antecedentesNoPatologicosController.text.trim());
      buffer.writeln();
    }
    if (s.antecedentesPatologicosController.text.trim().isNotEmpty) {
      buffer.writeln('PATOLOGICOS:');
      buffer.writeln(s.antecedentesPatologicosController.text.trim());
      buffer.writeln();
    }
    if (s.padecimientoActualController.text.trim().isNotEmpty) {
      buffer.writeln('PADECIMIENTO ACTUAL:');
      buffer.writeln(s.padecimientoActualController.text.trim());
    }
    return buffer.toString().trim();
  }

  String buildExploracionOrl() {
    final s = state;
    final buffer = StringBuffer();
    // Order matters, use same order as in Page or generic iteration
    final sections = [
      ('otoscopia', 'Otoscopia'),
      ('otomicroscopia', 'Otomicroscopia'),
      ('rinoscopia', 'Rinoscopia'),
      ('endoscopiaNasal', 'Endoscopia nasal'),
      ('orofaringe', 'Orofaringe'),
      ('cuello', 'Cuello'),
      ('laringoscopia', 'Laringoscopia'),
    ];

    for (final section in sections) {
      final text = s.orlControllers[section.$1]?.text.trim() ?? '';
      if (text.isNotEmpty) {
        buffer.writeln('${section.$2.toUpperCase()}:');
        buffer.writeln(text);
        buffer.writeln();
      }
    }
    return buffer.toString().trim();
  }

  Future<void> saveNote({bool asDraft = false}) async {
    state = state.copyWith(isSaving: true);

    try {
      final now = DateTime.now();
      final isEditing = args.isEditMode;
      final existingNote = args.existingNote;

      final antecedentes = buildAntecedentes();
      final exploracionOrl = buildExploracionOrl();

      final weightKg = double.tryParse(state.weightController.text);
      final heightCm = double.tryParse(state.heightController.text);
      final bpSystolic = int.tryParse(state.bpSystolicController.text);
      final bpDiastolic = int.tryParse(state.bpDiastolicController.text);
      final heartRate = int.tryParse(state.heartRateController.text);
      final respiratoryRate = int.tryParse(
        state.respiratoryRateController.text,
      );
      final temperatureC = double.tryParse(state.temperatureController.text);
      final spo2 = int.tryParse(state.spo2Controller.text);
      final prognosis = state.prognosisController.text.trim().isEmpty
          ? null
          : state.prognosisController.text.trim();

      final MedicalNoteEntity note;

      if (isEditing && existingNote != null) {
        // Hardening: don't overwrite existing transcript with empty state
        final nextTranscript = state.rawTranscript.trim().isNotEmpty
            ? state.rawTranscript
            : existingNote.rawTranscript;

        note = existingNote.copyWith(
          updatedAt: now,
          type: MedicalNoteType.clinicalHistory,
          motivoConsulta: state.motivoController.text.trim(),
          antecedentes: antecedentes,
          exploracionFisicaOrl: exploracionOrl,
          diagnostico: state.diagnosticoController.text.trim(),
          planTratamiento: state.planController.text.trim(),
          weightKg: weightKg,
          heightCm: heightCm,
          bpSystolic: bpSystolic,
          bpDiastolic: bpDiastolic,
          heartRate: heartRate,
          respiratoryRate: respiratoryRate,
          temperatureC: temperatureC,
          spo2: spo2,
          prognosis: prognosis,
          rawTranscript: nextTranscript,
          status: asDraft ? NoteStatus.draft : existingNote.status,
          attachments: state.attachments,
        );

        await ref
            .read(medicalNotesControllerProvider.notifier)
            .updateMedicalNote(note);
      } else {
        note = MedicalNoteEntity(
          id: '', // Repo generates ID
          patientId: args.patientId,
          doctorId: args.doctorId,
          createdAt: state.noteDate,
          updatedAt: now,
          type: MedicalNoteType.clinicalHistory,
          motivoConsulta: state.motivoController.text.trim(),
          antecedentes: antecedentes,
          exploracionFisicaOrl: exploracionOrl,
          diagnostico: state.diagnosticoController.text.trim(),
          planTratamiento: state.planController.text.trim(),
          weightKg: weightKg,
          heightCm: heightCm,
          bpSystolic: bpSystolic,
          bpDiastolic: bpDiastolic,
          heartRate: heartRate,
          respiratoryRate: respiratoryRate,
          temperatureC: temperatureC,
          spo2: spo2,
          prognosis: prognosis,
          rawTranscript: state.rawTranscript,
          status: asDraft ? NoteStatus.draft : NoteStatus.draft,
          attachments: state.attachments,
        );

        await ref
            .read(medicalNotesControllerProvider.notifier)
            .createMedicalNote(note);
      }
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  // Attachments logic
  void addAttachment(AttachmentEntity attachment) {
    state = state.copyWith(attachments: [...state.attachments, attachment]);
  }

  void removeAttachment(String id) {
    state = state.copyWith(
      attachments: state.attachments.where((a) => a.id != id).toList(),
    );
  }

  void setUploading(bool uploading) {
    state = state.copyWith(isUploading: uploading);
  }

  // Method to update rawTranscript (e.g. if AI generates more)
  void updateRawTranscript(String transcript) {
    state = state.copyWith(rawTranscript: transcript);
  }

  // ---------------------------------------------------------------------------
  // Form Engine API (EPIC 1)
  // ---------------------------------------------------------------------------

  /// Wrapper for saving as draft.
  Future<void> saveDraft() => saveNote(asDraft: true);

  /// Wrapper for saving as final.
  Future<void> saveFinal() => saveNote(asDraft: false);

  /// Validates if there's any content to save as draft.
  ///
  /// Returns true if any field has non-empty text or attachments exist.
  bool canSaveDraft() {
    final s = state;

    // Check main text fields
    if (s.motivoController.text.trim().isNotEmpty) return true;
    if (s.antecedentesHeredofamiliaresController.text.trim().isNotEmpty) {
      return true;
    }
    if (s.antecedentesNoPatologicosController.text.trim().isNotEmpty) {
      return true;
    }
    if (s.antecedentesPatologicosController.text.trim().isNotEmpty) return true;
    if (s.padecimientoActualController.text.trim().isNotEmpty) return true;
    if (s.diagnosticoController.text.trim().isNotEmpty) return true;
    if (s.planController.text.trim().isNotEmpty) return true;
    if (s.prognosisController.text.trim().isNotEmpty) return true;

    // Check ORL fields
    for (final controller in s.orlControllers.values) {
      if (controller.text.trim().isNotEmpty) return true;
    }

    // Check vital signs
    if (s.weightController.text.trim().isNotEmpty) return true;
    if (s.heightController.text.trim().isNotEmpty) return true;
    if (s.bpSystolicController.text.trim().isNotEmpty) return true;
    if (s.bpDiastolicController.text.trim().isNotEmpty) return true;
    if (s.heartRateController.text.trim().isNotEmpty) return true;
    if (s.respiratoryRateController.text.trim().isNotEmpty) return true;
    if (s.temperatureController.text.trim().isNotEmpty) return true;
    if (s.spo2Controller.text.trim().isNotEmpty) return true;

    // Check attachments
    if (s.attachments.isNotEmpty) return true;

    return false;
  }

  /// Validates the form for final save.
  ///
  /// Returns null if valid, otherwise returns a [FinalSaveValidationResult]
  /// with the error message and step index to navigate to.
  FinalSaveValidationResult? validateForFinalSave() {
    final s = state;

    if (s.motivoController.text.trim().isEmpty) {
      return const FinalSaveValidationResult(
        message: 'El motivo de consulta es requerido',
        stepIndex: 0,
      );
    }

    if (s.diagnosticoController.text.trim().isEmpty) {
      return const FinalSaveValidationResult(
        message: 'El diagnostico es requerido',
        stepIndex: 6,
      );
    }

    if (s.planController.text.trim().isEmpty) {
      return const FinalSaveValidationResult(
        message: 'El plan de tratamiento es requerido',
        stepIndex: 6,
      );
    }

    return null;
  }

  /// Returns the current value for a section ID.
  String currentValueForSectionId(String sectionId) {
    final s = state;
    switch (sectionId) {
      case 'motivoConsulta':
        return s.motivoController.text;
      case 'heredofamiliares':
        return s.antecedentesHeredofamiliaresController.text;
      case 'noPatologicos':
        return s.antecedentesNoPatologicosController.text;
      case 'patologicos':
        return s.antecedentesPatologicosController.text;
      case 'padecimientoActual':
        return s.padecimientoActualController.text;
      case 'otoscopia':
        return s.orlControllers['otoscopia']?.text ?? '';
      case 'otomicroscopia':
        return s.orlControllers['otomicroscopia']?.text ?? '';
      case 'rinoscopia':
        return s.orlControllers['rinoscopia']?.text ?? '';
      case 'endoscopiaNasal':
        return s.orlControllers['endoscopiaNasal']?.text ?? '';
      case 'orofaringe':
        return s.orlControllers['orofaringe']?.text ?? '';
      case 'cuello':
        return s.orlControllers['cuello']?.text ?? '';
      case 'laringoscopia':
        return s.orlControllers['laringoscopia']?.text ?? '';
      case 'pronostico':
        return s.prognosisController.text;
      case 'diagnostico':
        return s.diagnosticoController.text;
      case 'planTratamiento':
        return s.planController.text;
      default:
        return '';
    }
  }

  /// Sets the controller value for a section ID.
  void setControllerValue(String sectionId, String value) {
    final s = state;
    switch (sectionId) {
      case 'motivoConsulta':
        s.motivoController.text = value;
        break;
      case 'heredofamiliares':
        s.antecedentesHeredofamiliaresController.text = value;
        break;
      case 'noPatologicos':
        s.antecedentesNoPatologicosController.text = value;
        break;
      case 'patologicos':
        s.antecedentesPatologicosController.text = value;
        break;
      case 'padecimientoActual':
        s.padecimientoActualController.text = value;
        break;
      case 'otoscopia':
        s.orlControllers['otoscopia']?.text = value;
        break;
      case 'otomicroscopia':
        s.orlControllers['otomicroscopia']?.text = value;
        break;
      case 'rinoscopia':
        s.orlControllers['rinoscopia']?.text = value;
        break;
      case 'endoscopiaNasal':
        s.orlControllers['endoscopiaNasal']?.text = value;
        break;
      case 'orofaringe':
        s.orlControllers['orofaringe']?.text = value;
        break;
      case 'cuello':
        s.orlControllers['cuello']?.text = value;
        break;
      case 'laringoscopia':
        s.orlControllers['laringoscopia']?.text = value;
        break;
      case 'pronostico':
        s.prognosisController.text = value;
        break;
      case 'diagnostico':
        s.diagnosticoController.text = value;
        break;
      case 'planTratamiento':
        s.planController.text = value;
        break;
      default:
        assert(() {
          debugPrint('Unknown sectionId: $sectionId');
          return true;
        }());
    }
  }

  /// Checks if a section is effectively empty for AI suggestion purposes.
  ///
  /// A field is effectively empty if:
  /// 1. It's literally empty, OR
  /// 2. It contains only a short placeholder/negation pattern (max 25 chars)
  bool isEffectivelyEmpty(String sectionId) {
    final txt = currentValueForSectionId(sectionId).trim();
    if (txt.isEmpty) return true;
    if (txt.length > 25) return false;
    return AISuggestionSection.isPlaceholderContent(txt.toLowerCase());
  }

  /// Applies AI suggestions to the form fields.
  ///
  /// [sections] - List of AI suggestion sections to apply.
  /// [mode] - Apply mode: onlyEmpty (only apply to empty/placeholder fields)
  ///          or replace (apply to all fields).
  ///
  /// Returns the number of suggestions that were applied.
  int applySuggestions(List<AISuggestionSection> sections, ApplyMode mode) {
    int appliedCount = 0;

    for (final section in sections) {
      if (!section.hasContent) continue;

      final shouldApply = mode == ApplyMode.replace ||
          (mode == ApplyMode.onlyEmpty && isEffectivelyEmpty(section.id));

      if (shouldApply) {
        setControllerValue(section.id, section.suggestion);
        appliedCount++;
      }
    }

    return appliedCount;
  }
}
