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
import '../medicalization/glossary_loader.dart';
import '../medicalization/medicalization_glossary.dart';
import '../note_ai_service_impl.dart';
import 'process_encounter_usecase.dart';

/// Factory for creating Scribe pipeline components.
///
/// Provides static factory methods to construct pipeline components
/// without Riverpod, UI, or Flutter widget dependencies.
///
/// Usage:
/// ```dart
/// final useCase = ScribePipelineFactory.forEval(
///   apiKey: 'sk-...',
///   glossaryLoader: FileGlossaryLoader(),
/// );
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
  /// [glossaryLoader] - Loade logic for medical terms (required, e.g. FileGlossaryLoader)
  /// [extractorModel] - Model for extraction (default: gpt-4o-mini)
  /// [composerModel] - Model for composition (default: gpt-4o-mini)
  static ProcessEncounterUseCase forEval({
    required String apiKey,
    required GlossaryLoader glossaryLoader,
    String extractorModel = 'gpt-4o-mini',
    String composerModel = 'gpt-4o-mini',
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
    final medicalizationService = MedicalizationServiceFactory.create(
      glossary: MedicalizationGlossary(loader: glossaryLoader),
    );

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
    // 1) dart-define
    const fromDefineOpenAI = String.fromEnvironment('OPENAI_API_KEY');
    const fromDefineDocsoft = String.fromEnvironment('DOCSOFT_OPENAI_KEY');

    if (fromDefineOpenAI.isNotEmpty) return fromDefineOpenAI;
    if (fromDefineDocsoft.isNotEmpty) return fromDefineDocsoft;

    // 2) OS env (mostly works on desktop runners, not on Android)
    final keyFromEnv =
        Platform.environment['OPENAI_API_KEY'] ??
        Platform.environment['DOCSOFT_OPENAI_KEY'];

    if (keyFromEnv == null || keyFromEnv.isEmpty) {
      throw StateError(
        'No OpenAI API key found. Use --dart-define=OPENAI_API_KEY=... (preferred) or set env var.',
      );
    }

    return keyFromEnv;
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
  ///
  /// [glossary] - Optional custom glossary. If not provided, uses singleton.
  /// For CLI/harness: pass a glossary with [FileGlossaryLoader]
  /// For Flutter app: ensure [MedicalizationGlossary.defaultLoader] is set.
  static MedicalizationService create({MedicalizationGlossary? glossary}) {
    return LocalMedicalizationService(glossary: glossary);
  }
}
