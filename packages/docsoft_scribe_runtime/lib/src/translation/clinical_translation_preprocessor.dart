// packages/docsoft_scribe_runtime/lib/src/translation/clinical_translation_preprocessor.dart
//
// ÉPICA 2: Preprocessor that protects clinical markers before translation.
//
// CRITICAL DESIGN:
// - Replaces clinical markers with placeholders [[CLN_xxxx]]
// - Placeholders are designed to pass through translation untouched
// - Original values stored for post-processing restoration

import 'package:docsoft_scribe_core/src/translation/translation.dart';

/// Preprocessor that protects clinical markers with placeholders.
class ClinicalTranslationPreprocessor {
  ClinicalTranslationPreprocessor([this._context]);

  final ClinicalContext? _context;

  // Placeholder format: [[CLN_0001]], [[CLN_0002]], etc.
  static const _placeholderPrefix = '[[CLN_';
  static const _placeholderSuffix = ']]';

  int _placeholderCounter = 0;
  final List<ProtectedToken> _protectedTokens = [];

  /// Protects clinical markers in text, returning protected text.
  ///
  /// Returns tuple of (protectedText, protectedTokens).
  PreprocessResult process(String text) {
    _placeholderCounter = 0;
    _protectedTokens.clear();

    var result = text;

    // Order matters: protect more specific patterns first
    result = _protectDosages(result);
    result = _protectFrequencies(result);
    result = _protectTemporalMarkers(result);
    result = _protectNegations(result);
    result = _protectLaterality(result);
    result = _protectAmbiguousAbbreviations(result);

    return PreprocessResult(
      protectedText: result,
      protectedTokens: List.unmodifiable(_protectedTokens),
    );
  }

  String _nextPlaceholder() {
    _placeholderCounter++;
    final id = _placeholderCounter.toString().padLeft(4, '0');
    return '$_placeholderPrefix$id$_placeholderSuffix';
  }

  String _protect(
    String text,
    Pattern pattern,
    TokenCategory category, {
    String Function(String)? englishEquivalent,
  }) {
    return text.replaceAllMapped(
      pattern is String
          ? RegExp(pattern, caseSensitive: false)
          : pattern as RegExp,
      (match) {
        final original = match.group(0)!;
        final placeholder = _nextPlaceholder();
        _protectedTokens.add(ProtectedToken(
          original: original,
          placeholder: placeholder,
          category: category,
          englishEquivalent: englishEquivalent?.call(original),
        ));
        return placeholder;
      },
    );
  }

  /// Protect dosages: "500 mg", "3 gotas", "media tableta", etc.
  String _protectDosages(String text) {
    // Pattern: number + space + unit
    // Units: mg, g, ml, mL, gotas, tableta(s), comprimido(s), cápsula(s)
    final dosagePattern = RegExp(
      r'\b(\d+(?:[.,]\d+)?)\s*(mg|g|ml|mL|mcg|μg|gotas?|tabletas?|'
      r'comprimidos?|cápsulas?|capsulas?|sobres?|ampollas?|UI)\b',
      caseSensitive: false,
    );

    text = _protect(text, dosagePattern, TokenCategory.dosage,
        englishEquivalent: _dosageToEnglish);

    // "media tableta", "una tableta"
    final fractionalPattern = RegExp(
      r'\b(media|un cuarto de|medio)\s+(tableta|comprimido|cápsula)\b',
      caseSensitive: false,
    );

    return _protect(text, fractionalPattern, TokenCategory.dosage,
        englishEquivalent: _fractionalDosageToEnglish);
  }

  String _dosageToEnglish(String dosage) {
    // Preserve numbers exactly, only translate units
    return dosage
        .replaceAll(RegExp(r'\bgotas?\b', caseSensitive: false), 'drops')
        .replaceAll(RegExp(r'\btabletas?\b', caseSensitive: false), 'tablets')
        .replaceAll(
            RegExp(r'\bcomprimidos?\b', caseSensitive: false), 'tablets')
        .replaceAll(RegExp(r'\bcápsulas?\b', caseSensitive: false), 'capsules')
        .replaceAll(RegExp(r'\bcapsulas?\b', caseSensitive: false), 'capsules')
        .replaceAll(RegExp(r'\bsobres?\b', caseSensitive: false), 'sachets')
        .replaceAll(RegExp(r'\bampollas?\b', caseSensitive: false), 'ampules');
  }

