import '../../../../../core/base/failure.dart';
import '../../../../../core/base/repository.dart';
import '../../../../../core/base/result.dart';
import '../../../data/scribe/dtos/clinical_facts_dto.dart';
import '../entities/transcript_with_speakers.dart';

/// Context information to help guide clinical fact extraction.
class ExtractionContext {
  const ExtractionContext({
    this.specialty,
    this.encounterType,
    this.patientAge,
    this.patientGender,
    this.priorDiagnoses = const [],
  });

  /// Medical specialty (e.g., "otorrinolaringología", "medicina general").
  final String? specialty;

  /// Type of encounter (e.g., "consulta", "seguimiento", "urgencia").
  final String? encounterType;

  /// Patient age (helps contextualize findings).
  final int? patientAge;

  /// Patient gender.
  final String? patientGender;

  /// Known prior diagnoses for context.
  final List<String> priorDiagnoses;
}

/// Repository interface for extracting clinical facts from transcripts.
///
/// Stage 2 of the medical scribe pipeline: analyzes the transcript
/// to extract structured clinical information with evidence.
abstract base class EncounterExtractorRepository extends Repository {
  /// Extracts clinical facts from a transcript.
  ///
  /// [transcript] - The transcript with speaker information.
  /// [context] - Optional context to improve extraction accuracy.
  ///
  /// Returns [ClinicalFactsDTO] on success, [Failure] on error.
  Future<Result<ClinicalFactsDTO, Failure>> extract(
    TranscriptWithSpeakers transcript, {
    ExtractionContext context = const ExtractionContext(),
  });
}
