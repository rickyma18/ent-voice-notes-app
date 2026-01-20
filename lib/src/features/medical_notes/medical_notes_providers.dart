// lib/src/features/medical_notes/medical_notes_providers.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/base/result.dart';
import 'application/note_ai_service.dart';
import 'application/note_ai_service_impl.dart';
import 'application/audio_recording_service.dart';
import 'application/audio_recording_service_impl.dart';
import 'application/speech_to_text_service.dart';
import 'application/speech_to_text_service_impl.dart';
import 'application/note_quality_gate_service_impl.dart';
import 'domain/services/note_quality_gate_service.dart';

import 'application/usecases/upload_image_attachment_usecase.dart';
import 'application/usecases/upload_pdf_attachment_usecase.dart';
import 'data/datasources/attachments_storage_datasource.dart';
import 'data/datasources/medical_notes_local_datasource.dart';
import 'data/datasources/medical_notes_remote_datasource.dart';
import 'data/datasources/signature_storage_datasource.dart';
// import 'data/datasources/medical_notes_fake_datasource.dart'; // Fake kept for testing
import 'data/repositories/attachments_repository_impl.dart';
import 'data/repositories/medical_notes_repository_impl.dart';
import 'domain/repositories/attachments_repository.dart';
import 'domain/repositories/medical_notes_repository.dart';
import 'domain/usecases/get_medical_notes_by_doctor_use_case.dart';
import 'domain/usecases/create_medical_note_use_case.dart';
import 'domain/usecases/delete_medical_note_use_case.dart';
import 'domain/usecases/get_medical_notes_use_case.dart';
import 'domain/usecases/update_medical_note_use_case.dart';
import 'domain/usecases/get_medical_note_by_id_use_case.dart';
import 'domain/usecases/add_attachment_to_medical_note_use_case.dart';
import 'domain/usecases/sign_medical_note_use_case.dart';
import 'domain/entities/medical_note_entity.dart';
import '../../presentation/core/application_state/current_doctor_provider/current_doctor_provider.dart';
import '../doctors/doctors_providers.dart';
import '../doctors/domain/entities/doctor_signature_info.dart';

// Scribe (Pipeline) Imports
import 'data/scribe/scribe.dart'; // Impls & DTOs
import 'application/scribe/scribe.dart'; // UseCases & Prompts
import 'domain/scribe/repositories/transcription_repository.dart';
import 'domain/scribe/repositories/encounter_extractor_repository.dart';
import 'domain/scribe/repositories/note_composer_repository.dart';

// Medicalization Service Import
import 'application/medicalization/medicalization_service.dart';

// Audio Preprocessing (VAD/Chunking) Imports
import 'data/repositories/audio_preprocessor_repository_impl.dart';
import 'domain/repositories/audio_preprocessor_repository.dart';

// Diarization (Speaker Identification) Imports
import 'data/scribe/services_impl/diarization_service_stub.dart';
import 'data/scribe/services_impl/diarization_service_impl.dart';
import 'domain/scribe/services/diarization_service.dart';

// Google Cloud STT V2 (Chirp-3) Imports
import 'data/stt/google_chirp_stt_client.dart';
import 'data/stt/google_chirp_stt_service_impl.dart';

// Scribe V2 Storage Imports
import 'data/datasources/scribe_v2_storage_datasource.dart';

// ÉPICA 10 - MedGemma Advanced Extractor Imports
import 'package:docsoft_scribe_runtime/docsoft_scribe_runtime.dart' as runtime;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'data/medgemma/providers/medgemma_providers.dart';
import 'data/medgemma/repositories/medgemma_extractor_adapter.dart';

part 'medical_notes_providers.g.dart';

