// packages/docsoft_scribe_core/lib/src/canonical/evidence_finder.dart
//
// ÉPICA 1: Evidence Finder
// Deterministically finds evidence quotes in transcript for claims.

import 'canonical_clinical_facts.dart';

/// Finds evidence quotes in a transcript for clinical claims.
///
/// This is a deterministic substring search, no AI involved.
class EvidenceFinder {
  const EvidenceFinder();

  /// Maximum length of evidence quote.
  static const int maxQuoteLength = 120;

  /// Find evidence for chief complaint.
  CanonicalEvidence? findChiefComplaintEvidence(
    String transcript,
    CanonicalChiefComplaint? cc,
  ) {
    if (cc == null) return null;

    // Build search patterns based on the symptom
    final patterns = _buildSymptomPatterns(cc.symptom);

    for (final pattern in patterns) {
      final match = _findBestMatch(transcript, pattern);
      if (match != null) {
        return CanonicalEvidence(
          quote: _truncateQuote(match),
          speaker: 'Patient',
        );
      }
    }

    return null;
  }

  /// Find evidence for a ROS symptom.
  CanonicalEvidence? findROSEvidence(
    String transcript,
    CanonicalSymptom symptom,
    Polarity polarity,
  ) {
    // Build patterns for the symptom
    final symptomPatterns = _buildSymptomPatterns(symptom);

    // Add polarity-specific patterns
    final patterns = <String>[];
    if (polarity == Polarity.negative) {
      // Look for negation patterns
      for (final sp in symptomPatterns) {
        patterns.add('niega $sp');
        patterns.add('sin $sp');
        patterns.add('no $sp');
        patterns.add('no tiene $sp');
        patterns.add('no presenta $sp');
      }
    } else {
      patterns.addAll(symptomPatterns);
    }

    for (final pattern in patterns) {
      final match = _findBestMatch(transcript, pattern);
      if (match != null) {
        return CanonicalEvidence(
          quote: _truncateQuote(match),
          speaker: 'Patient',
        );
      }
    }

    return null;
  }

  /// Build search patterns for a symptom.
  List<String> _buildSymptomPatterns(CanonicalSymptom symptom) {
    final patterns = <String>[];

    // Add the canonical display name
    patterns.add(symptom.displayEs.toLowerCase());

    // Add laterality variants
    if (symptom.laterality != Laterality.unknown) {
      patterns.add(
        '${symptom.displayEs.toLowerCase()} ${symptom.laterality.toDisplayEs()}',
      );
    }

    // Get synonyms from dictionary
    final code = symptom.code;
    // Look up common patterns for known codes
    switch (code) {
      case 'otalgia':
        patterns.addAll([
          'dolor de oído',
          'dolor en el oído',
          'le duele el oído',
          'duele el oído',
          'dolor oído',
        ]);
        break;
      case 'otorrea':
        patterns.addAll([
          'escurrimiento',
          'secreción del oído',
          'supuración',
        ]);
        break;
      case 'fiebre':
        patterns.addAll([
          'fiebre',
          'calentura',
          'temperatura',
        ]);
        break;
      case 'odinofagia':
        patterns.addAll([
          'dolor de garganta',
          'dolor al tragar',
          'garganta',
        ]);
        break;
      case 'mareo':
        patterns.addAll([
          'mareo',
          'mareado',
          'me mareo',
        ]);
        break;
      case 'vertigo':
        patterns.addAll([
          'vértigo',
          'todo da vueltas',
          'sensación rotatoria',
        ]);
        break;
    }

    // Add laterality suffix patterns
    if (symptom.laterality == Laterality.right) {
      for (final p in List<String>.from(patterns)) {
        patterns.add('$p derecho');
        patterns.add('$p derecha');
        patterns.add('oído derecho');
      }
    } else if (symptom.laterality == Laterality.left) {
      for (final p in List<String>.from(patterns)) {
        patterns.add('$p izquierdo');
        patterns.add('$p izquierda');
        patterns.add('oído izquierdo');
      }
    }

    return patterns;
  }

  /// Find the best match for a pattern in the transcript.
  String? _findBestMatch(String transcript, String pattern) {
    final lowerTranscript = _normalize(transcript);
    final lowerPattern = _normalize(pattern);

    final index = lowerTranscript.indexOf(lowerPattern);
    if (index == -1) return null;

    // Extract a context window around the match
    final start = _findSentenceStart(transcript, index);
    final end = _findSentenceEnd(transcript, index + pattern.length);

    return transcript.substring(start, end).trim();
  }

  /// Find the start of the sentence containing the index.
  int _findSentenceStart(String text, int index) {
    // Look backwards for sentence delimiter or start of text
    int start = index;
    const delimiters = {'.', '!', '?', '\n'};
    while (start > 0 && !delimiters.contains(text[start - 1])) {
      start--;
      // Don't go too far back
      if (index - start > 50) break;
    }
    return start;
  }

  /// Find the end of the sentence containing the index.
  int _findSentenceEnd(String text, int index) {
    // Look forwards for sentence delimiter or end of text
    int end = index;
    const delimiters = {'.', '!', '?', '\n'};
    while (end < text.length && !delimiters.contains(text[end])) {
      end++;
      // Don't go too far forward
      if (end - index > 80) break;
    }
    // Include the delimiter
    if (end < text.length && delimiters.contains(text[end])) {
      end++;
    }
    return end;
  }

  /// Truncate quote to max length.
  String _truncateQuote(String quote) {
    if (quote.length <= maxQuoteLength) return quote;
    return '${quote.substring(0, maxQuoteLength - 3)}...';
  }

  /// Normalize text for matching.
  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n');
  }
}

/// Extension for enriching canonical facts with evidence.
extension CanonicalFactsEvidenceEnrichment on CanonicalClinicalFacts {
  /// Enrich this facts object with evidence from the transcript.
  CanonicalClinicalFacts enrichWithEvidence(
    String transcript,
    EvidenceFinder finder,
  ) {
    // Enrich chief complaint
    CanonicalChiefComplaint? enrichedCC;
    if (chiefComplaint != null) {
      final ccEvidence = chiefComplaint!.evidence ??
          finder.findChiefComplaintEvidence(transcript, chiefComplaint);
      if (ccEvidence != null || chiefComplaint!.evidence != null) {
        enrichedCC = CanonicalChiefComplaint(
          symptom: chiefComplaint!.symptom,
          evidence: ccEvidence ?? chiefComplaint!.evidence,
        );
      } else {
        enrichedCC = chiefComplaint;
      }
    }

    return CanonicalClinicalFacts(
      chiefComplaint: enrichedCC,
      ros: ros,
      assessment: assessment,
      hpiKeyPoints: hpiKeyPoints,
    );
  }
}
