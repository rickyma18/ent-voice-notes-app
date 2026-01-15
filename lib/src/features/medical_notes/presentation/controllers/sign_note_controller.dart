// lib/src/features/medical_notes/presentation/controllers/sign_note_controller.dart

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../../doctors/domain/entities/doctor_entity.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/quality_gate_result.dart';
import '../../domain/usecases/sign_medical_note_use_case.dart';
import '../../medical_notes_providers.dart';

part 'sign_note_controller.g.dart';

/// Steps in the signing process for UI feedback
enum SigningStep {
  idle(''),
  validatingQuality('Validando campos requeridos...'),
  savingSignature('Guardando firma...'),
  generatingPdf('Generando PDF...'),
  uploadingDocuments('Subiendo documentos...'),
  finalizing('Finalizando...'),
  success('¡Nota firmada!'),
  error('Error al firmar');

  const SigningStep(this.message);
  final String message;
}

/// State for the sign note process
class SignNoteState {
  const SignNoteState({
    this.step = SigningStep.idle,
    this.signedNote,
    this.signedPdfUrl,
    this.failure,
    this.qualityGateResult,
  });

  final SigningStep step;
  final MedicalNoteEntity? signedNote;
  final String? signedPdfUrl;
  final Failure? failure;

  /// Quality gate result when validation fails.
  /// Contains details about missing required fields.
  final QualityGateResult? qualityGateResult;

  bool get isIdle => step == SigningStep.idle;
  bool get isSigning =>
      step != SigningStep.idle &&
      step != SigningStep.success &&
      step != SigningStep.error;
  bool get isSuccess => step == SigningStep.success;
  bool get isError => step == SigningStep.error;

  /// Whether the error was due to quality gate failure.
  bool get isQualityGateError =>
      isError && qualityGateResult != null && !qualityGateResult!.pass;

  SignNoteState copyWith({
    SigningStep? step,
    MedicalNoteEntity? signedNote,
    String? signedPdfUrl,
    Failure? failure,
    QualityGateResult? qualityGateResult,
  }) {
    return SignNoteState(
      step: step ?? this.step,
      signedNote: signedNote ?? this.signedNote,
      signedPdfUrl: signedPdfUrl ?? this.signedPdfUrl,
      failure: failure ?? this.failure,
      qualityGateResult: qualityGateResult ?? this.qualityGateResult,
    );
  }
}

/// Controller for signing a medical note.
///
/// Manages the state of the signing process with visual feedback
/// for each step.
@riverpod
class SignNoteController extends _$SignNoteController {
  @override
  SignNoteState build() => const SignNoteState();

  /// Resets the controller to idle state
  void reset() {
    state = const SignNoteState();
  }

  /// Signs a medical note with the provided signature.
  ///
  /// [note] - The note to sign
  /// [doctor] - The doctor signing the note
  /// [patientName] - Patient name for PDF generation
  /// [signatureBytes] - PNG bytes of the signature (required if not using default)
  /// [useDefaultSignature] - Whether to use doctor's saved default signature
  /// [saveAsDefault] - Whether to save new signature as doctor's default
  ///
  /// Returns false if quality gate validation fails. Check [state.qualityGateResult]
  /// for details about missing required fields.
  Future<bool> signNote({
    required MedicalNoteEntity note,
    required DoctorEntity doctor,
    required String patientName,
    Uint8List? signatureBytes,
    bool useDefaultSignature = false,
    bool saveAsDefault = false,
  }) async {
    // Step 0: Quality Gate validation (MANDATORY before signing)
    state = state.copyWith(step: SigningStep.validatingQuality);

    final qualityGate = ref.read(noteQualityGateServiceProvider);
    final gateResult = qualityGate.validateForSigning(note);

    if (!gateResult.pass) {
      // Quality gate failed - block signing
      state = SignNoteState(
        step: SigningStep.error,
        qualityGateResult: gateResult,
        failure: Failure(
          type: FailureType.validation,
          message: gateResult.errorMessage,
        ),
      );
      return false;
    }

    // Small delay for UX (let user see validation passed)
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 1: Saving signature
    state = state.copyWith(step: SigningStep.savingSignature);

    // Small delay for UX (let user see the step)
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 2: Generating PDF
    state = state.copyWith(step: SigningStep.generatingPdf);
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 3: Uploading documents
    state = state.copyWith(step: SigningStep.uploadingDocuments);

    try {
      final useCase = ref.read(signMedicalNoteUseCaseProvider);

      final params = SignMedicalNoteParams(
        note: note,
        doctor: doctor,
        patientName: patientName,
        signatureBytes: signatureBytes,
        useDefaultSignature: useDefaultSignature,
        saveAsDefault: saveAsDefault,
      );

      final result = await useCase.call(params);

      // Step 4: Finalizing
      state = state.copyWith(step: SigningStep.finalizing);
      await Future.delayed(const Duration(milliseconds: 200));

      return result.when(
        success: (data) {
          state = SignNoteState(
            step: SigningStep.success,
            signedNote: data.signedNote,
            signedPdfUrl: data.signedPdfUrl,
          );
          return true;
        },
        error: (failure) {
          state = SignNoteState(step: SigningStep.error, failure: failure);
          return false;
        },
      );
    } catch (e) {
      state = SignNoteState(
        step: SigningStep.error,
        failure: Failure(
          type: FailureType.unknown,
          message: 'Error inesperado: $e',
        ),
      );
      return false;
    }
  }
}