/// Family provider for loading medical notes for a specific patient.
/// Returns AsyncValue<List<MedicalNoteEntity>> scoped to one patient.
///
/// This provider is isolated from the global [medicalNotesControllerProvider]
/// to prevent state pollution when navigating between patient detail and notes list.
///
/// Usage (in patient detail):
/// ```dart
/// final notesAsync = ref.watch(medicalNotesByPatientProvider(patient.id));
/// ```
@riverpod
Future<List<MedicalNoteEntity>> medicalNotesByPatient(
  Ref ref,
  String patientId,
) async {
  final doctorId = ref.read(currentDoctorIdProvider);
  if (doctorId == null) {
    throw Exception('Doctor not authenticated');
  }

  final result = await ref
      .read(getMedicalNotesUseCaseProvider)
      .call(patientId: patientId, doctorId: doctorId);

  final notes = switch (result) {
    Success(:final data) => data,
    Error(:final error) => throw error,
    _ => throw Exception('Unexpected result type'),
  };

  // DEBUG ASSERTION: Verify all returned notes belong to the requested patient.
  // If this assertion fails, the data layer is not filtering correctly.
  assert(() {
    final wrongPatientNotes = notes.where((n) => n.patientId != patientId);
    if (wrongPatientNotes.isNotEmpty) {
      throw StateError(
        'medicalNotesByPatientProvider: Data layer returned notes for wrong patient!\n'
        'Requested patientId: $patientId\n'
        'Wrong notes: ${wrongPatientNotes.map((n) => '${n.id} (patientId: ${n.patientId})').join(', ')}',
      );
    }
    return true;
  }());

  return notes;
}

/// Remote datasource provider
///
/// PRODUCTION MODE: Uses Firestore for medical notes storage.
///
/// To switch to fake datasource (development/testing):
/// - Uncomment: return FakeMedicalNotesRemoteDatasource();
/// - Comment out: return MedicalNotesRemoteDatasourceImpl();
@riverpod
MedicalNotesRemoteDatasource medicalNotesRemoteDatasource(
  MedicalNotesRemoteDatasourceRef ref,
) {
  // Production: Use Firestore implementation
  return MedicalNotesRemoteDatasourceImpl();

  // Development: Use fake in-memory datasource (for testing)
  // return FakeMedicalNotesRemoteDatasource();
}

/// Local datasource provider
@riverpod
MedicalNotesLocalDatasource medicalNotesLocalDatasource(
  MedicalNotesLocalDatasourceRef ref,
) {
  return MedicalNotesLocalDatasourceImpl();
}

/// OpenAI API Key provider.
///
/// MUST be overridden in main() with the actual API key.
/// The API key should come from:
/// - Environment variables (recommended for production)
/// - Secure storage
/// - Configuration file (excluded from version control)
///
/// Example override in main():
/// ```dart
/// container.overrideWith((ref) => 'sk-...');
/// ```
@Riverpod(keepAlive: true)
String openAIApiKey(Ref ref) {
  throw UnimplementedError(
    'openAIApiKeyProvider must be overridden in main() with your OpenAI API key.\n'
    'Never commit API keys to version control.\n'
    'Use environment variables: const String.fromEnvironment("OPENAI_API_KEY")',
  );
}

/// OpenAI Client provider.
///
/// Creates a configured OpenAI client with the API key.
@riverpod
OpenAIClient openAIClient(Ref ref) {
  final apiKey = ref.watch(openAIApiKeyProvider);
  return OpenAIClient(
    apiKey: apiKey,
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ),
    ),
  );
}

/// NoteAI Service provider.
///
/// PRODUCTION MODE: Uses real OpenAI APIs (Whisper + GPT-4).
/// TEST MODE: Uncomment the stub below for UI testing without API calls.
@riverpod
NoteAIService noteAIService(NoteAIServiceRef ref) {
  // CRITICAL: Keep alive during long LLM operations
  ref.keepAlive();

  return NoteAIServiceImpl(
    openAIClient: ref.watch(openAIClientProvider),
    enablePhoneticMedicationMatching: true,
  );
}