  String _fractionalDosageToEnglish(String dosage) {
    return dosage
        .replaceAll(RegExp(r'\bmedia\b', caseSensitive: false), 'half')
        .replaceAll(
            RegExp(r'\bun cuarto de\b', caseSensitive: false), 'quarter')
        .replaceAll(RegExp(r'\bmedio\b', caseSensitive: false), 'half')
        .replaceAll(RegExp(r'\btableta\b', caseSensitive: false), 'tablet')
        .replaceAll(RegExp(r'\bcomprimido\b', caseSensitive: false), 'tablet')
        .replaceAll(RegExp(r'\bcápsula\b', caseSensitive: false), 'capsule');
  }

  /// Protect frequency markers: "c/8h", "cada 12 horas", "diario", "PRN".
  String _protectFrequencies(String text) {
    // c/Xh format
    final cSlashPattern = RegExp(r'\bc/(\d+)\s?h\b', caseSensitive: false);
    text = _protect(text, cSlashPattern, TokenCategory.frequency,
        englishEquivalent: (s) {
      final match = RegExp(r'c/(\d+)', caseSensitive: false).firstMatch(s);
      return match != null ? 'q${match.group(1)}h' : s;
    });

    // "cada X horas"
    final cadaPattern =
        RegExp(r'\bcada\s+(\d+)\s+horas?\b', caseSensitive: false);
    text = _protect(text, cadaPattern, TokenCategory.frequency,
        englishEquivalent: (s) {
      final match = RegExp(r'cada\s+(\d+)', caseSensitive: false).firstMatch(s);
      return match != null ? 'every ${match.group(1)} hours' : s;
    });

    // "X veces al día"
    final vecesPattern =
        RegExp(r'\b(\d+)\s+veces?\s+al\s+día\b', caseSensitive: false);
    text = _protect(text, vecesPattern, TokenCategory.frequency,
        englishEquivalent: (s) {
      final match = RegExp(r'(\d+)\s+veces?').firstMatch(s);
      return match != null ? '${match.group(1)} times daily' : s;
    });

    // Common frequency terms
    final freqTerms = {
      r'\bdiario\b': 'daily',
      r'\bdiaria\b': 'daily',
      r'\bPRN\b': 'PRN',
      r'\bSOS\b': 'PRN',
      r'\ba demanda\b': 'as needed',
      r'\bpor razón necesaria\b': 'PRN',
    };

    for (final entry in freqTerms.entries) {
      text = _protect(
        text,
        RegExp(entry.key, caseSensitive: false),
        TokenCategory.frequency,
        englishEquivalent: (_) => entry.value,
      );
    }

    return text;
  }

  /// Protect temporal markers: "hace 3 días", "desde hace 2 semanas".
  String _protectTemporalMarkers(String text) {
    // "hace X días/semanas/meses"
    final hacePattern = RegExp(
      r'\bhace\s+(\d+)\s+(días?|semanas?|meses?|años?|horas?)\b',
      caseSensitive: false,
    );
    text = _protect(text, hacePattern, TokenCategory.temporal,
        englishEquivalent: _temporalToEnglish);

    // "desde hace X días"
    final desdeHacePattern = RegExp(
      r'\bdesde\s+hace\s+(\d+)\s+(días?|semanas?|meses?)\b',
      caseSensitive: false,
    );
    text = _protect(text, desdeHacePattern, TokenCategory.temporal,
        englishEquivalent: _temporalToEnglish);

    // "por X días" (duration for treatment)
    final porPattern = RegExp(
      r'\bpor\s+(\d+)\s+(días?|semanas?)\b',
      caseSensitive: false,
    );
    text = _protect(text, porPattern, TokenCategory.temporal,
        englishEquivalent: (s) {
      return s
          .replaceAll(RegExp(r'\bpor\b'), 'for')
          .replaceAll(RegExp(r'\bdías?\b'), 'days')
          .replaceAll(RegExp(r'\bsemanas?\b'), 'weeks');
    });

    return text;
  }

