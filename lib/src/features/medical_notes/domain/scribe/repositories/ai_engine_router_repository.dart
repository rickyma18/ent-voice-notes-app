import 'encounter_extractor_repository.dart';

/// Router interface for selecting the AI engine strategy at runtime.
///
/// It strictly follows the [EncounterExtractorRepository] contract
/// so it can be swapped transparently into the use case.
abstract base class AiEngineRouterRepository extends EncounterExtractorRepository {}