@riverpod
AudioRecordingService audioRecordingService(AudioRecordingServiceRef ref) {
  // CRITICAL: Keep provider alive to prevent disposal during recording
  // Without this, the provider can be disposed between startRecording() and stopRecording(),
  // causing "not recording" errors when stop is called on a new instance.
  ref.keepAlive();

  // PRODUCTION MODE: Real audio recording implementation
  return AudioRecordingServiceImpl();

  // For testing purposes, you can uncomment the stub below:
  // return AudioRecordingServiceStub();
}

/// Feature flag for audio preprocessing (VAD/chunking).
///
/// When true, audio is preprocessed to detect silences and split into
/// multiple chunks before transcription. This can reduce latency and
/// improve transcription quality for long recordings with pauses.
///
/// Default: false (disabled for backward compatibility).
/// Override in main() or via environment variable to enable.
@Riverpod(keepAlive: true)
bool enableAudioPreprocessing(Ref ref) {
  // Default: disabled for backward compatibility
  // Can be overridden in main() for testing or gradual rollout:
  // container.updateOverrides([enableAudioPreprocessingProvider.overrideWithValue(true)]);
  return false;
}

/// Feature flag for using Scribe V2 pipeline in note creation flows.
///
/// When true:
/// - CreateMedicalNotePage and ClinicalHistoryWizardPage use Scribe V2
///   via MedicalNotesController.generateNoteFromAudio/Transcript
/// - Results are mapped to legacy format via _mapScribeResultToLegacyFormat
/// - If Scribe V2 fails (JSON invalid, rate limit, etc.), auto-fallback to legacy
///
/// When false:
/// - Legacy NoteAIService is used directly (current behavior)
///
/// Default: false (disabled for backward compatibility, enable for gradual rollout).
@Riverpod(keepAlive: true)
bool useScribeV2ForNoteCreation(Ref ref) {
  // Default: disabled for backward compatibility
  // Can be overridden in main() for testing or gradual rollout:
  // container.updateOverrides([useScribeV2ForNoteCreationProvider.overrideWithValue(true)]);
  return false;
}

/// Note Quality Gate Service provider.
///
/// Validates that medical notes have minimum required clinical fields:
/// - Motivo de consulta (Chief complaint / HPI)
/// - Diagnóstico (Assessment / Diagnosis)
/// - Plan de tratamiento (Treatment plan)
///
/// Used to block:
/// - Saving incomplete notes (warning only, doesn't block draft saves)
/// - Signing notes that don't meet quality standards (blocks signing)
@riverpod
NoteQualityGateService noteQualityGateService(Ref ref) {
  return const NoteQualityGateServiceImpl();
}

/// Audio Preprocessor Repository provider.
///
/// Provides VAD/chunking preprocessing for audio before STT.
/// Uses FFmpeg if available, falls back to passthrough (single chunk).
@riverpod
AudioPreprocessorRepository audioPreprocessorRepository(Ref ref) {
  return AudioPreprocessorRepositoryImpl();
}

