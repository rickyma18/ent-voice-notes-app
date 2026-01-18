// packages/docsoft_scribe_runtime/lib/src/translation/clinical_translation_postprocessor.dart
//
// ÉPICA 2: Postprocessor that restores placeholders and validates integrity.
//
// CRITICAL DESIGN:
// - Restores ALL placeholders with translated equivalents
// - FAILS if any placeholder is missing or was modified
// - Validates deterministically: no semantic similarity, only exact checks

import 'package:docsoft_scribe_core/src/translation/translation.dart';
import 'clinical_translation_preprocessor.dart';

/// Postprocessor that restores placeholders and validates translation integrity.
class ClinicalTranslationPostprocessor {
  const ClinicalTranslationPostprocessor();

  /// Restores placeholders in translated text and validates integrity.
  ///
  /// [translatedText] - Text from translation API with placeholders intact.
  /// [protectedTokens] - Tokens from preprocessing.
  /// [direction] - Translation direction for selecting equivalents.
  /// [strictValidation] - If true, throws on any drift.
  ///
  /// Returns [PostprocessResult] or throws [TranslationDriftException].
  PostprocessResult process({
    required String translatedText,
    required List<ProtectedToken> protectedTokens,
    required TranslationDirection direction,
    bool strictValidation = true,
  }) {
    final warnings = <TranslationWarning>[];
    final missingPlaceholders = <String>[];
    final alteredTokens = <AlteredToken>[];

    var result = translatedText;

    // Validate and restore each placeholder
    for (final token in protectedTokens) {
      if (!result.contains(token.placeholder)) {
        // CRITICAL: Placeholder was lost or modified
        missingPlaceholders.add(token.placeholder);
        continue;
      }

      // Determine replacement value
      final replacement = _getReplacementValue(token, direction);
      result = result.replaceAll(token.placeholder, replacement);
    }

    // Check for any unreplaced placeholders (edge case: API introduced new ones)
    final remainingPlaceholders =
        RegExp(r'\[\[CLN_\d{4}\]\]').allMatches(result).toList();
    for (final match in remainingPlaceholders) {
      warnings.add(TranslationWarning(
        code: 'UNEXPECTED_PLACEHOLDER',
        message: 'Unexpected placeholder in output: ${match.group(0)}',
        translatedToken: match.group(0),
      ));
    }

    // Determine quality based on issues found
    if (missingPlaceholders.isNotEmpty) {
      final driftType = _determineDriftType(protectedTokens
          .where((t) => missingPlaceholders.contains(t.placeholder))
          .toList());

      if (strictValidation) {
        throw TranslationDriftException(
          message: 'Clinical markers lost in translation',
          driftType: driftType,
          originalText: null,
          translatedText: translatedText,
          missingPlaceholders: missingPlaceholders,
          alteredTokens: alteredTokens,
        );
      }

      return PostprocessResult(
        restoredText: result,
        quality: TranslationQuality.failed,
        warnings: warnings,
        missingPlaceholders: missingPlaceholders,
        alteredTokens: alteredTokens,
      );
    }

    // Passed validation
    final quality = warnings.isEmpty
        ? TranslationQuality.verified
        : TranslationQuality.warning;

    return PostprocessResult(
      restoredText: result,
      quality: quality,
      warnings: warnings,
      missingPlaceholders: [],
      alteredTokens: [],
    );
  }

  /// Get the replacement value for a token based on direction.
  String _getReplacementValue(
    ProtectedToken token,
    TranslationDirection direction,
  ) {
    if (direction == TranslationDirection.estoEN) {
      // Use English equivalent if available, otherwise original
      return token.englishEquivalent ?? token.original;
    } else {
      // EN→ES: always use original Spanish
      return token.original;
    }
  }

