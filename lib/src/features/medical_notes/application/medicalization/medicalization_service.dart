// lib/src/features/medical_notes/application/medicalization/medicalization_service.dart

import '../../../../core/logger/log.dart';
import 'medicalization_glossary.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MEDICALIZATION SERVICE INTERFACE
// ═══════════════════════════════════════════════════════════════════════════

/// Service interface for medicalization operations.
///
/// The medicalization service transforms colloquial patient language into
/// formal clinical terminology BEFORE sending to LLM.
///
/// Pipeline: Raw Transcript → LocalMedicalizationService → Medicalized Text → LLM
abstract class MedicalizationService {
  /// Medicalize the raw transcript text.
  ///
  /// Returns the medicalized text with spans for traceability.
  Future<MedicalizationOutput> medicalize(String rawText);

  /// Get statistics about loaded mappings (for logging).
  Future<MedicalizationStats> getStats();
}

/// Output of the medicalization process.
class MedicalizationOutput {
  const MedicalizationOutput({
    required this.originalText,
    required this.medicalizedText,
    required this.appliedMappings,
    required this.spans,
    required this.negationsPreserved,
    this.negatedFindings = const [],
  });

  /// The original unmodified text.
  final String originalText;

  /// The transformed text with clinical terminology.
  final String medicalizedText;

  /// List of mappings that were applied.
  final List<AppliedMapping> appliedMappings;

  /// Spans linking medicalized terms back to original text.
  final List<TextSpan> spans;

  /// Count of negations that were preserved (mappings skipped).
  final int negationsPreserved;

  /// List of clinical findings that were explicitly NEGATED in the text.
  /// Example: "no fiebre" -> ['fiebre'], "niega tos y mocos" -> ['tos', 'mocos']
  /// This captures negations even when there's no mapping for the term.
  final List<String> negatedFindings;

  /// Returns true if any transformations were applied or negations preserved.
  /// Negations preserved count as "changes" because they represent intentional
  /// skipping of mappings due to negation context.
  bool get hasChanges => appliedMappings.isNotEmpty || negationsPreserved > 0;

  /// Returns true if any negations were detected (with or without mappings).
  bool get hasNegations => negationsPreserved > 0 || negatedFindings.isNotEmpty;
}

/// Represents a single applied mapping.
class AppliedMapping {
  const AppliedMapping({
    required this.original,
    required this.clinical,
    required this.originalStart,
    required this.originalEnd,
    this.isNegated = false,
  });

  final String original;
  final String clinical;
  final int originalStart;
  final int originalEnd;
  final bool isNegated;
}

/// Represents a span in the text for traceability.
class TextSpan {
  const TextSpan({
    required this.start,
    required this.end,
    required this.originalText,
    required this.medicalizedText,
    this.type = SpanType.term,
  });

  final int start;
  final int end;
  final String originalText;
  final String medicalizedText;
  final SpanType type;
}

enum SpanType { term, negation, uncertainty }

/// Statistics about the medicalization process.
class MedicalizationStats {
  const MedicalizationStats({
    required this.mappingsLoaded,
    required this.mappingsApplied,
    required this.negationsPreserved,
  });

  final int mappingsLoaded;
  final int mappingsApplied;
  final int negationsPreserved;
}

// ═══════════════════════════════════════════════════════════════════════════
// LOCAL DETERMINISTIC IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════

/// Local, deterministic medicalization service.
///
/// Processes text BEFORE sending to LLM using:
/// - Dictionary-based term matching (longest match first)
/// - Negation detection and preservation
/// - Span tracking for traceability
///
/// ## IMPORTANT: Non-Cascading Matching Strategy
///
/// This implementation uses a **non-cascading** matching strategy:
/// - Pattern matching is performed against the ORIGINAL text (never the result)
/// - Replacements are applied to the RESULT string with offset adjustments
///
/// **Why non-cascading?**
/// 1. **Avoids inference chains**: If "dolor de cabeza" → "cefalea" and
///    "cefalea intensa" → "cefalea severa", cascading could create "cefalea severa"
///    from "dolor de cabeza intenso" which is an INFERENCE, not a direct mapping.
/// 2. **Predictable behavior**: Each term is matched exactly once against original.
/// 3. **Clinical safety**: We only transform what the patient explicitly said,
///    not derived terms from previous transformations.
/// 4. **Auditability**: Every transformation maps 1:1 to original text position.
///
/// NO LLM calls - purely local text transformation.
class LocalMedicalizationService implements MedicalizationService {
  /// Creates a LocalMedicalizationService.
  ///
  /// [glossary] - Optional custom glossary. If not provided, uses singleton.
  /// The singleton requires [MedicalizationGlossary.defaultLoader] to be set.
  LocalMedicalizationService({MedicalizationGlossary? glossary})
    : _glossary = glossary ?? MedicalizationGlossary.singleton();