/// SpeechToText Service provider.
///
/// PRODUCTION MODE: Uses real OpenAI Whisper API for transcription.
/// Phase 1.5: Now applies medical transcript post-processing for consistency
/// with NoteAIService pipeline.
/// Phase 2.0: Optional audio preprocessing (VAD/chunking) when enabled.
/// Phase 2.5: Optional Google Chirp-3 STT backend via useChirp3SttProvider.
/// TEST MODE: Uncomment the stub below for UI testing without API calls.
@riverpod
SpeechToTextService speechToTextService(Ref ref) {
  ref.keepAlive(); // Prevent disposal during long operations
  final enablePreprocessing = ref.watch(enableAudioPreprocessingProvider);
  final useChirp3 = ref.watch(useChirp3SttProvider);
  final allowFallback = ref.watch(allowSttFallbackProvider);

  // Get audio preprocessor if enabled
  final audioPreprocessor = enablePreprocessing
      ? ref.watch(audioPreprocessorRepositoryProvider)
      : null;

  // Phase 2.5: Use Google Chirp-3 if enabled
  if (useChirp3) {
    final chirpConfig = ref.watch(googleChirpSttConfigProvider);
    if (chirpConfig != null) {
      final chirpClient = GoogleChirpSttClient(config: chirpConfig);

      // Build fallback service (Whisper) if allowed
      SpeechToTextService? fallback;
      if (allowFallback) {
        fallback = SpeechToTextServiceImpl(
          openAIClient: ref.watch(openAIClientProvider),
          enablePhoneticMedicationMatching: true,
          audioPreprocessor: audioPreprocessor,
          enableAudioPreprocessing: enablePreprocessing,
        );
      }

      return GoogleChirpSttServiceImpl(
        client: chirpClient,
        fallbackService: fallback,
        allowFallback: allowFallback,
        audioPreprocessor: audioPreprocessor,
        enableAudioPreprocessing: enablePreprocessing,
      );
    }
  }

  // Default: OpenAI Whisper transcription with Phase 1.5 post-processing
  return SpeechToTextServiceImpl(
    openAIClient: ref.watch(openAIClientProvider),
    enablePhoneticMedicationMatching: true, // Phase 1.5 enabled
    audioPreprocessor: audioPreprocessor,
    enableAudioPreprocessing: enablePreprocessing,
  );

  // TEST MODE: Stub for UI testing (no real API calls)
  // return SpeechToTextServiceStub();
}

// =============================================================================
// Google Cloud STT V2 (Chirp-3) Providers
// =============================================================================

/// Feature flag for using Google Cloud STT V2 with Chirp-3 model.
///
/// When true, uses Google Chirp-3 for transcription instead of OpenAI Whisper.
/// Provides word-level timestamps and potentially better multilingual support.
///
/// Default: false (uses Whisper).
/// Requires googleChirpSttConfigProvider to be configured.
@Riverpod(keepAlive: true)
bool useChirp3Stt(Ref ref) {
  // Default: disabled, use Whisper
  // Can be overridden: container.updateOverrides([useChirp3SttProvider.overrideWithValue(true)])
  return false;
}

/// Feature flag for allowing STT fallback.
///
/// When true and Chirp-3 fails, automatically falls back to Whisper.
/// Default: true (always try fallback).
@Riverpod(keepAlive: true)
bool allowSttFallback(Ref ref) {
  return true;
}

/// Configuration provider for Google Cloud STT V2.
///
/// Returns null if not configured (Chirp-3 won't be used).
/// Override this provider with actual credentials in main().
///
/// Example:
/// ```dart
/// ProviderScope(
///   overrides: [
///     googleChirpSttConfigProvider.overrideWithValue(
///       GoogleChirpSttConfig(
///         projectId: 'my-project',
///         location: 'us-central1',
///         accessToken: 'ya29...',
///       ),
///     ),
///   ],
/// )
/// ```
@Riverpod(keepAlive: true)
GoogleChirpSttConfig? googleChirpSttConfig(Ref ref) {
  // Default: not configured
  // Must be overridden with actual credentials to use Chirp-3
  return null;
}

// =============================================================================
// Diarization (Speaker Identification) Providers
// =============================================================================

/// Feature flag for speaker diarization.
///
/// When true, diarization service will attempt to assign speaker labels
/// (Doctor, Paciente) to transcript segments based on audio analysis.
///
/// Default: false (disabled - all segments assigned 'unknown').
/// Override in main() or via environment variable to enable.
///
/// TODO: Enable when pyannote FastAPI integration is complete.
@Riverpod(keepAlive: true)
bool enableDiarization(Ref ref) {
  // Default: disabled until real implementation is ready
  // Can be overridden in main() for testing:
  // container.updateOverrides([enableDiarizationProvider.overrideWithValue(true)]);
  return false;
}

/// Diarization backend configuration provider.
///
/// Configure the pyannote diarization backend URL.
/// Default: http://localhost:8000 (local Docker)
@Riverpod(keepAlive: true)
DiarizationBackendConfig diarizationBackendConfig(Ref ref) {
  return const DiarizationBackendConfig();
}

