// lib/src/features/medical_notes/application/scribe/scribe_pipeline_factory.dart

import 'dart:io';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../data/scribe/datasources/llm/openai_composer_client.dart';
import '../../data/scribe/datasources/llm/openai_extractor_client.dart';
import '../../data/scribe/repositories_impl/encounter_extractor_repository_impl.dart';
import '../../data/scribe/repositories_impl/note_composer_repository_impl.dart';
import '../../domain/scribe/entities/transcript_with_speakers.dart';
import '../../domain/scribe/repositories/transcription_repository.dart';
import '../medicalization/medicalization_service.dart';
import '../note_ai_service_impl.dart';
import 'process_encounter_usecase.dart';

/// Factory for creating Scribe pipeline components.
///
/// Provides static factory methods to construct pipeline components
/// without Riverpod, UI, or Flutter widget dependencies.
///
/// Usage:
/// ```dart
/// final useCase = ScribePipelineFactory.forEval(apiKey: 'sk-...');
/// final result = await useCase.callFromTranscript(transcript);
/// ```
class ScribePipelineFactory {
  ScribePipelineFactory._();

  /// Creates a ProcessEncounterUseCase for evaluation purposes.
  ///
  /// This factory method builds all required components:
  /// - OpenAIClient for LLM calls
  /// - EncounterExtractorRepository for fact extraction
  /// - NoteComposerRepository for SOAP composition
  /// - LocalMedicalizationService for term normalization
  /// - Dummy TranscriptionRepository (not used in eval)
  ///
  /// [apiKey] - OpenAI API key (required)
  /// [extractorModel] - Model for extraction (default: gpt-4o-mini)
  /// [composerModel] - Model for composition (default: gpt-4o-mini)
  /// [disableFallbacks] - If true, disables generated fallback content
  static ProcessEncounterUseCase forEval({
    required String apiKey,
    String extractorModel = 'gpt-4o-mini',
    String composerModel = 'gpt-4o-mini',
    bool disableFallbacks = true,
  }) {
    // Create OpenAI client
    final openAIClient = OpenAIClient(apiKey: apiKey);

    // Create extractor components
    final extractorClient = OpenAIExtractorClient(
      openAIClient: openAIClient,
      defaultModel: extractorModel,
      defaultTemperature: 0.0, // Max determinism
      defaultMaxTokens: 1200,
    );
    final extractorRepository = EncounterExtractorRepositoryImpl(
      client: extractorClient,
    );

    // Create composer components
    final composerClient = OpenAIComposerClient(
      openAIClient: openAIClient,
      defaultModel: composerModel,
      defaultTemperature: 0.1,
      defaultMaxTokens: 800,
    );
    final composerRepository = NoteComposerRepositoryImpl(
      client: composerClient,
    );

    // Create medicalization service (local, no LLM)
    final medicalizationService = MedicalizationServiceFactory.create();

    // Create dummy transcription repository (not used in eval)
    final transcriptionRepository = _DummyTranscriptionRepository();

    // Create use case
    return ProcessEncounterUseCase(
      transcriptionRepository: transcriptionRepository,
      extractorRepository: extractorRepository,
      composerRepository: composerRepository,
      medicalizationService: medicalizationService,
    );
  }

  /// Gets OpenAI API key from environment.
  ///
  /// Checks in order:
  /// 1. OPENAI_API_KEY environment variable
  /// 2. DOCSOFT_OPENAI_KEY environment variable
  ///
  /// Throws if no key is found.
  static String getApiKeyFromEnv() {
    final key =
        Platform.environment['OPENAI_API_KEY'] ??
        Platform.environment['DOCSOFT_OPENAI_KEY'];

    if (key == null || key.isEmpty) {
      throw StateError(
        'No OpenAI API key found. Set OPENAI_API_KEY or DOCSOFT_OPENAI_KEY environment variable.',
      );
    }

    return key;
  }
}

/// Dummy transcription repository for evaluation.
///
/// The evaluation harness uses callFromTranscript() which bypasses STT,
/// so this repository is never actually called.
final class _DummyTranscriptionRepository extends TranscriptionRepository {
  @override
  Future<Result<TranscriptWithSpeakers, Failure>> transcribe(
    File audioFile, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async {
    throw UnimplementedError(
      'Transcription is not used in evaluation mode. Use callFromTranscript() instead.',
    );
  }
}

/// Extension to create MedicalizationService without Riverpod.
extension MedicalizationServiceFactory on MedicalizationService {
  /// Creates a LocalMedicalizationService instance.
  static MedicalizationService create() {
    return LocalMedicalizationService();
  }
}
