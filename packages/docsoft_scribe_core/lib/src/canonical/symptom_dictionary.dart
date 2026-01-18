// packages/docsoft_scribe_core/lib/src/canonical/symptom_dictionary.dart
//
// ÉPICA 1: Symptom Dictionary
// Maps Spanish vernacular terms to canonical symptom codes.

import 'canonical_clinical_facts.dart';

/// Dictionary entry for a canonical symptom.
class SymptomEntry {
  const SymptomEntry({
    required this.code,
    required this.displayEs,
    required this.synonyms,
    this.bodySystem = 'general',
  });

  /// Canonical code (lowercase, no diacritics).
  final String code;

  /// Preferred display in Spanish.
  final String displayEs;

  /// List of synonym patterns (lowercase).
  final List<String> synonyms;

  /// Body system for grouping.
  final String bodySystem;
}

/// Static dictionary of ENT-focused symptoms.
///
/// This is a deterministic mapping, no AI involved.
class SymptomDictionary {
  SymptomDictionary._();

  static const List<SymptomEntry> _entries = [
    // ENT - Ear
    SymptomEntry(
      code: 'otalgia',
      displayEs: 'Otalgia',
      synonyms: [
        'dolor de oido',
        'dolor del oido',
        'dolor en el oido',
        'dolor en oido',
        'dolor oido',
        'duele el oido',
        'duele oido',
        'le duele el oido',
        'me duele el oido',
        'otalgia',
        'dolor punzante en el oido',
        'dolor punzante oido',
        'dolor de oreja',
        'dolor en la oreja',
      ],
      bodySystem: 'ENT',
    ),
    SymptomEntry(
      code: 'otorrea',
      displayEs: 'Otorrea',
      synonyms: [
        'otorrea',
        'escurrimiento',
        'escurrimiento del oido',
        'secrecion del oido',
        'supuracion',
        'sale liquido del oido',
        'liquido del oido',
        'secrecion otica',
      ],
      bodySystem: 'ENT',
    ),
    SymptomEntry(
      code: 'hipoacusia',
      displayEs: 'Hipoacusia',
      synonyms: [
        'hipoacusia',
        'no oye bien',
        'no escucha bien',
        'sordera',
        'perdida de audicion',
        'perdida auditiva',
        'oye menos',
        'baja audicion',
      ],
      bodySystem: 'ENT',
    ),
    SymptomEntry(
      code: 'acufeno',
      displayEs: 'Acúfeno',
      synonyms: [
        'acufeno',
        'tinnitus',
        'zumbido',
        'zumbido en el oido',
        'ruido en el oido',
        'pitido en el oido',
      ],
      bodySystem: 'ENT',
    ),

    // ENT - Nose/Sinus
    SymptomEntry(
      code: 'rinorrea',
      displayEs: 'Rinorrea',
      synonyms: [
        'rinorrea',
        'escurrimiento nasal',
        'moco',
        'moqueo',
        'secrecion nasal',
        'nariz que escurre',
        'flujo nasal',
      ],
      bodySystem: 'ENT',
    ),
    SymptomEntry(
      code: 'obstruccion_nasal',
      displayEs: 'Obstrucción nasal',
      synonyms: [
        'obstruccion nasal',
        'nariz tapada',
        'congestion nasal',
        'no respira por la nariz',
        'nariz congestionada',
      ],
      bodySystem: 'ENT',
    ),
    SymptomEntry(
      code: 'epistaxis',
      displayEs: 'Epistaxis',
      synonyms: [
        'epistaxis',
        'sangrado nasal',
        'sangre de la nariz',
        'hemorragia nasal',
        'le sangra la nariz',
      ],
      bodySystem: 'ENT',
    ),

    // ENT - Throat
    SymptomEntry(
      code: 'odinofagia',
      displayEs: 'Odinofagia',
      synonyms: [
        'odinofagia',
        'dolor de garganta',
        'dolor al tragar',
        'dolor al pasar',
        'duele al tragar',
        'garganta irritada',
        'ardor de garganta',
      ],
      bodySystem: 'ENT',
    ),
    SymptomEntry(
      code: 'disfagia',
      displayEs: 'Disfagia',
      synonyms: [
        'disfagia',
        'dificultad para tragar',
        'no puede tragar',
        'se atora',
        'problemas para tragar',
      ],
      bodySystem: 'ENT',
    ),
    SymptomEntry(
      code: 'disfonia',
      displayEs: 'Disfonía',
      synonyms: [
        'disfonia',
        'ronquera',
        'voz ronca',
        'cambio de voz',
        'afonia',
        'perdida de voz',
      ],
      bodySystem: 'ENT',
    ),

    // Neurological/Vestibular
    SymptomEntry(
      code: 'mareo',
      displayEs: 'Mareo',
      synonyms: [
        'mareo',
        'mareado',
        'me mareo',
        'sensacion de mareo',
        'aturdido',
        'inestabilidad',
      ],
      bodySystem: 'neuro',
    ),
    SymptomEntry(
      code: 'vertigo',
      displayEs: 'Vértigo',
      synonyms: [
        'vertigo',
        'sensacion rotatoria',
        'todo da vueltas',
        'gira todo',
        'vertigo rotatorio',
      ],
      bodySystem: 'neuro',
    ),
    SymptomEntry(
      code: 'cefalea',
      displayEs: 'Cefalea',
      synonyms: [
        'cefalea',
        'dolor de cabeza',
        'jaqueca',
        'migrana',
      ],
      bodySystem: 'neuro',
    ),

    // Systemic
    SymptomEntry(
      code: 'fiebre',
      displayEs: 'Fiebre',
      synonyms: [
        'fiebre',
        'calentura',
        'temperatura alta',
        'febril',
        'tiene fiebre',
        'esta con fiebre',
      ],
      bodySystem: 'systemic',
    ),
    SymptomEntry(
      code: 'tos',
      displayEs: 'Tos',
      synonyms: [
        'tos',
        'tose',
        'tosiendo',
      ],
      bodySystem: 'respiratory',
    ),
    SymptomEntry(
      code: 'nausea',
      displayEs: 'Náusea',
      synonyms: [
        'nausea',
        'asco',
        'ganas de vomitar',
      ],
      bodySystem: 'GI',
    ),
    SymptomEntry(
      code: 'vomito',
      displayEs: 'Vómito',
      synonyms: [
        'vomito',
        'vomita',
        'vomitando',
      ],
      bodySystem: 'GI',
    ),
  ];

