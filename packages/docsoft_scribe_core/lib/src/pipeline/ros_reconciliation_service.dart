// packages/docsoft_scribe_core/lib/src/pipeline/ros_reconciliation_service.dart

import '../core/logger.dart';
import '../dtos/clinical_facts_dto.dart';

/// Service for reconciling ROS (Review of Systems) data with deterministic rules.
///
/// This service implements the following resolution rules:
/// 1. **Last Statement Priority**: Later explicit statements override earlier ones
/// 2. **Temporal Context ≠ Current State**: Historical negations remain in HPI only
/// 3. **No Contradictions**: A symptom cannot be in both positives AND negatives
/// 4. **Cleaned Negatives**: No duplicate or malformed negation entries
///
/// Example:
/// Input: "Al inicio no tenía mareo… pero anoche sí me mareé"
/// - ROS positives: ["mareo"] ✓ (final state)
/// - ROS negatives: [] (historical negation stays in HPI)
class ROSReconciliationService {
  const ROSReconciliationService({LogSink? logSink})
      : _logSink = logSink ?? const NoOpLogSink();

  final LogSink _logSink;

  /// Reconciles ROS data with negated findings using deterministic rules.
  ///
  /// [ros] - The original ROS section from LLM extraction
  /// [negatedFindings] - Findings detected as negated by medicalization
  /// [hpiNarrative] - The HPI narrative for temporal context detection
  ///
  /// Returns a new [ROSSection] with conflicts resolved.
  ROSSection reconcile({
    required ROSSection ros,
    required List<String> negatedFindings,
    String? hpiNarrative,
  }) {
    // Step 1: Normalize and deduplicate existing ROS data
    final cleanedPositives = _normalizeAndDedupe(ros.positives);
    final cleanedNegatives = _normalizeAndDedupe(ros.negatives);

    // Step 2: Build a set of positive symptom roots for conflict detection
    final positiveRoots = _extractSymptomRoots(cleanedPositives);

    // Step 3: Remove any negatives that conflict with positives (positive wins)
    final reconciledNegatives = _removeConflictingNegatives(
      cleanedNegatives,
      positiveRoots,
    );

    // Step 4: Add negated findings that are NOT in positives and NOT temporal
    final hpiContext = (hpiNarrative ?? '').toLowerCase();
    final finalNegatives = _addNonConflictingNegations(
      reconciledNegatives,
      negatedFindings,
      positiveRoots,
      hpiContext,
    );

    // Step 5: Clean up malformed negation entries
    final sanitizedNegatives = _sanitizeNegatives(finalNegatives);

    // Log reconciliation summary
    final addedCount = sanitizedNegatives.length - ros.negatives.length;
    final removedCount = ros.negatives.length - reconciledNegatives.length;
    if (addedCount != 0 || removedCount != 0) {
      _logSink.info(
        '[ROSReconciliation] Reconciled: '
        'positives=${cleanedPositives.length}, '
        'negatives: ${ros.negatives.length} → ${sanitizedNegatives.length} '
        '(removed=$removedCount, added=${addedCount.clamp(0, 100)})',
      );
    }

    return ROSSection(
      positives: cleanedPositives,
      negatives: sanitizedNegatives,
      evidence: ros.evidence,
    );
  }

  /// Normalizes and deduplicates a list of symptoms.
  List<String> _normalizeAndDedupe(List<String> items) {
    final seen = <String>{};
    final result = <String>[];

    for (final item in items) {
      final normalized = _normalizeSymptom(item);
      if (normalized.isNotEmpty && !seen.contains(normalized)) {
        seen.add(normalized);
        result.add(item.trim()); // Keep original casing
      }
    }

    return result;
  }