@riverpod
DiarizationService diarizationService(Ref ref) {
  final enabled = ref.watch(enableDiarizationProvider);

  if (enabled) {
    // Use real pyannote backend implementation
    final config = ref.watch(diarizationBackendConfigProvider);
    return DiarizationServiceImpl(
      config: config,
      fallbackService:
          const DiarizationServiceStub(), // Fallback if backend fails
    );
  }

  // Default: stub implementation
  return const DiarizationServiceStub();
}

/// Repository provider
@riverpod
MedicalNotesRepository medicalNotesRepository(MedicalNotesRepositoryRef ref) {
  return MedicalNotesRepositoryImpl(
    remoteDatasource: ref.watch(medicalNotesRemoteDatasourceProvider),
    localDatasource: ref.watch(medicalNotesLocalDatasourceProvider),
  );
}

/// Use cases providers

@riverpod
GetMedicalNotesUseCase getMedicalNotesUseCase(GetMedicalNotesUseCaseRef ref) {
  return GetMedicalNotesUseCase(ref.watch(medicalNotesRepositoryProvider));
}

@riverpod
GetMedicalNotesByDoctorUseCase getMedicalNotesByDoctorUseCase(
  GetMedicalNotesByDoctorUseCaseRef ref,
) {
  return GetMedicalNotesByDoctorUseCase(
    repository: ref.watch(medicalNotesRepositoryProvider),
  );
}

@riverpod
GetMedicalNoteByIdUseCase getMedicalNoteByIdUseCase(
  GetMedicalNoteByIdUseCaseRef ref,
) {
  return GetMedicalNoteByIdUseCase(ref.watch(medicalNotesRepositoryProvider));
}

@riverpod
CreateMedicalNoteUseCase createMedicalNoteUseCase(
  CreateMedicalNoteUseCaseRef ref,
) {
  return CreateMedicalNoteUseCase(ref.watch(medicalNotesRepositoryProvider));
}

@riverpod
UpdateMedicalNoteUseCase updateMedicalNoteUseCase(
  UpdateMedicalNoteUseCaseRef ref,
) {
  return UpdateMedicalNoteUseCase(ref.watch(medicalNotesRepositoryProvider));
}

@riverpod
DeleteMedicalNoteUseCase deleteMedicalNoteUseCase(
  DeleteMedicalNoteUseCaseRef ref,
) {
  return DeleteMedicalNoteUseCase(ref.watch(medicalNotesRepositoryProvider));
}

// =============================================================================
// Attachments providers (Firebase Storage)
// =============================================================================

/// Attachments storage datasource provider.
@riverpod
AttachmentsStorageDatasource attachmentsStorageDatasource(
  AttachmentsStorageDatasourceRef ref,
) {
  return AttachmentsStorageDatasource();
}

/// Attachments repository provider.
@riverpod
AttachmentsRepository attachmentsRepository(AttachmentsRepositoryRef ref) {
  return AttachmentsRepositoryImpl(
    datasource: ref.watch(attachmentsStorageDatasourceProvider),
  );
}

/// Upload image attachment use case provider.
@riverpod
UploadImageAttachmentUseCase uploadImageAttachmentUseCase(
  UploadImageAttachmentUseCaseRef ref,
) {
  return UploadImageAttachmentUseCase(
    repository: ref.watch(attachmentsRepositoryProvider),
  );
}

/// Upload PDF attachment use case provider.
@riverpod
UploadPdfAttachmentUseCase uploadPdfAttachmentUseCase(
  UploadPdfAttachmentUseCaseRef ref,
) {
  return UploadPdfAttachmentUseCase(
    repository: ref.watch(attachmentsRepositoryProvider),
  );
}

/// Add attachment to medical note use case provider.
@riverpod
AddAttachmentToMedicalNoteUseCase addAttachmentToMedicalNoteUseCase(
  AddAttachmentToMedicalNoteUseCaseRef ref,
) {
  return AddAttachmentToMedicalNoteUseCase(
    ref.watch(medicalNotesRepositoryProvider),
    ref.watch(attachmentsRepositoryProvider),
  );
}