  String _temporalToEnglish(String temporal) {
    return temporal
        .replaceAll(RegExp(r'\bhace\b', caseSensitive: false), 'ago')
        .replaceAll(RegExp(r'\bdesde\s+hace\b', caseSensitive: false), 'for')
        .replaceAll(RegExp(r'\bdías?\b', caseSensitive: false), 'days')
        .replaceAll(RegExp(r'\bsemanas?\b', caseSensitive: false), 'weeks')
        .replaceAll(RegExp(r'\bmeses?\b', caseSensitive: false), 'months')
        .replaceAll(RegExp(r'\baños?\b', caseSensitive: false), 'years')
        .replaceAll(RegExp(r'\bhoras?\b', caseSensitive: false), 'hours');
  }

  /// Protect negation verbs: "niega", "sin", "no presenta".
  ///
  /// CRITICAL: Negation must be preserved exactly.
  /// "niega dolor" = "denies pain" ≠ "no pain"
  String _protectNegations(String text) {
    final negationPatterns = {
      r'\bniega\b': 'denies',
      r'\bniego\b': 'I deny',
      r'\bsin\b': 'without',
      r'\bno presenta\b': 'does not present',
      r'\bno refiere\b': 'does not report',
      r'\bausencia de\b': 'absence of',
      r'\bnega\b': 'denies', // Common misspelling
    };

    for (final entry in negationPatterns.entries) {
      text = _protect(
        text,
        RegExp(entry.key, caseSensitive: false),
        TokenCategory.negation,
        englishEquivalent: (_) => entry.value,
      );
    }

    return text;
  }

  /// Protect laterality: "derecho", "izquierdo", "bilateral".
  ///
  /// CRITICAL: Laterality swap is a never-event in surgery.
  String _protectLaterality(String text) {
    final lateralityPatterns = {
      r'\bderecho\b': 'right',
      r'\bderecha\b': 'right',
      r'\bizquierdo\b': 'left',
      r'\bizquierda\b': 'left',
      r'\bbilateral\b': 'bilateral',
      r'\bambos\b': 'both',
      r'\bambas\b': 'both',
    };

    for (final entry in lateralityPatterns.entries) {
      text = _protect(
        text,
        RegExp(entry.key, caseSensitive: false),
        TokenCategory.laterality,
        englishEquivalent: (_) => entry.value,
      );
    }

    return text;
  }

  /// Protect ambiguous abbreviations that depend on specialty.
  ///
  /// OD/OI: In ENT = right/left ear, in OPHTH = right/left eye.
  /// Without context, these are protected as literals.
  String _protectAmbiguousAbbreviations(String text) {
    // OD and OI patterns (word boundaries)
    final odPattern = RegExp(r'\bOD\b');
    final oiPattern = RegExp(r'\bOI\b');

    // Determine English equivalent based on context
    String? odEquivalent;
    String? oiEquivalent;

    if (_context?.specialty == ClinicalSpecialty.ent) {
      odEquivalent = 'right ear';
      oiEquivalent = 'left ear';
    } else if (_context?.specialty == ClinicalSpecialty.ophthalmology) {
      odEquivalent = 'right eye';
      oiEquivalent = 'left eye';
    }
    // If general/null, leave englishEquivalent as null → will be preserved literally

    text = _protect(
      text,
      odPattern,
      TokenCategory.ambiguousAbbreviation,
      englishEquivalent: odEquivalent != null ? (_) => odEquivalent! : null,
    );

    text = _protect(
      text,
      oiPattern,
      TokenCategory.ambiguousAbbreviation,
      englishEquivalent: oiEquivalent != null ? (_) => oiEquivalent! : null,
    );

    return text;
  }
}

/// Result of preprocessing clinical text.
class PreprocessResult {
  const PreprocessResult({
    required this.protectedText,
    required this.protectedTokens,
  });

  /// Text with clinical markers replaced by placeholders.
  final String protectedText;

  /// List of protected tokens with their placeholders.
  final List<ProtectedToken> protectedTokens;

  /// Number of protected tokens.
  int get tokenCount => protectedTokens.length;
}
