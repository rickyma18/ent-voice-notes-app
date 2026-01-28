import '../../../../../core/base/failure.dart';
import '../../../../../core/base/result.dart';
import '../../../../../core/logger/log.dart';
import '../../../domain/entities/ai_engine.dart';
import '../../../domain/scribe/entities/transcript_with_speakers.dart';
import '../../../domain/scribe/repositories/ai_engine_router_repository.dart';
import '../../../domain/scribe/repositories/encounter_extractor_repository.dart';
import '../../../domain/sources/engine_setting_source.dart';
import '../dtos/clinical_facts_dto.dart';

/// Implementation of [AiEngineRouterRepository] that delegates to specific
/// engine repositories based on the persistent [EngineSettingSource].
final class AiEngineRouterRepositoryImpl extends AiEngineRouterRepository {
  AiEngineRouterRepositoryImpl({
    required EngineSettingSource engineSettingSource,
    required EncounterExtractorRepository medgemmaRepository,
    required EncounterExtractorRepository openAiRepository,
  }) : _engineSettingSource = engineSettingSource,
       _medgemmaRepository = medgemmaRepository,
       _openAiRepository = openAiRepository;

  final EngineSettingSource _engineSettingSource;
  final EncounterExtractorRepository _medgemmaRepository;
  final EncounterExtractorRepository _openAiRepository;

  @override
  Future<Result<ClinicalFactsDTO, Failure>> extract(
    TranscriptWithSpeakers transcript, {
    ExtractionContext context = const ExtractionContext(),
  }) async {
    final engine = await _engineSettingSource.getEngine();

    Log.info(
      '[AiEngineRouter] Routing extraction request to engine: ${engine.name}',
    );

    switch (engine) {
      case AiEngine.medgemma:
        return _medgemmaRepository.extract(transcript, context: context);
      case AiEngine.openai:
        return _openAiRepository.extract(transcript, context: context);
    }
  }
}
