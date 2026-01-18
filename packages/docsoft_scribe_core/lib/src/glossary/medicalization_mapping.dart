// packages/docsoft_scribe_core/lib/src/glossary/medicalization_mapping.dart
//
// Data class for medicalization mappings.

import 'package:equatable/equatable.dart';

/// Full mapping with metadata from glossary.
class MedicalizationMapping extends Equatable {
  const MedicalizationMapping({
    required this.colloquial,
    required this.clinical,
    required this.category,
    this.note,
  });

  /// The colloquial/informal term (e.g., "dolor de cabeza").
  final String colloquial;

  /// The clinical/medical term (e.g., "cefalea").
  final String clinical;

  /// Category from glossary (symptoms, symptoms_orl, voice_transforms, etc.).
  final String category;

  /// Optional note about the mapping.
  final String? note;

  @override
  List<Object?> get props => [colloquial, clinical, category, note];

  @override
  String toString() =>
      'MedicalizationMapping($colloquial -> $clinical [$category])';
}

/// Priority tiers for mapping categories.
///
/// Higher priority mappings are selected first when overlaps occur.
class MappingPriority {
  const MappingPriority._();

  /// Priority for clinical terms (symptoms, symptoms_orl, antecedentes, habits).
  /// These are specific medical mappings and should NEVER be blocked.
  static const int clinical = 300;

  /// Priority for specific phrases (reserved for future use).
  /// Compound expressions that are more specific than voice transforms.
  static const int phrases = 200;

  /// Priority for voice transforms (me duele → refiere dolor en).
  /// Generic first-to-third person conversions, lowest priority.
  static const int voiceTransforms = 100;

  /// Gets priority for a category name.
  static int forCategory(String category) {
    switch (category) {
      case 'symptoms':
      case 'symptoms_orl':
      case 'antecedentes':
      case 'habits':
        return clinical;
      case 'phrases':
        return phrases;
      case 'voice_transforms':
        return voiceTransforms;
      default:
        // Unknown categories get mid-priority
        return phrases;
    }
  }
}