// =============================================================================
// Scribe Pipeline Providers (Stage 1, 2 & 3)
// =============================================================================

/// MedicalizationService Provider.
///
/// Transforms colloquial patient language into formal clinical terminology
/// BEFORE sending to LLM. Uses a deterministic local dictionary approach.
///
/// keepAlive: true to preserve the glossary cache across the session.
@Riverpod(keepAlive: true)
MedicalizationService medicalizationService(Ref ref) {
  return MedicalizationServiceFactory.create();
}

/// OpenAI Extractor Client Provider (Stage 2).
///
/// keepAlive: true to prevent disposal during long-running pipeline.
@Riverpod(keepAlive: true)
OpenAIExtractorClient openAIExtractorClient(Ref ref) {
  return OpenAIExtractorClient(openAIClient: ref.watch(openAIClientProvider));
}

@riverpod
EncounterExtractorRepository encounterExtractorRepository(
  EncounterExtractorRepositoryRef ref,
) {
  return EncounterExtractorRepositoryImpl(
    client: ref.watch(openAIExtractorClientProvider),
  );
}

/// OpenAI Composer Client Provider (Stage 3).
///
/// keepAlive: true to prevent disposal during long-running pipeline.
@Riverpod(keepAlive: true)
OpenAIComposerClient openAIComposerClient(Ref ref) {
  return OpenAIComposerClient(openAIClient: ref.watch(openAIClientProvider));
}

@riverpod
NoteComposerRepository noteComposerRepository(NoteComposerRepositoryRef ref) {
  return NoteComposerRepositoryImpl(
    client: ref.watch(openAIComposerClientProvider),
  );
}

/// Transcription Repository Provider (Stage 1).
///
/// Phase 2.2: Now supports optional speaker diarization when enableDiarization is true.
@riverpod
TranscriptionRepository transcriptionRepository(
  TranscriptionRepositoryRef ref,
) {
  final enableDiarization = ref.watch(enableDiarizationProvider);

  // Stage 1: Transcription with Phase 1.5 SpeechToTextService (Whisper)
  // Phase 2.2: Optional speaker diarization
  return TranscriptionRepositoryImpl(
    service: ref.watch(speechToTextServiceProvider),
    diarizationService: enableDiarization
        ? ref.watch(diarizationServiceProvider)
        : null,
    enableDiarization: enableDiarization,
  );
}

// =============================================================================
// ÉPICA 10 – MedGemma Advanced Extractor Providers (Feature Flags + Wiring)
// =============================================================================
//
// FAIL-CLOSED DESIGN:
// - MedGemma is DISABLED by default
// - Requires: (1) baseUrl configured, (2) isPro == true, (3) useMedGemmaExtractor flag ON
// - If any condition fails → baseline extractor used
// - ExtractorPipelineSelector handles SLA timeouts and automatic fallback
//
// PHI-SAFE: No transcripts, prompts, or clinical outputs logged.
// =============================================================================

/// Feature flags for Scribe pipeline.
///
/// Detects environment and returns appropriate flags:
/// - kDebugMode (dev/staging): shadowMode enabled, useMedGemmaExtractor = false by default
/// - Production: all flags at safest defaults
///
/// To enable MedGemma extraction in dev, override this provider:
/// ```dart
/// scribeFeatureFlagsProvider.overrideWithValue(
///   FeatureFlags.dev.copyWith(useMedGemmaExtractor: true),
/// )
/// ```
final scribeFeatureFlagsProvider = Provider<runtime.FeatureFlags>((ref) {
  // Environment detection: kDebugMode = dev/staging, else prod
  if (kDebugMode) {
    return runtime.FeatureFlags.staging;
  }
  return runtime.FeatureFlags.prod;
});

