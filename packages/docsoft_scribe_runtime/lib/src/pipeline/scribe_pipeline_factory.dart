// packages/docsoft_scribe_runtime/lib/src/pipeline/scribe_pipeline_factory.dart
//
// Factory for creating pipeline runners with all dependencies.

import 'dart:io';

import 'package:docsoft_scribe_core/src/core/logger.dart';
import 'package:docsoft_scribe_core/src/glossary/glossary_loader.dart';
import 'package:docsoft_scribe_core/src/medicalization/medicalization_glossary.dart';
import 'package:docsoft_scribe_core/src/medicalization/medicalization_service.dart';

import '../clients/openai_client.dart';
import '../clients/openai_extractor_client.dart';
import '../clients/openai_composer_client.dart';
import '../repositories/encounter_extractor_repository_impl.dart';
import '../repositories/note_composer_repository_impl.dart';
import '../glossary/file_glossary_loader.dart';
import 'process_encounter_usecase.dart';
import 'scribe_pipeline_runner.dart';

/// Factory for creating configured pipeline instances.
///
/// Handles all dependency wiring for the pipeline:
/// - OpenAI clients (extractor, composer)
/// - Repository implementations
/// - Medicalization service with glossary
/// - Logging
class ScribePipelineFactory {
  const ScribePipelineFactory._();

  /// Creates a [ProcessEncounterUseCase] for evaluation harness.
  ///
  /// [apiKey] - OpenAI API key (required).
  /// [glossaryLoader] - Optional custom glossary loader.
  ///
  /// Returns a configured [ProcessEncounterUseCase].
  static ProcessEncounterUseCase forEval({
    required String apiKey,
    GlossaryLoader? glossaryLoader,
    LogSink? logger,
    String? projectRoot,
  }) {
    final log = logger ?? const PrintLogSink(verbose: false);

    // Create OpenAI clients
    final openAIClient = OpenAIClient(
      apiKey: apiKey,
      logger: log,
    );

    final extractorClient = OpenAIExtractorClient(
      openAIClient: openAIClient,
      logger: log,
    );

    final composerClient = OpenAIComposerClient(
      openAIClient: openAIClient,
    );

    // Create repositories
    final extractorRepo = EncounterExtractorRepositoryImpl(
      client: extractorClient,
      logger: log,
    );

    final composerRepo = NoteComposerRepositoryImpl(
      client: composerClient,
      logger: log,
    );

    // Create medicalization service
    final loader =
        glossaryLoader ?? RuntimeFileGlossaryLoader(projectRoot: projectRoot);
    final glossary = MedicalizationGlossary(loader: loader);
    final medicalizationService = LocalMedicalizationService(
      glossary: glossary,
      logSink: log,
    );

    // Return configured use case
    return ProcessEncounterUseCase(
      medicalizationService: medicalizationService,
      extractorRepository: extractorRepo,
      composerRepository: composerRepo,
      logger: log,
    );
  }