  /// Normalizes a symptom string for comparison.
  String _normalizeSymptom(String symptom) {
    return symptom.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Extracts root symptoms from a list (removes "niega", "sin", etc.).
  Set<String> _extractSymptomRoots(List<String> symptoms) {
    final roots = <String>{};

    for (final symptom in symptoms) {
      final root = _extractRoot(symptom);
      if (root.isNotEmpty) {
        roots.add(root);
      }
    }

    return roots;
  }

  /// Extracts the root symptom from a string like "niega mareo" → "mareo".
  String _extractRoot(String symptom) {
    var root = symptom.toLowerCase().trim();

    // Remove common negation prefixes
    final prefixes = [
      'niega ',
      'sin ',
      'no ',
      'no presenta ',
      'no refiere ',
      'ausencia de ',
      'descarta ',
    ];

    for (final prefix in prefixes) {
      if (root.startsWith(prefix)) {
        root = root.substring(prefix.length).trim();
        break;
      }
    }

    return root;
  }

  /// Removes negatives that conflict with positives (positive wins).
  List<String> _removeConflictingNegatives(
    List<String> negatives,
    Set<String> positiveRoots,
  ) {
    return negatives.where((negative) {
      final root = _extractRoot(negative);
      final conflicts = positiveRoots.contains(root) ||
          positiveRoots.any((pos) => _symptomsMatch(pos, root));

      if (conflicts) {
        _logSink.debug(
          '[ROSReconciliation] Removed conflicting negative: "$negative" '
          '(conflicts with positive)',
        );
      }

      return !conflicts;
    }).toList();
  }

  /// Checks if two symptom strings refer to the same condition.
  bool _symptomsMatch(String a, String b) {
    if (a == b) return true;

    // Handle common variants
    final variants = <String, Set<String>>{
      'mareo': {'vértigo', 'mareos'},
      'vértigo': {'mareo', 'mareos'},
      'tos': {'tos seca', 'tos productiva'},
      'fiebre': {'febrícula', 'hipertermia'},
      'rinorrea': {'moco', 'mocos'},
      'cefalea': {'dolor de cabeza'},
      'odinofagia': {'dolor de garganta'},
      'otalgia': {'dolor de oído'},
    };

    if (variants.containsKey(a) && variants[a]!.contains(b)) return true;
    if (variants.containsKey(b) && variants[b]!.contains(a)) return true;

    // Check for substring match (e.g., "mareo" in "mareo postural")
    if (a.contains(b) || b.contains(a)) return true;

    return false;
  }

  /// Adds negated findings that don't conflict with positives.
  ///
  /// Also filters out temporal negations that are part of historical context.
  List<String> _addNonConflictingNegations(
    List<String> currentNegatives,
    List<String> negatedFindings,
    Set<String> positiveRoots,
    String hpiContext,
  ) {
    final existingRoots = _extractSymptomRoots(currentNegatives);
    final result = [...currentNegatives];

    for (final finding in negatedFindings) {
      final normalizedFinding = finding.toLowerCase().trim();

      // Skip if already in negatives
      if (existingRoots.contains(normalizedFinding)) continue;

      // Skip if conflicts with a positive (positive wins)
      if (positiveRoots.contains(normalizedFinding) ||
          positiveRoots.any((pos) => _symptomsMatch(pos, normalizedFinding))) {
        _logSink.debug(
          '[ROSReconciliation] Skipped negation "$finding" - conflicts with positive',
        );
        continue;
      }

      // Skip if this is a temporal/historical negation
      if (_isTemporalNegation(normalizedFinding, hpiContext)) {
        _logSink.debug(
          '[ROSReconciliation] Skipped temporal negation "$finding" - historical context only',
        );
        continue;
      }

      // Add as a properly formatted negation
      result.add('niega $finding');
      existingRoots.add(normalizedFinding);
    }

    return result;
  }

  /// Detects if a negation is temporal/historical context only.
  ///
  /// Patterns that indicate temporal context:
  /// - "al inicio no tenía X"
  /// - "antes no tenía X"
  /// - "inicialmente no"
  /// - "no tenía X al principio"
  ///
  /// If the HPI contains a later affirmative statement, the negation is historical.
  bool _isTemporalNegation(String symptom, String hpiContext) {
    if (hpiContext.isEmpty) return false;

    // Temporal negation patterns
    final temporalPatterns = [
      RegExp(
        r'al inicio\s+no\s+(?:tenía|había|presentaba)\s*' +
            RegExp.escape(symptom),
      ),
      RegExp(r'antes\s+no\s+(?:tenía|había)\s*' + RegExp.escape(symptom)),
      RegExp(r'inicialmente\s+(?:sin|no)\s*' + RegExp.escape(symptom)),
      RegExp(
        r'no\s+tenía\s+' +
            RegExp.escape(symptom) +
            r'\s+al\s+(?:inicio|principio)',
      ),
      RegExp(r'previamente\s+(?:sin|no)\s*' + RegExp.escape(symptom)),
    ];

    // Affirmative override patterns (indicate current positive state)
    final affirmativePatterns = [
      RegExp(
        r'(?:pero|sin embargo|aunque|después|ahora|anoche|hoy)\s+(?:sí|ya)\s+(?:tengo|tiene|presenta|hay)\s*' +
            RegExp.escape(symptom),
      ),
      RegExp(
        r'(?:ahora|actualmente|hoy)\s+(?:sí\s+)?(?:presenta|tiene|refiere)\s*' +
            RegExp.escape(symptom),
      ),
      // Special pattern for 'mareo' symptom
      if (symptom == 'mareo') RegExp(r'sí\s+(?:me\s+)?(?:marea|mareo|mareé)'),
    ];

    // Check if there's a temporal negation pattern
    final hasTemporalNegation = temporalPatterns.any(
      (pattern) => pattern.hasMatch(hpiContext),
    );

    // Check if there's a later affirmative that overrides
    final hasAffirmativeOverride = affirmativePatterns.any(
      (pattern) => pattern.hasMatch(hpiContext),
    );

    // If we have a temporal negation AND an affirmative override, it's historical
    if (hasTemporalNegation && hasAffirmativeOverride) {
      return true;
    }

    // Also check for simple adversative pattern with symptom
    final adversativePattern = RegExp(
      r'no\s+(?:tenía|había)\s+' +
          RegExp.escape(symptom) +
          r'.*(?:pero|sin embargo|aunque).*(?:sí|ahora|después)',
      caseSensitive: false,
    );
    if (adversativePattern.hasMatch(hpiContext)) {
      return true;
    }

    return false;
  }

  /// Sanitizes negative entries to ensure proper formatting.
  ///
  /// Deduplicates by symptom ROOT, not by full string.
  /// So "niega fiebre" and "sin fiebre" are both root "fiebre" -> keep first.
  List<String> _sanitizeNegatives(List<String> negatives) {
    final result = <String>[];
    final seenRoots = <String>{};

    for (var negative in negatives) {
      // Fix double negation: "niega niega X" → "niega X"
      negative = negative.replaceAll(RegExp(r'niega\s+niega\s*'), 'niega ');

      // Normalize whitespace
      negative = negative.replaceAll(RegExp(r'\s+'), ' ').trim();

      // Skip empty or too short
      if (negative.length < 3) continue;

      // Skip if it's just a bare negation word
      if (_isBareNegation(negative)) continue;

      // Deduplicate by ROOT symptom, not full string
      // "niega fiebre" and "sin fiebre" both have root "fiebre"
      final root = _extractRoot(negative);
      if (root.isEmpty) continue;
      if (seenRoots.contains(root)) continue;
      seenRoots.add(root);

      result.add(negative);
    }

    return result;
  }

  /// Checks if a string is just a bare negation word with no symptom.
  bool _isBareNegation(String text) {
    final bare = text.toLowerCase().trim();
    const bareWords = {'niega', 'sin', 'no', 'ninguno', 'ninguna', 'nada'};
    return bareWords.contains(bare);
  }
}

/// Extension to run ROS reconciliation on ClinicalFactsDTO.
extension ClinicalFactsDTOReconciliation on ClinicalFactsDTO {
  /// Returns a new DTO with ROS reconciled using the given service.
  ClinicalFactsDTO withReconciledROS({
    required ROSReconciliationService service,
    required List<String> negatedFindings,
  }) {
    final reconciledROS = service.reconcile(
      ros: ros,
      negatedFindings: negatedFindings,
      hpiNarrative: hpi.narrative,
    );

    // Only create new DTO if ROS changed
    if (reconciledROS == ros) return this;

    return ClinicalFactsDTO(
      metadata: metadata,
      patient: patient,
      chiefComplaint: chiefComplaint,
      hpi: hpi,
      ros: reconciledROS,
      pmh: pmh,
      medications: medications,
      allergies: allergies,
      physicalExam: physicalExam,
      assessment: assessment,
      plan: plan,
      missingInfo: missingInfo,
      ambiguousInfo: ambiguousInfo,
    );
  }
}