/// Shadow Metrics Collector for staging/dev.
///
/// **FAIL-CLOSED**: Returns null if enableShadowMode is false.
/// Only instantiated in staging/dev when shadow mode is enabled.
final shadowMetricsCollectorProvider =
    Provider<runtime.ShadowMetricsCollector?>((ref) {
      final flags = ref.watch(scribeFeatureFlagsProvider);

      // Fail-closed: shadow mode must be explicitly enabled
      if (!flags.enableShadowMode) {
        return null;
      }

      // Only enable logging in debug mode
      return runtime.ShadowMetricsCollector(
        config: runtime.ShadowMetricsConfig(
          enableLogging: kDebugMode,
          maxSamples: 100,
        ),
      );
    });

/// SLA Evaluator for MedGemma pipeline monitoring.
///
/// **PRODUCTION SILENT**: enableDebugLogging is false in prod.
/// Only logs in debug/staging mode (kDebugMode).
final slaEvaluatorProvider = Provider<runtime.SlaEvaluator>((ref) {
  return runtime.SlaEvaluator(
    thresholds: runtime.SlaThresholds.defaults,
    // CRITICAL: Only log in debug mode, production is silent
    enableDebugLogging: kDebugMode,
  );
});

/// Whether current user is a Pro subscriber.
///
/// **FAIL-CLOSED**: Returns false by default.
/// TODO: Connect to actual subscription plan when implemented.
///
/// This provider will be updated when DoctorEntity gets subscriptionPlan field.
final isProUserProvider = Provider<bool>((ref) {
  // FAIL-CLOSED: Default to false until subscription system is implemented
  // When DoctorEntity has subscriptionPlan:
  // final doctor = ref.watch(currentDoctorProfileProvider).valueOrNull;
  // return doctor?.subscriptionPlan.isPro ?? false;
  return false;
});

/// Advanced Encounter Extractor Repository (MedGemma).
///
/// **FAIL-CLOSED DESIGN:**
/// - Returns null if MedGemma is not fully configured (baseUrl, auth)
/// - Returns null if user is not Pro
/// - When null, ProcessEncounterUseCase uses baseline extractor only
///
/// The ExtractorPipelineSelector (inside ProcessEncounterUseCase) handles:
/// - SLA timeout enforcement (5s advanced, 8s baseline)
/// - Automatic fallback on timeout/error
/// - Metrics and logging
final advancedEncounterExtractorRepositoryProvider =
    Provider<EncounterExtractorRepository?>((ref) {
      // Gate 1: Pro user check
      final isPro = ref.watch(isProUserProvider);
      if (!isPro) {
        // Free user → no advanced extractor
        return null;
      }

      // Gate 2: MedGemma configuration check
      final medGemmaRepo = ref.watch(medGemmaExtractorRepositoryProvider);
      if (medGemmaRepo == null) {
        // MedGemma not configured → no advanced extractor
        return null;
      }

      // Gate 3: Feature flag check
      final flags = ref.watch(scribeFeatureFlagsProvider);
      if (!flags.useMedGemmaExtractor) {
        // Feature flag OFF → no advanced extractor
        return null;
      }

      // All gates passed → return adapter that wraps MedGemma repo
      return MedGemmaExtractorAdapter(coreRepository: medGemmaRepo);
    });

/// ProcessEncounterUseCase Provider.
///
/// Orchestrates the full Scribe V2 pipeline:
/// Stage 1: Transcription → Stage 1.5: Medicalization → Stage 2: Extraction → Stage 3: Composition
///
/// ÉPICA 10 - MedGemma Integration:
/// - Injects advancedExtractorRepository when available (Pro + configured + flag ON)
/// - Injects featureFlags for pipeline behavior control
/// - ExtractorPipelineSelector handles automatic fallback on timeout/error
///
/// IMPORTANT: advancedExtractorRepository is NOT read for free users (fail-closed).
/// The conditional in advancedEncounterExtractorRepositoryProvider ensures this.
///
/// keepAlive: true to prevent disposal during long-running pipeline execution.
@Riverpod(keepAlive: true)
ProcessEncounterUseCase processEncounterUseCase(Ref ref) {
  // Get advanced extractor (null for free users or if not configured)
  // IMPORTANT: This is the ONLY place that reads advancedEncounterExtractorRepositoryProvider
  final advancedExtractor = ref.watch(
    advancedEncounterExtractorRepositoryProvider,
  );

  // Get feature flags for pipeline behavior
  final featureFlags = ref.watch(scribeFeatureFlagsProvider);

  return ProcessEncounterUseCase(
    transcriptionRepository: ref.watch(transcriptionRepositoryProvider),
    extractorRepository: ref.watch(encounterExtractorRepositoryProvider),
    composerRepository: ref.watch(noteComposerRepositoryProvider),
    medicalizationService: ref.watch(medicalizationServiceProvider),
    advancedExtractorRepository: advancedExtractor,
    featureFlags: featureFlags,
  );
}