  /// Normalize text for matching: lowercase, remove accents, trim.
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Look up a symptom from Spanish text.
  ///
  /// Returns null if no match found.
  static CanonicalSymptom? lookup(String text) {
    final normalized = _normalize(text);

    for (final entry in _entries) {
      for (final synonym in entry.synonyms) {
        if (normalized.contains(synonym) || synonym.contains(normalized)) {
          // Extract laterality from original text
          final laterality = Laterality.fromSpanishText(text);
          return CanonicalSymptom(
            code: entry.code,
            displayEs: entry.displayEs,
            laterality: laterality,
          );
        }
      }
    }

    return null;
  }

  /// Check if text matches any known symptom.
  static bool isKnownSymptom(String text) {
    return lookup(text) != null;
  }

  /// Check if text is a temporal/modifier phrase, not a symptom.
  ///
  /// These should go to HPI.keyPoints, not ROS.positives.
  static bool isTemporalModifier(String text) {
    final normalized = _normalize(text);
    const modifiers = [
      'empeora',
      'mejora',
      'por las noches',
      'por la noche',
      'en la manana',
      'por la manana',
      'al despertar',
      'al acostarse',
      'desde hace',
      'hace dias',
      'hace semanas',
      'intermitente',
      'constante',
      'progresivo',
      'agudo',
      'cronico',
      'recurrente',
    ];

    for (final mod in modifiers) {
      if (normalized.contains(mod)) {
        return true;
      }
    }
    return false;
  }

  /// Get display name for a code.
  static String? getDisplayEs(String code) {
    final entry = _entries.firstWhere(
      (e) => e.code == code,
      orElse: () => const SymptomEntry(
        code: '',
        displayEs: '',
        synonyms: [],
      ),
    );
    return entry.displayEs.isEmpty ? null : entry.displayEs;
  }
}
