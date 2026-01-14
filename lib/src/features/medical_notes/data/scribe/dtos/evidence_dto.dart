import '../../../domain/scribe/entities/evidence.dart';

/// DTO for evidence with JSON serialization.
/// Maps to/from the domain Evidence entity.
class EvidenceDTO {
  const EvidenceDTO({
    required this.quote,
    required this.speaker,
    this.startMs,
    this.endMs,
  });

  factory EvidenceDTO.fromJson(Map<String, dynamic> json) {
    return EvidenceDTO(
      quote: json['quote'] as String? ?? '',
      speaker: json['speaker'] as String? ?? 'unknown',
      startMs: _parseIntOrNull(json['startMs'] ?? json['start_ms']),
      endMs: _parseIntOrNull(json['endMs'] ?? json['end_ms']),
    );
  }

  /// Creates DTO from domain Evidence entity.
  factory EvidenceDTO.fromDomain(Evidence evidence) {
    return EvidenceDTO(
      quote: evidence.quote,
      speaker: evidence.speaker,
      startMs: evidence.startMs,
      endMs: evidence.endMs,
    );
  }

  final String quote;
  final String speaker;
  final int? startMs;
  final int? endMs;

  Map<String, dynamic> toJson() {
    return {
      'quote': quote,
      'speaker': speaker,
      if (startMs != null) 'startMs': startMs,
      if (endMs != null) 'endMs': endMs,
    };
  }

  /// Converts this DTO to domain Evidence entity.
  Evidence toDomain() {
    return Evidence(
      quote: quote,
      speaker: speaker,
      startMs: startMs,
      endMs: endMs,
    );
  }

  static int? _parseIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Parses a list of evidence from JSON array.
  static List<EvidenceDTO> listFromJson(dynamic json) {
    if (json == null) return [];
    if (json is! List) return [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(EvidenceDTO.fromJson)
        .toList();
  }

  /// Converts list of DTOs to JSON array.
  static List<Map<String, dynamic>> listToJson(List<EvidenceDTO> list) {
    return list.map((e) => e.toJson()).toList();
  }
}
