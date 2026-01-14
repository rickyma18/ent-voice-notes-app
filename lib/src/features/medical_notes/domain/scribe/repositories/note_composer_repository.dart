import '../../../../../core/base/failure.dart';
import '../../../../../core/base/repository.dart';
import '../../../../../core/base/result.dart';
import '../entities/clinical_facts_dto.dart';

/// Template configuration for SOAP note composition.
class NoteTemplate {
  const NoteTemplate({
    this.format = NoteFormat.soap,
    this.includeEvidence = false,
    this.language = 'es',
    this.specialty,
    this.customInstructions,
  });

  /// The note format to generate.
  final NoteFormat format;

  /// Whether to include evidence quotes in the output.
  final bool includeEvidence;

  /// Output language code.
  final String language;

  /// Medical specialty for terminology preferences.
  final String? specialty;

  /// Custom instructions for the composer.
  final String? customInstructions;
}

/// Supported note formats.
enum NoteFormat {
  /// Standard SOAP format (Subjective, Objective, Assessment, Plan).
  soap,

  /// History and Physical format.
  hp,

  /// Progress note format.
  progress,

  /// Custom format defined by template instructions.
  custom,
}

/// Repository interface for composing clinical notes from extracted facts.
///
/// Stage 3 of the medical scribe pipeline: transforms structured
/// clinical facts into a formatted medical note.
abstract base class NoteComposerRepository extends Repository {
  /// Composes a medical note from clinical facts.
  ///
  /// [facts] - The extracted clinical facts.
  /// [template] - Optional template configuration.
  ///
  /// Returns the composed note text on success, [Failure] on error.
  Future<Result<String, Failure>> composeSoap(
    ClinicalFactsDTO facts, {
    NoteTemplate template = const NoteTemplate(),
  });
}