  final MedicalizationGlossary _glossary;

  /// Cached mappings sorted by length (longest first for greedy matching).
  List<_SortedMapping>? _sortedMappings;

  // ─────────────────────────────────────────────────────────────────────────
  // NEGATION DETECTION - Clause-based with adversative handling
  // ─────────────────────────────────────────────────────────────────────────

  /// Negation trigger words.
  static final RegExp _negationTriggers = RegExp(
    r'\b(no|niega|sin|nunca|jamás|tampoco|ni|ausencia de|descarta|negative|ningún|ninguna)\b',
    caseSensitive: false,
  );

  /// Clause terminators: punctuation that ends a negation scope.
  static final RegExp _clauseTerminators = RegExp(r'[.;:\n]');

  /// Adversative conjunctions that break negation scope.
  static final RegExp _adversatives = RegExp(
    r'\b(pero|sin embargo|aunque|no obstante|excepto|salvo|menos)\b',
    caseSensitive: false,
  );

  /// Maximum characters for negation window (safety limit).
  static const int _maxNegationChars = 90;

  /// List connectors that extend negation scope (for "niega fiebre, tos y disnea").
  static final RegExp _listConnectors = RegExp(r'[,]|\b(y|e|ni|o|u)\b');

  @override
  Future<MedicalizationOutput> medicalize(String rawText) async {
    if (rawText.trim().isEmpty) {
      return MedicalizationOutput(
        originalText: rawText,
        medicalizedText: rawText,
        appliedMappings: [],
        spans: [],
        negationsPreserved: 0,
        negatedFindings: [],
      );
    }

    // Load and sort mappings (cached)
    await _ensureMappingsLoaded();

    // Step 1: Detect negation positions with improved clause-based detection
    final negationRanges = _detectNegationRanges(rawText);

    // Step 2: Extract negated clinical findings (independent of mappings)
    final negatedFindings = _extractNegatedFindings(rawText, negationRanges);

    // Step 3: Apply mappings with offset tracking (NON-CASCADING)
    final result = _applyMappings(rawText, negationRanges);

    Log.info(
      '[LocalMedicalization] Applied ${result.appliedMappings.length} mappings, '
      'preserved ${result.negationsPreserved} negations, '
      'detected ${negatedFindings.length} negated findings',
    );

    // Return result with extracted negatedFindings
    return MedicalizationOutput(
      originalText: result.originalText,
      medicalizedText: result.medicalizedText,
      appliedMappings: result.appliedMappings,
      spans: result.spans,
      negationsPreserved: result.negationsPreserved,
      negatedFindings: negatedFindings,
    );
  }