  /// Gets API key from environment.
  ///
  /// Checks in order:
  /// 1. OPENAI_API_KEY environment variable
  /// 2. .env file in current or parent directories
  ///
  /// Throws [StateError] if not found.
  static String getApiKeyFromEnv() {
    // Try environment variable first
    final envKey = Platform.environment['OPENAI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    // Try .env file
    final fileKey = _loadFromEnvFile();
    if (fileKey != null && fileKey.isNotEmpty) {
      return fileKey;
    }

    throw StateError(
      'OpenAI API key not found. Set OPENAI_API_KEY environment variable '
      'or add it to .env file.',
    );
  }

  /// Creates a production pipeline runner using OpenAI.
  ///
  /// [apiKey] - OpenAI API key (required).
  /// [glossaryLoader] - Optional custom glossary loader.
  /// [logger] - Optional logger. Defaults to [PrintLogSink].
  /// [projectRoot] - Optional project root for glossary location.
  ///
  /// Returns a configured [ScribePipelineRunner] ready for use.
  static ScribePipelineRunner createProductionRunner({
    String? apiKey,
    GlossaryLoader? glossaryLoader,
    LogSink? logger,
    String? projectRoot,
  }) {
    // Resolve API key
    final resolvedApiKey =
        apiKey ?? Platform.environment['OPENAI_API_KEY'] ?? _loadFromEnvFile();

    if (resolvedApiKey == null || resolvedApiKey.isEmpty) {
      throw StateError(
        'OpenAI API key not found. Set OPENAI_API_KEY environment variable '
        'or pass apiKey parameter.',
      );
    }

    final useCase = forEval(
      apiKey: resolvedApiKey,
      glossaryLoader: glossaryLoader,
      logger: logger,
      projectRoot: projectRoot,
    );

    return ScribePipelineRunner(useCase: useCase);
  }

  /// Creates dependencies individually for more control.
  ///
  /// Returns a [PipelineDependencies] object with all components.
  static PipelineDependencies createDependencies({
    String? apiKey,
    GlossaryLoader? glossaryLoader,
    LogSink? logger,
    String? projectRoot,
  }) {
    final resolvedApiKey =
        apiKey ?? Platform.environment['OPENAI_API_KEY'] ?? _loadFromEnvFile();

    if (resolvedApiKey == null || resolvedApiKey.isEmpty) {
      throw StateError(
        'OpenAI API key not found. Set OPENAI_API_KEY environment variable.',
      );
    }

    final log = logger ?? const PrintLogSink(verbose: false);

    final openAIClient = OpenAIClient(
      apiKey: resolvedApiKey,
      logger: log,
    );

    final extractorClient = OpenAIExtractorClient(
      openAIClient: openAIClient,
      logger: log,
    );

    final composerClient = OpenAIComposerClient(
      openAIClient: openAIClient,
    );

    final extractorRepo = EncounterExtractorRepositoryImpl(
      client: extractorClient,
      logger: log,
    );

    final composerRepo = NoteComposerRepositoryImpl(
      client: composerClient,
      logger: log,
    );

    final loader =
        glossaryLoader ?? RuntimeFileGlossaryLoader(projectRoot: projectRoot);
    final glossary = MedicalizationGlossary(loader: loader);
    final medicalizationService = LocalMedicalizationService(
      glossary: glossary,
      logSink: log,
    );

    return PipelineDependencies(
      openAIClient: openAIClient,
      extractorClient: extractorClient,
      composerClient: composerClient,
      extractorRepository: extractorRepo,
      composerRepository: composerRepo,
      medicalizationService: medicalizationService,
      logger: log,
    );
  }

  /// Attempts to load API key from .env file.
  static String? _loadFromEnvFile() {
    try {
      // Try current directory
      var envFile = File('.env');
      if (!envFile.existsSync()) {
        // Try project root
        envFile = File('../../.env');
      }

      if (envFile.existsSync()) {
        final lines = envFile.readAsLinesSync();
        for (final line in lines) {
          if (line.startsWith('OPENAI_API_KEY=')) {
            return line.substring('OPENAI_API_KEY='.length).trim();
          }
        }
      }
    } catch (_) {
      // Ignore errors, fall back to null
    }
    return null;
  }
}

/// Container for all pipeline dependencies.
///
/// Useful when you need access to individual components
/// for testing or custom configuration.
class PipelineDependencies {
  const PipelineDependencies({
    required this.openAIClient,
    required this.extractorClient,
    required this.composerClient,
    required this.extractorRepository,
    required this.composerRepository,
    required this.medicalizationService,
    required this.logger,
  });

  final OpenAIClient openAIClient;
  final OpenAIExtractorClient extractorClient;
  final OpenAIComposerClient composerClient;
  final EncounterExtractorRepositoryImpl extractorRepository;
  final NoteComposerRepositoryImpl composerRepository;
  final MedicalizationService medicalizationService;
  final LogSink logger;

  /// Creates a [ProcessEncounterUseCase] from these dependencies.
  ProcessEncounterUseCase createUseCase() {
    return ProcessEncounterUseCase(
      medicalizationService: medicalizationService,
      extractorRepository: extractorRepository,
      composerRepository: composerRepository,
      logger: logger,
    );
  }

  /// Creates a [ScribePipelineRunner] from these dependencies.
  ScribePipelineRunner createRunner() {
    return ScribePipelineRunner(useCase: createUseCase());
  }
}
