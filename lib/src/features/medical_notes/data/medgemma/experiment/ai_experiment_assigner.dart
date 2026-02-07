// lib/src/features/medical_notes/data/medgemma/experiment/ai_experiment_assigner.dart
//
// Deterministic A/B experiment assignment for AI engine comparisons.
//
// Uses FNV-1a hash for stable, reproducible bucket assignment:
// same (userId, experimentName, seed) always yields the same variant.
//
// PHI-SAFE: Only hashes userId (opaque ID), never clinical content.

/// Deterministic A/B experiment assigner.
///
/// Assigns users to 'medgemma' or 'openai' variant based on a
/// hash of their userId + experiment name + seed.
///
/// The assignment is:
/// - **Deterministic**: same inputs always produce same variant
/// - **Uniform**: approximately `medgemmaRatio` fraction get 'medgemma'
/// - **Re-randomizable**: changing `seed` reshuffles assignments
///
/// Usage:
/// ```dart
/// final variant = AiExperimentAssigner.assign(
///   userId: doctorId,
///   experimentName: 'suggest_plan',
///   seed: MedGemmaConfig.aiExperimentSeed,
///   medgemmaRatio: MedGemmaConfig.aiExperimentRatioMedgemma,
/// );
/// // variant == 'medgemma' or 'openai'
/// ```
abstract class AiExperimentAssigner {
  AiExperimentAssigner._();

  /// Assigns a variant based on deterministic hashing.
  ///
  /// Returns `'medgemma'` or `'openai'`.
  ///
  /// - [userId]: opaque user/doctor ID (e.g. Firebase UID)
  /// - [experimentName]: experiment key (e.g. 'suggest_plan', 'extract')
  /// - [seed]: allows re-randomization without code changes (default 0)
  /// - [medgemmaRatio]: fraction assigned to medgemma (0.0–1.0, default 0.5)
  static String assign({
    required String userId,
    required String experimentName,
    int seed = 0,
    double medgemmaRatio = 0.5,
  }) {
    final key = '$userId:$experimentName:$seed';
    final hash = _fnv1a32(key);
    // Map hash to [0.0, 1.0) with 1000 buckets for granularity
    final bucket = (hash % 1000) / 1000.0;
    return bucket < medgemmaRatio ? 'medgemma' : 'openai';
  }

  /// Returns a PHI-safe description of the assignment for logging.
  ///
  /// Includes: experimentName, seed, ratio, variant, bucket.
  /// Does NOT include userId.
  static Map<String, dynamic> describeAssignment({
    required String userId,
    required String experimentName,
    int seed = 0,
    double medgemmaRatio = 0.5,
  }) {
    final key = '$userId:$experimentName:$seed';
    final hash = _fnv1a32(key);
    final bucket = (hash % 1000) / 1000.0;
    final variant = bucket < medgemmaRatio ? 'medgemma' : 'openai';

    return {
      'experiment': experimentName,
      'seed': seed,
      'ratio': medgemmaRatio,
      'bucket': bucket,
      'variant': variant,
    };
  }

  /// FNV-1a 32-bit hash.
  ///
  /// Simple, fast, well-distributed hash suitable for bucket assignment.
  /// Reference: http://www.isthe.com/chongo/tech/comp/fnv/
  static int _fnv1a32(String input) {
    const int fnvOffsetBasis = 0x811c9dc5;
    const int fnvPrime = 0x01000193;

    int hash = fnvOffsetBasis;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    // Ensure non-negative
    return hash & 0x7FFFFFFF;
  }
}