// =============================================================================
// Signature & Digital Signing Providers
// =============================================================================

/// Signature storage datasource provider.
///
/// Handles Firebase Storage operations for:
/// - Doctor default signatures: doctors/{doctorId}/signature/default.png
/// - Note signature snapshots: medical_notes/{noteId}/signature.png
/// - Signed PDFs: medical_notes/{noteId}/final.pdf
@riverpod
SignatureStorageDatasource signatureStorageDatasource(
  SignatureStorageDatasourceRef ref,
) {
  return SignatureStorageDatasource();
}

/// Sign medical note use case provider.
///
/// Orchestrates the complete digital signature flow:
/// 1. Validates note can be signed
/// 2. Obtains signature (from default or new)
/// 3. Uploads signature snapshot to Storage
/// 4. Optionally saves signature as doctor's default
/// 5. Generates PDF with embedded signature
/// 6. Uploads signed PDF to Storage
/// 7. Updates note in Firestore with signature data and status=signed
@riverpod
SignMedicalNoteUseCase signMedicalNoteUseCase(SignMedicalNoteUseCaseRef ref) {
  return SignMedicalNoteUseCase(
    notesRepository: ref.watch(medicalNotesRepositoryProvider),
    signatureStorage: ref.watch(signatureStorageDatasourceProvider),
    onUpdateDoctorSignature: (String doctorId, DoctorSignatureInfo info) async {
      // Get current doctor profile
      final doctorsRepo = ref.read(doctorsRepositoryProvider);
      final doctorResult = await doctorsRepo.getDoctorById(doctorId);

      await doctorResult.maybeMap(
        success: (success) async {
          final currentDoctor = success.data;
          if (currentDoctor != null) {
            // Update with new signature info
            final updatedDoctor = currentDoctor.copyWith(signatureInfo: info);
            await doctorsRepo.updateDoctorProfile(updatedDoctor);
          }
        },
        orElse: () async {},
      );
    },
  );
}

// =============================================================================
// Scribe V2 Storage Providers
// =============================================================================

/// Scribe V2 storage datasource provider.
///
/// Handles Firestore operations for persisting Scribe V2 pipeline results.
/// Storage location: medical_notes/{noteId}/scribe_v2/latest
///
/// This datasource stores:
/// - Transcript segments with speaker and timing info
/// - Extracted clinical facts (structured JSON)
/// - Evidence mapping (facts → transcript quotes/timestamps)
/// - Composed SOAP note text
/// - Pipeline metadata (source, model, timings)
@riverpod
ScribeV2StorageDatasource scribeV2StorageDatasource(Ref ref) {
  return ScribeV2StorageDatasource();
}

// ─────────────────────────────────────────────────────────────────────────────
// Debug & Telemetry Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Features flag to enable the Scribe V2 Evidence Debug Hook in UI.
/// Features flag to enable the Scribe V2 Evidence Debug Hook in UI.
final enableEvidenceDebugHookProvider = Provider<bool>((ref) {
  // Default to false. Can be overridden in main.dart or tests.
  return false;
});

/// Provides the current application version.
@riverpod
String appVersion(Ref ref) {
  // TODO: Integrate package_info_plus for real version
  return '1.0.0+1';
}
