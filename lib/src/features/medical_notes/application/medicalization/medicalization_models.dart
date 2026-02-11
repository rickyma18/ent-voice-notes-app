// lib/src/features/medical_notes/application/medicalization/medicalization_models.dart

/// Models for the medicalization layer.
///
/// These models are used to represent medicalized text with traceability
/// information, allowing the UI to show evidence and normalized terms.

/// Represents a single term mapping from colloquial to clinical.
class NormalizedTerm {
  const NormalizedTerm({
    required this.original,
    required this.clinical,
    this.type = 'symptom',
    this.note,
  });

  /// The original colloquial term found in the transcript.
  final String original;

  /// The clinical/medical term it was normalized to.
  final String clinical;

  /// Type of term: 'symptom', 'condition', 'medication', 'negation', 'voice'.
  final String type;

  /// Optional clinical note/warning about this mapping.
  final String? note;

  Map<String, dynamic> toJson() => {
    'original': original,
    'clinical': clinical,
    'type': type,
    if (note != null) 'note': note,
  };

  factory NormalizedTerm.fromJson(Map<String, dynamic> json) => NormalizedTerm(
    original: json['original'] as String,
    clinical: json['clinical'] as String,
    type: json['type'] as String? ?? 'symptom',
    note: json['note'] as String?,
  );
}

/// Represents evidence from the original transcript.
class TranscriptEvidence {
  const TranscriptEvidence({
    required this.text,
    this.startOffset,
    this.endOffset,
  });

  /// The exact text from the transcript that supports this field.
  final String text;

  /// Optional character offset where this evidence starts in the transcript.
  final int? startOffset;

  /// Optional character offset where this evidence ends in the transcript.
  final int? endOffset;

  Map<String, dynamic> toJson() => {
    'text': text,
    if (startOffset != null) 'start': startOffset,
    if (endOffset != null) 'end': endOffset,
  };

  factory TranscriptEvidence.fromJson(Map<String, dynamic> json) =>
      TranscriptEvidence(
        text: json['text'] as String,
        startOffset: json['start'] as int?,
        endOffset: json['end'] as int?,
      );
}

/// Represents an uncertainty flag when the patient expressed doubt.
class UncertaintyFlag {
  const UncertaintyFlag({required this.originalPhrase, required this.type});

  /// The phrase that indicated uncertainty (e.g., "creo que", "como que").
  final String originalPhrase;

  /// Type of uncertainty: 'patient_doubt', 'approximation', 'hearsay'.
  final String type;

  Map<String, dynamic> toJson() => {
    'original_phrase': originalPhrase,
    'type': type,
  };

  factory UncertaintyFlag.fromJson(Map<String, dynamic> json) =>
      UncertaintyFlag(
        originalPhrase: json['original_phrase'] as String,
        type: json['type'] as String,
      );
}

/// Represents a medicalized section with full traceability.
///
/// This is the output format for each section after medicalization.
/// Can be serialized to JSON for the LLM or stored for audit.
class MedicalizedSection {
  const MedicalizedSection({
    required this.sectionText,
    this.evidence = const [],
    this.normalizedTerms = const [],
    this.uncertaintyFlags = const [],
  });

  /// The final medicalized text for this section.
  final String sectionText;

  /// Evidence from the transcript that supports this section.
  final List<TranscriptEvidence> evidence;

  /// List of term normalizations applied.
  final List<NormalizedTerm> normalizedTerms;

  /// List of uncertainty flags if patient expressed doubt.
  final List<UncertaintyFlag> uncertaintyFlags;

  /// Returns true if this section has no content.
  bool get isEmpty => sectionText.isEmpty;

  /// Returns true if this section has content.
  bool get isNotEmpty => sectionText.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'section_text': sectionText,
    'evidence': evidence.map((e) => e.toJson()).toList(),
    'normalized_terms': normalizedTerms.map((t) => t.toJson()).toList(),
    'uncertainty_flags': uncertaintyFlags.map((f) => f.toJson()).toList(),
  };

  factory MedicalizedSection.fromJson(
    Map<String, dynamic> json,
  ) => MedicalizedSection(
    sectionText: json['section_text'] as String? ?? '',
    evidence:
        (json['evidence'] as List<dynamic>?)
            ?.map((e) => TranscriptEvidence.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    normalizedTerms:
        (json['normalized_terms'] as List<dynamic>?)
            ?.map((t) => NormalizedTerm.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [],
    uncertaintyFlags:
        (json['uncertainty_flags'] as List<dynamic>?)
            ?.map((f) => UncertaintyFlag.fromJson(f as Map<String, dynamic>))
            .toList() ??
        [],
  );

  /// Creates an empty section.
  static const MedicalizedSection empty = MedicalizedSection(sectionText: '');
}

/// Result of the medicalization layer processing.
///
/// Contains the dictionary of mappings that were loaded for logging/debug.
class MedicalizationDictionaryResult {
  const MedicalizationDictionaryResult({
    required this.mappingsLoaded,
    required this.mappingsApplied,
  });

  /// Total number of mappings loaded from the dictionary.
  final int mappingsLoaded;

  /// Number of mappings actually applied to the text.
  final int mappingsApplied;
}