  /// Determine the type of drift based on affected tokens.
  DriftType _determineDriftType(List<ProtectedToken> affectedTokens) {
    if (affectedTokens.isEmpty) return DriftType.missingPlaceholder;

    final categories = affectedTokens.map((t) => t.category).toSet();

    if (categories.length > 1) return DriftType.multipleDrift;

    switch (categories.first) {
      case TokenCategory.negation:
        return DriftType.negationLost;
      case TokenCategory.laterality:
        return DriftType.lateralityDrift;
      case TokenCategory.dosage:
        return DriftType.dosageDrift;
      case TokenCategory.frequency:
        return DriftType.frequencyDrift;
      case TokenCategory.temporal:
        return DriftType.temporalDrift;
      case TokenCategory.ambiguousAbbreviation:
        return DriftType.missingPlaceholder;
    }
  }

  /// Validates that round-trip translation preserves clinical markers.
  ///
  /// This is DETERMINISTIC validation, not semantic similarity.
  /// Checks:
  /// - All numbers preserved exactly
  /// - Laterality preserved (left=left, right=right)
  /// - Negation verbs preserved
  RoundTripValidationResult validateRoundTrip({
    required String original,
    required String backTranslated,
    required List<ProtectedToken> originalTokens,
  }) {
    final issues = <String>[];

    // Check 1: All numbers match
    final originalNumbers = _extractNumbers(original);
    final backNumbers = _extractNumbers(backTranslated);
    if (!_setsEqual(originalNumbers, backNumbers)) {
      issues
          .add('Number mismatch: original=$originalNumbers, back=$backNumbers');
    }

    // Check 2: Laterality preserved
    final originalLaterality = _extractLaterality(original);
    final backLaterality = _extractLaterality(backTranslated);
    if (originalLaterality != null && originalLaterality != backLaterality) {
      issues.add(
          'Laterality drift: original=$originalLaterality, back=$backLaterality');
    }

    // Check 3: Negation count matches
    final originalNegCount = _countNegations(original);
    final backNegCount = _countNegations(backTranslated);
    if (originalNegCount != backNegCount) {
      issues.add(
          'Negation count mismatch: original=$originalNegCount, back=$backNegCount');
    }

    if (issues.isNotEmpty) {
      return RoundTripValidationResult.failed(issues);
    }

    return RoundTripValidationResult.passed();
  }

  Set<String> _extractNumbers(String text) {
    return RegExp(r'\d+(?:[.,]\d+)?')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toSet();
  }

  String? _extractLaterality(String text) {
    final normalized = text.toLowerCase();
    if (normalized.contains('derech') || normalized.contains('right')) {
      return 'right';
    }
    if (normalized.contains('izquierd') || normalized.contains('left')) {
      return 'left';
    }
    if (normalized.contains('bilateral') || normalized.contains('both')) {
      return 'bilateral';
    }
    return null;
  }

  int _countNegations(String text) {
    final normalized = text.toLowerCase();
    final negPatterns = [
      'niega',
      'sin',
      'no presenta',
      'ausencia',
      'denies',
      'without',
      'does not',
      'absence',
    ];
    return negPatterns
        .map((p) =>
            RegExp(p, caseSensitive: false).allMatches(normalized).length)
        .reduce((a, b) => a + b);
  }

  bool _setsEqual<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.difference(b).isEmpty;
  }
}

/// Result of postprocessing.
class PostprocessResult {
  const PostprocessResult({
    required this.restoredText,
    required this.quality,
    this.warnings = const [],
    this.missingPlaceholders = const [],
    this.alteredTokens = const [],
  });

  final String restoredText;
  final TranslationQuality quality;
  final List<TranslationWarning> warnings;
  final List<String> missingPlaceholders;
  final List<AlteredToken> alteredTokens;
}

/// Result of round-trip validation.
class RoundTripValidationResult {
  const RoundTripValidationResult._({
    required this.passed,
    this.issues = const [],
  });

  final bool passed;
  final List<String> issues;

  factory RoundTripValidationResult.passed() =>
      const RoundTripValidationResult._(passed: true);

  factory RoundTripValidationResult.failed(List<String> issues) =>
      RoundTripValidationResult._(passed: false, issues: issues);
}