  @override
  Future<MedicalizationStats> getStats() async {
    await _ensureMappingsLoaded();

    return MedicalizationStats(
      mappingsLoaded: _sortedMappings?.length ?? 0,
      mappingsApplied: 0,
      negationsPreserved: 0,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIORITY TIER CONSTANTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Priority for clinical terms (symptoms, symptoms_orl, antecedentes, habits).
  /// These are specific medical mappings and should NEVER be blocked.
  static const int _priorityClinical = 300;

  /// Priority for specific phrases (reserved for future use).
  /// Compound expressions that are more specific than voice transforms.
  static const int _priorityPhrases = 200;

  /// Priority for voice transforms (me duele → refiere dolor en).
  /// Generic first-to-third person conversions, lowest priority.
  static const int _priorityVoiceTransforms = 100;

  /// Maps category names to priority values.
  static int _getCategoryPriority(String category) {
    switch (category) {
      case 'symptoms':
      case 'symptoms_orl':
      case 'antecedentes':
      case 'habits':
        return _priorityClinical;
      case 'phrases':
        return _priorityPhrases;
      case 'voice_transforms':
        return _priorityVoiceTransforms;
      default:
        // Unknown categories get mid-priority
        return _priorityPhrases;
    }
  }

  /// Ensures mappings are loaded with priority assignment.
  ///
  /// Priority is assigned by category:
  /// - Clinical terms (symptoms, etc.): 300 (highest)
  /// - Phrases: 200 (medium)
  /// - Voice transforms: 100 (lowest)
  Future<void> _ensureMappingsLoaded() async {
    if (_sortedMappings != null) return;

    // Use full mappings to get category information
    final fullMappings = await _glossary.getFullMappings();

    _sortedMappings = fullMappings.entries
        .map(
          (e) => _SortedMapping(
            colloquial: e.key,
            clinical: e.value.clinical,
            pattern: _buildWordBoundaryPattern(e.key),
            priority: _getCategoryPriority(e.value.category),
            category: e.value.category,
          ),
        )
        .toList();

    // Pre-sort by length descending (will be re-sorted during matching)
    _sortedMappings!.sort(
      (a, b) => b.colloquial.length.compareTo(a.colloquial.length),
    );

    Log.info(
      '[LocalMedicalization] Loaded ${_sortedMappings!.length} mappings '
      '(clinical: ${_sortedMappings!.where((m) => m.priority == _priorityClinical).length}, '
      'voice_transforms: ${_sortedMappings!.where((m) => m.priority == _priorityVoiceTransforms).length})',
    );
  }

  /// Builds a regex pattern for word-boundary matching.
  RegExp _buildWordBoundaryPattern(String term) {
    final escaped = RegExp.escape(term);
    // Spanish word boundaries including accented chars
    const boundary = r'(?<![a-záéíóúüñA-ZÁÉÍÓÚÜÑ])';
    const endBoundary = r'(?![a-záéíóúüñA-ZÁÉÍÓÚÜÑ])';
    return RegExp('$boundary($escaped)$endBoundary', caseSensitive: false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IMPROVED NEGATION DETECTION
  // ─────────────────────────────────────────────────────────────────────────

  /// Detects ranges where negations apply using clause-based detection.
  ///
  /// Handles:
  /// - "no tengo dolor" (simple negation)
  /// - "niega fiebre, tos y disnea" (list with connectors)
  /// - "no tengo fiebre pero sí dolor" (adversative breaks scope)
  /// - "sin dolor de cabeza. Sí presenta..." (punctuation breaks scope)
  List<_NegationRange> _detectNegationRanges(String text) {
    final ranges = <_NegationRange>[];

    for (final match in _negationTriggers.allMatches(text)) {
      final negationEnd = match.end;
      final afterNegation = text.substring(negationEnd);

      // Find the end of this negation's scope
      int windowEnd = negationEnd;

      // Look for clause terminators (., ;, :, \n)
      final terminatorMatch = _clauseTerminators.firstMatch(afterNegation);
      final terminatorPos = terminatorMatch?.start ?? afterNegation.length;

      // Look for adversative conjunctions (pero, sin embargo, etc.)
      final adversativeMatch = _adversatives.firstMatch(afterNegation);
      final adversativePos = adversativeMatch?.start ?? afterNegation.length;

      // The scope ends at whichever comes first: terminator, adversative, or max chars
      final scopeEnd = [
        terminatorPos,
        adversativePos,
        _maxNegationChars,
      ].reduce((a, b) => a < b ? a : b);

      windowEnd = negationEnd + scopeEnd;

      // Extend scope if we're in a list pattern (commas, y, ni, o)
      // Check if the potential scope contains list connectors
      final scopeText = afterNegation.substring(
        0,
        scopeEnd.clamp(0, afterNegation.length),
      );
      if (_listConnectors.hasMatch(scopeText)) {
        // For lists like "niega fiebre, tos y disnea", extend to end of list
        // Find where the list pattern ends (first non-list word after last connector)
        final listExtension = _findListEnd(afterNegation, scopeEnd);
        windowEnd = negationEnd + listExtension;
      }

      ranges.add(
        _NegationRange(
          negationStart: match.start,
          negationEnd: negationEnd,
          windowEnd: windowEnd.clamp(negationEnd, text.length),
          negationWord: match.group(0) ?? '',
        ),
      );
    }

    return ranges;
  }

  /// Finds the end of a list pattern for extended negation scope.
  ///
  /// For "fiebre, tos y disnea, pero..." returns position after "disnea".
  int _findListEnd(String text, int initialScopeEnd) {
    // Start from initial scope and look for list continuation
    var endPos = initialScopeEnd;

    // Pattern: word(,|\s+y\s+|\s+ni\s+|\s+o\s+)word...
    // Match list patterns like "fiebre, tos y disnea"
    final listPattern = RegExp(
      r'^[\w\sáéíóúüñ,]+(?:\s*(?:y|e|ni|o|u)\s*[\wáéíóúüñ]+)*',
      caseSensitive: false,
    );
    final listMatch = listPattern.firstMatch(text);

    if (listMatch != null) {
      endPos = listMatch.end.clamp(0, _maxNegationChars);
    }

    return endPos;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NEGATED FINDINGS EXTRACTION (Independent of mappings)
  // ─────────────────────────────────────────────────────────────────────────

  /// Common clinical symptom terms that we want to detect when negated.
  /// These are NOT mappings - they're terms we look for after negation words.
  static final Set<String> _commonClinicalTerms = {
    // General symptoms
    'fiebre',
    'tos',
    'dolor',
    'cefalea',
    'mareo',
    'náuseas',
    'vómito',
    'vómitos',
    'diarrea', 'estreñimiento', 'fatiga', 'cansancio', 'debilidad',
    // ENT symptoms
    'mocos', 'moco', 'rinorrea', 'congestión', 'estornudos', 'picazón',
    'odinofagia', 'disfagia', 'otalgia', 'otorrea', 'disfonía', 'ronquera',
    // Allergies patterns
    'alérgico', 'alérgica', 'alergias', 'alergia',
    // Medications
    'medicamentos', 'medicinas', 'pastillas', 'tratamiento',
    // Other common
    'sangrado', 'herida', 'lesión', 'inflamación', 'hinchazón',
  };

  /// Pattern to extract negated terms in Spanish.
  /// Matches: "no [tengo|he tenido|tiene|presenta] TERM"
  /// or "niega TERM" / "sin TERM" / "tampoco TERM"
  static final RegExp _negatedTermPattern = RegExp(
    r'\b(?:no(?:\s+(?:tengo|tiene|presenta|he\s+tenido|ha\s+tenido|soy|es))?\s+|niega\s+|sin\s+|tampoco\s+|ni\s+)([a-záéíóúüñ]+(?:\s+(?:de\s+)?[a-záéíóúüñ]+)?)',
    caseSensitive: false,
  );

  /// Extracts clinical terms that are explicitly negated in the text.
  ///
  /// Returns a list of unique negated clinical terms found.
  /// Example: "no he tenido fiebre, no tos, sin mocos"
  ///          -> ['fiebre', 'tos', 'mocos']
  List<String> _extractNegatedFindings(
    String text,
    List<_NegationRange> negationRanges,
  ) {
    final findings = <String>{};

    // For each negation range, extract the words that follow
    for (final range in negationRanges) {
      // Get the text in the negation window
      final windowText = text.substring(
        range.negationEnd,
        range.windowEnd.clamp(range.negationEnd, text.length),
      );

      // Split by common separators and extract words
      final words = windowText
          .split(RegExp(r'[,\s]+'))
          .map((w) => w.toLowerCase().trim())
          .where((w) => w.isNotEmpty && w.length > 2);

      for (final word in words) {
        // Check if it's a known clinical term or looks like one
        if (_commonClinicalTerms.contains(word)) {
          findings.add(word);
        }
        // Also catch patterns like "alérgico a nada" -> "alérgico"
        for (final term in _commonClinicalTerms) {
          if (word.contains(term)) {
            findings.add(term);
            break;
          }
        }
      }
    }

    // Also use regex pattern for more structured detection
    for (final match in _negatedTermPattern.allMatches(text.toLowerCase())) {
      final captured = match.group(1)?.trim();
      if (captured != null && captured.isNotEmpty) {
        // Check if the captured term is or contains a clinical term
        for (final term in _commonClinicalTerms) {
          if (captured.contains(term) || term.contains(captured)) {
            findings.add(term);
            break;
          }
        }
        // Also add the raw captured term if it's reasonably clinical-looking
        if (captured.length >= 3 && !_isStopWord(captured)) {
          findings.add(captured);
        }
      }
    }

    return findings.toList();
  }

  /// Checks if a word is a common stop word (not clinically meaningful).
  bool _isStopWord(String word) {
    const stopWords = {
      'que',
      'de',
      'la',
      'el',
      'en',
      'es',
      'un',
      'una',
      'los',
      'las',
      'por',
      'con',
      'para',
      'del',
      'al',
      'se',
      'lo',
      'como',
      'más',
      'pero',
      'sus',
      'le',
      'ya',
      'son',
      'este',
      'entre',
      'cuando',
      'muy',
      'sin',
      'sobre',
      'también',
      'me',
      'hasta',
      'hay',
      'donde',
      'quien',
      'desde',
      'todo',
      'nos',
      'durante',
      'todos',
      'uno',
      'les',
      'ni',
      'contra',
      'otros',
      'ese',
      'eso',
      'ante',
      'ellos',
      'sido',
      'tengo',
      'tiene',
      'nada',
      'algo',
    };
    return stopWords.contains(word.toLowerCase());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NON-CASCADING MATCHER WITH PRIORITY-AWARE OVERLAP RESOLUTION
  // ─────────────────────────────────────────────────────────────────────────

  /// Applies mappings to text with offset tracking and priority-based selection.
  ///
  /// ## Non-Cascading Strategy
  /// - ALL pattern matches are found against the ORIGINAL text
  /// - Replacements are then applied to the RESULT with offset adjustments
  /// - This prevents inference chains where a replacement could trigger
  ///   additional matches that weren't in the original text
  ///
  /// ## Priority Selection Strategy
  /// When overlaps occur between candidates:
  /// 1. Collect ALL candidates (matches against ORIGINAL text)
  /// 2. Sort by: priority DESC, length DESC, start ASC
  /// 3. Select non-overlapping candidates (higher priority wins)
  /// 4. Re-sort selected by position for offset calculation
  /// 5. Apply replacements to RESULT with offset tracking
  ///
  /// Example:
  /// - Input: "Me duele la cabeza desde hace 3 días"
  /// - "me duele" (P100) matches [0, 8]
  /// - "dolor de cabeza" would need to match, but we don't have that exact phrase
  /// - If we had "la cabeza" → "cefalea" (P300), it would NOT be blocked by "me duele"
  ///
  /// The key insight: clinical terms (P300) are selected FIRST due to sorting,
  /// so voice_transforms (P100) can only fill gaps where no clinical term matched.
  MedicalizationOutput _applyMappings(
    String text,
    List<_NegationRange> negationRanges,
  ) {
    final appliedMappings = <AppliedMapping>[];
    final spans = <TextSpan>[];
    var negationsPreserved = 0;

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 1: Collect ALL matches (against ORIGINAL text)
    // ─────────────────────────────────────────────────────────────────────────
    final allCandidates = <_PendingMatch>[];

    for (final mapping in _sortedMappings!) {
      for (final match in mapping.pattern.allMatches(text)) {
        allCandidates.add(
          _PendingMatch(
            mapping: mapping,
            start: match.start,
            end: match.end,
            matchedText: text.substring(match.start, match.end),
          ),
        );
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 2: Sort candidates by priority (desc), length (desc), start (asc)
    // ─────────────────────────────────────────────────────────────────────────
    // This ensures:
    // - Higher priority mappings are considered first
    // - Among equal priority, longer (more specific) matches win
    // - Stable ordering by position for deterministic results
    allCandidates.sort((a, b) {
      // Priority descending (300 before 100)
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;

      // Length descending (longer matches first)
      final lengthCompare = b.length.compareTo(a.length);
      if (lengthCompare != 0) return lengthCompare;

      // Start ascending (earlier position first for stability)
      return a.start.compareTo(b.start);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 3: Select non-overlapping candidates (greedy by priority order)
    // ─────────────────────────────────────────────────────────────────────────
    final selectedCandidates = <_PendingMatch>[];
    final occupiedRanges = <_Range>[];

    for (final candidate in allCandidates) {
      final start = candidate.start;
      final end = candidate.end;

      // Check if this candidate overlaps with any already-selected range
      if (!_overlapsAny(start, end, occupiedRanges)) {
        selectedCandidates.add(candidate);
        occupiedRanges.add(_Range(start, end));
      }
      // If it overlaps, skip it (a higher-priority candidate already claimed that range)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 4: Re-sort selected candidates by start position for offset tracking
    // ─────────────────────────────────────────────────────────────────────────
    selectedCandidates.sort((a, b) => a.start.compareTo(b.start));

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 5: Apply replacements to RESULT with offset tracking
    // ─────────────────────────────────────────────────────────────────────────
    var result = text;
    var offset = 0; // Cumulative offset from replacements

    for (final candidate in selectedCandidates) {
      final originalStart = candidate.start;
      final originalEnd = candidate.end;

      // Check if this match is within a negation window
      final isNegated = _isWithinNegation(originalStart, negationRanges);

      // SKIP mapping if within negation scope - preserve original text
      if (isNegated) {
        negationsPreserved++;
        // DO NOT apply replacement - skip this candidate entirely
        continue;
      }

      // Calculate positions in the result string (accounting for previous replacements)
      final adjustedStart = originalStart + offset;
      final adjustedEnd = originalEnd + offset;

      final replacement = candidate.mapping.clinical;

      // Apply replacement to RESULT (not to original)
      result =
          result.substring(0, adjustedStart) +
          replacement +
          result.substring(adjustedEnd);

      // Update offset for future replacements
      offset += replacement.length - (originalEnd - originalStart);

      // Record the mapping
      appliedMappings.add(
        AppliedMapping(
          original: candidate.matchedText,
          clinical: replacement,
          originalStart: originalStart,
          originalEnd: originalEnd,
          isNegated:
              false, // Only applied mappings reach here, so never negated
        ),
      );

      // Record the span
      spans.add(
        TextSpan(
          start: adjustedStart,
          end: adjustedStart + replacement.length,
          originalText: candidate.matchedText,
          medicalizedText: replacement,
          type: SpanType.term,
        ),
      );
    }

    return MedicalizationOutput(
      originalText: text,
      medicalizedText: result,
      appliedMappings: appliedMappings,
      spans: spans,
      negationsPreserved: negationsPreserved,
    );
  }

  /// Checks if a position is within a negation window.
  bool _isWithinNegation(int position, List<_NegationRange> ranges) {
    for (final range in ranges) {
      if (position >= range.negationEnd && position < range.windowEnd) {
        return true;
      }
    }
    return false;
  }

  /// Checks if a range overlaps with any existing range.
  bool _overlapsAny(int start, int end, List<_Range> ranges) {
    for (final range in ranges) {
      if (start < range.end && end > range.start) {
        return true;
      }
    }
    return false;
  }

  /// Clears cached data. Useful for testing.
  void clearCache() {
    _sortedMappings = null;
    _glossary.clearCache();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INTERNAL HELPER CLASSES
// ═══════════════════════════════════════════════════════════════════════════

/// Internal mapping representation with priority for overlap resolution.
///
/// ## Priority Selection Strategy
///
/// Mappings have priority tiers to ensure clinical terminology takes precedence:
/// - Priority 300: Clinical terms (symptoms, symptoms_orl, antecedentes, habits)
///   → These represent specific medical mappings and should NEVER be blocked
/// - Priority 200: Specific phrases (future expansion for multi-word phrases)
///   → Reserved for compound expressions outside voice_transforms
/// - Priority 100: Voice transforms (me duele → refiere dolor en)
///   → Generic first-to-third person conversions, lowest priority
///
/// When overlaps occur between candidates:
/// - Higher priority ALWAYS wins, even if the lower-priority match came first
/// - At equal priority, longer matches win (more specific)
/// - At equal priority and length, earlier position wins (stable sort)
///
/// This ensures "dolor de cabeza" → "cefalea" is applied even when
/// "me duele" → "refiere dolor en" would otherwise overlap.
class _SortedMapping {
  const _SortedMapping({
    required this.colloquial,
    required this.clinical,
    required this.pattern,
    required this.priority,
    required this.category,
  });

  final String colloquial;
  final String clinical;
  final RegExp pattern;

  /// Priority tier: 300 (clinical), 200 (phrases), 100 (voice_transforms).
  final int priority;

  /// Category from glossary (symptoms, voice_transforms, etc.).
  final String category;
}

class _NegationRange {
  const _NegationRange({
    required this.negationStart,
    required this.negationEnd,
    required this.windowEnd,
    required this.negationWord,
  });

  final int negationStart;
  final int negationEnd;
  final int windowEnd;
  final String negationWord;
}

class _Range {
  const _Range(this.start, this.end);
  final int start;
  final int end;
}

class _PendingMatch {
  const _PendingMatch({
    required this.mapping,
    required this.start,
    required this.end,
    required this.matchedText,
  });

  final _SortedMapping mapping;
  final int start;
  final int end;
  final String matchedText;

  /// Length of the match (for sorting).
  int get length => end - start;

  /// Priority from the mapping (for sorting).
  int get priority => mapping.priority;
}

// ═══════════════════════════════════════════════════════════════════════════
// FACTORY
// ═══════════════════════════════════════════════════════════════════════════

/// Factory for creating medicalization services.
class MedicalizationServiceFactory {
  const MedicalizationServiceFactory._();

  /// Create the default implementation (local deterministic).
  static MedicalizationService create() {
    return LocalMedicalizationService();
  }
}
