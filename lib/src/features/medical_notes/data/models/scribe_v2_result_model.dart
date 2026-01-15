// lib/src/features/medical_notes/data/models/scribe_v2_result_model.dart
//
// Firestore model for persisting Scribe V2 pipeline results as a subdocument.
// Stored at: medical_notes/{noteId}/scribe_v2/latest

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../application/scribe/process_encounter_usecase.dart';
import '../../domain/scribe/entities/transcript_segment.dart';
import '../../domain/scribe/entities/transcript_with_speakers.dart';
import '../scribe/dtos/clinical_facts_dto.dart';

/// Maximum size in bytes for transcript text before truncation.
/// Firestore document limit is 1MB, we use conservative limit.
const int kMaxTranscriptBytes = 50000; // ~50KB

/// Maximum characters per segment text before truncation.
const int kMaxSegmentTextChars = 2000;

/// Maximum total segments to store.
const int kMaxSegments = 200;

/// Model for persisting Scribe V2 results to Firestore subdocument.
///
/// Structure in Firestore:
/// ```
/// medical_notes/{noteId}/scribe_v2/latest
/// {
///   transcriptSegments: [...],
///   clinicalFacts: {...},
///   evidenceMap: {...},
///   composerSoap: "...",
///   metadata: {...},
///   createdAt: Timestamp,
///   updatedAt: Timestamp,
/// }
/// ```
class ScribeV2ResultModel {
  const ScribeV2ResultModel({
    required this.transcriptSegments,
    required this.clinicalFacts,
    required this.evidenceMap,
    required this.composerSoap,
    required this.metadata,
    required this.createdAt,
    this.updatedAt,
    this.truncationInfo,
  });

  /// Transcript segments with speaker and timing information.
  final List<TranscriptSegmentModel> transcriptSegments;

  /// Structured clinical facts extracted from transcript.
  final Map<String, dynamic> clinicalFacts;

  /// Mapping from fact fields to evidence (quotes + timestamps).
  final Map<String, dynamic> evidenceMap;

  /// Final composed SOAP note text.
  final String? composerSoap;

  /// Pipeline metadata (source, model, versions, etc.).
  final ScribeMetadataModel metadata;

  /// When this result was created.
  final DateTime createdAt;

  /// When this result was last updated.
  final DateTime? updatedAt;

  /// Info about any truncation applied for size limits.
  final TruncationInfoModel? truncationInfo;

  /// Creates model from MedicalScribeResult with size guards.
  factory ScribeV2ResultModel.fromScribeResult(
    MedicalScribeResult result, {
    required String source,
    String? modelProvider,
    String? modelVersion,
    String? sttBackend,
    String? diarizationBackend,
    Map<String, String>? promptVersions,
    String? appVersion,
  }) {
    final now = DateTime.now();
    TruncationInfoModel? truncationInfo;

    // Convert segments with truncation guard
    final segments = result.transcript.segments;
    List<TranscriptSegmentModel> segmentModels;
    bool segmentsTruncated = false;
    int originalSegmentCount = segments.length;

    if (segments.length > kMaxSegments) {
      segmentsTruncated = true;
      // Keep first and last segments for context
      final firstHalf = segments.take(kMaxSegments ~/ 2).toList();
      final lastHalf = segments
          .skip(segments.length - kMaxSegments ~/ 2)
          .toList();
      segmentModels = [
        ...firstHalf,
        ...lastHalf,
      ].map((s) => TranscriptSegmentModel.fromEntity(s)).toList();
    } else {
      segmentModels = segments
          .map((s) => TranscriptSegmentModel.fromEntity(s))
          .toList();
    }

    // Apply text truncation to individual segments if needed
    int textTruncatedCount = 0;
    segmentModels = segmentModels.map((s) {
      if (s.text.length > kMaxSegmentTextChars) {
        textTruncatedCount++;
        return s.copyWithTruncatedText(kMaxSegmentTextChars);
      }
      return s;
    }).toList();

    // Build truncation info if any truncation occurred
    if (segmentsTruncated || textTruncatedCount > 0) {
      truncationInfo = TruncationInfoModel(
        segmentsTruncated: segmentsTruncated,
        originalSegmentCount: originalSegmentCount,
        finalSegmentCount: segmentModels.length,
        textTruncatedSegments: textTruncatedCount,
        maxSegmentTextChars: kMaxSegmentTextChars,
      );
    }

    // Convert clinical facts to JSON
    final factsJson = result.facts.toJson();

    // Build evidence map from facts
    final evidenceMap = _buildEvidenceMap(result.facts);

    // Truncate SOAP text if too long
    String? soapText = result.soapText;
    if (soapText.length > kMaxTranscriptBytes ~/ 2) {
      soapText =
          '${soapText.substring(0, kMaxTranscriptBytes ~/ 2)}... [TRUNCATED]';
    }

    return ScribeV2ResultModel(
      transcriptSegments: segmentModels,
      clinicalFacts: factsJson,
      evidenceMap: evidenceMap,
      composerSoap: soapText,
      metadata: ScribeMetadataModel(
        source: source,
        modelProvider: modelProvider ?? 'openai',
        modelVersion: modelVersion,
        sttBackend: sttBackend,
        diarizationBackend: diarizationBackend,
        promptVersions: promptVersions ?? {},
        language: result.facts.metadata.language,
        pipelineTimings: PipelineTimingsModel.fromTimings(result.timings),
        negatedFindings: result.negatedFindings,
        appVersion: appVersion,
      ),
      createdAt: now,
      truncationInfo: truncationInfo,
    );
  }

  /// Creates model from Firestore document.
  factory ScribeV2ResultModel.fromFirestore(Map<String, dynamic> json) {
    // Helper to safely convert dynamic maps to Map<String, dynamic>
    Map<String, dynamic> toStringDynamicMap(dynamic value) {
      if (value == null) return {};
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return {};
    }

    return ScribeV2ResultModel(
      transcriptSegments:
          (json['transcriptSegments'] as List<dynamic>?)
              ?.map(
                (s) => TranscriptSegmentModel.fromJson(toStringDynamicMap(s)),
              )
              .toList() ??
          [],
      clinicalFacts: toStringDynamicMap(json['clinicalFacts']),
      evidenceMap: toStringDynamicMap(json['evidenceMap']),
      composerSoap: json['composerSoap'] as String?,
      metadata: json['metadata'] != null
          ? ScribeMetadataModel.fromJson(toStringDynamicMap(json['metadata']))
          : ScribeMetadataModel.empty(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      truncationInfo: json['truncationInfo'] != null
          ? TruncationInfoModel.fromJson(
              toStringDynamicMap(json['truncationInfo']),
            )
          : null,
    );
  }

  /// Converts to Firestore document.
  Map<String, dynamic> toFirestore() {
    return {
      'transcriptSegments': transcriptSegments.map((s) => s.toJson()).toList(),
      'clinicalFacts': clinicalFacts,
      'evidenceMap': evidenceMap,
      'composerSoap': composerSoap,
      'metadata': metadata.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (truncationInfo != null) 'truncationInfo': truncationInfo!.toJson(),
    };
  }

  /// Builds evidence map from clinical facts DTO.
  static Map<String, dynamic> _buildEvidenceMap(ClinicalFactsDTO facts) {
    final map = <String, dynamic>{};

    // Chief complaint evidence
    if (facts.chiefComplaint.evidence != null) {
      map['chiefComplaint'] = [facts.chiefComplaint.evidence!.toJson()];
    }

    // HPI evidence
    if (facts.hpi.evidence.isNotEmpty) {
      map['hpi'] = facts.hpi.evidence.map((e) => e.toJson()).toList();
    }

    // ROS evidence
    if (facts.ros.evidence.isNotEmpty) {
      map['ros'] = facts.ros.evidence.map((e) => e.toJson()).toList();
    }

    // Assessment evidence
    if (facts.assessment.evidence.isNotEmpty) {
      map['assessment'] = facts.assessment.evidence
          .map((e) => e.toJson())
          .toList();
    }

    // Plan evidence
    if (facts.plan.evidence.isNotEmpty) {
      map['plan'] = facts.plan.evidence.map((e) => e.toJson()).toList();
    }

    // PMH evidence (per item)
    final pmhEvidence = facts.pmh
        .where((item) => item.evidence != null)
        .map((item) => {'item': item.item, 'evidence': item.evidence!.toJson()})
        .toList();
    if (pmhEvidence.isNotEmpty) {
      map['pmh'] = pmhEvidence;
    }

    // Medications evidence (per item)
    final medsEvidence = facts.medications
        .where((item) => item.evidence != null)
        .map((item) => {'item': item.item, 'evidence': item.evidence!.toJson()})
        .toList();
    if (medsEvidence.isNotEmpty) {
      map['medications'] = medsEvidence;
    }

    // Allergies evidence (per item)
    final allergiesEvidence = facts.allergies
        .where((item) => item.evidence != null)
        .map((item) => {'item': item.item, 'evidence': item.evidence!.toJson()})
        .toList();
    if (allergiesEvidence.isNotEmpty) {
      map['allergies'] = allergiesEvidence;
    }

    return map;
  }
}

/// Model for a single transcript segment.
class TranscriptSegmentModel {
  const TranscriptSegmentModel({
    required this.text,
    required this.speaker,
    this.startMs,
    this.endMs,
  });

  final String text;
  final String speaker;
  final int? startMs;
  final int? endMs;

  factory TranscriptSegmentModel.fromEntity(TranscriptSegment segment) {
    return TranscriptSegmentModel(
      text: segment.text,
      speaker: segment.speaker,
      startMs: segment.startMs,
      endMs: segment.endMs,
    );
  }

  factory TranscriptSegmentModel.fromJson(Map<String, dynamic> json) {
    return TranscriptSegmentModel(
      text: json['text'] as String? ?? '',
      speaker: json['speaker'] as String? ?? 'unknown',
      startMs: json['startMs'] as int?,
      endMs: json['endMs'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'speaker': speaker,
      if (startMs != null) 'startMs': startMs,
      if (endMs != null) 'endMs': endMs,
    };
  }

  /// Creates a copy with truncated text.
  TranscriptSegmentModel copyWithTruncatedText(int maxChars) {
    if (text.length <= maxChars) return this;
    return TranscriptSegmentModel(
      text: '${text.substring(0, maxChars)}... [TRUNCATED]',
      speaker: speaker,
      startMs: startMs,
      endMs: endMs,
    );
  }
}

/// Metadata about the Scribe V2 pipeline run.
class ScribeMetadataModel {
  const ScribeMetadataModel({
    required this.source,
    required this.modelProvider,
    this.modelVersion,
    this.sttBackend,
    this.diarizationBackend,
    this.promptVersions = const {},
    this.language,
    this.pipelineTimings,
    this.negatedFindings = const [],
    this.appVersion,
  });

  /// Source of the result: 'scribe_v2', 'legacy', 'fallback_from_scribe_v2'
  final String source;

  /// Model provider (e.g., 'openai', 'anthropic')
  final String modelProvider;

  /// Model version (e.g., 'gpt-4o-mini', 'gpt-4-turbo')
  final String? modelVersion;

  /// STT backend used: 'whisper', 'chirp3', 'none' (for transcript-only)
  final String? sttBackend;

  /// Diarization backend used: 'pyannote', 'stub', 'none'
  final String? diarizationBackend;

  /// Versions of prompts used in pipeline
  final Map<String, String> promptVersions;

  /// Detected/specified language
  final String? language;

  /// Timing information for each pipeline stage
  final PipelineTimingsModel? pipelineTimings;

  /// List of negated findings
  final List<String> negatedFindings;

  /// App version string (e.g., '1.2.3+45')
  final String? appVersion;

  factory ScribeMetadataModel.empty() {
    return const ScribeMetadataModel(
      source: 'unknown',
      modelProvider: 'unknown',
    );
  }

  factory ScribeMetadataModel.fromJson(Map<String, dynamic> json) {
    return ScribeMetadataModel(
      source: json['source'] as String? ?? 'unknown',
      modelProvider: json['modelProvider'] as String? ?? 'unknown',
      modelVersion: json['modelVersion'] as String?,
      sttBackend: json['sttBackend'] as String?,
      diarizationBackend: json['diarizationBackend'] as String?,
      promptVersions:
          (json['promptVersions'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
      language: json['language'] as String?,
      pipelineTimings: json['pipelineTimings'] != null
          ? PipelineTimingsModel.fromJson(
              json['pipelineTimings'] as Map<String, dynamic>,
            )
          : null,
      negatedFindings:
          (json['negatedFindings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      appVersion: json['appVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'modelProvider': modelProvider,
      if (modelVersion != null) 'modelVersion': modelVersion,
      if (sttBackend != null) 'sttBackend': sttBackend,
      if (diarizationBackend != null) 'diarizationBackend': diarizationBackend,
      if (promptVersions.isNotEmpty) 'promptVersions': promptVersions,
      if (language != null) 'language': language,
      if (pipelineTimings != null) 'pipelineTimings': pipelineTimings!.toJson(),
      if (negatedFindings.isNotEmpty) 'negatedFindings': negatedFindings,
      if (appVersion != null) 'appVersion': appVersion,
    };
  }
}

/// Model for pipeline timing information.
class PipelineTimingsModel {
  const PipelineTimingsModel({
    required this.transcriptionMs,
    required this.medicalizationMs,
    required this.extractionMs,
    required this.compositionMs,
    required this.totalMs,
  });

  final int transcriptionMs;
  final int medicalizationMs;
  final int extractionMs;
  final int compositionMs;
  final int totalMs;

  factory PipelineTimingsModel.fromTimings(PipelineTimings timings) {
    return PipelineTimingsModel(
      transcriptionMs: timings.transcriptionMs,
      medicalizationMs: timings.medicalizationMs,
      extractionMs: timings.extractionMs,
      compositionMs: timings.compositionMs,
      totalMs: timings.totalMs,
    );
  }

  factory PipelineTimingsModel.fromJson(Map<String, dynamic> json) {
    return PipelineTimingsModel(
      transcriptionMs: json['transcriptionMs'] as int? ?? 0,
      medicalizationMs: json['medicalizationMs'] as int? ?? 0,
      extractionMs: json['extractionMs'] as int? ?? 0,
      compositionMs: json['compositionMs'] as int? ?? 0,
      totalMs: json['totalMs'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transcriptionMs': transcriptionMs,
      'medicalizationMs': medicalizationMs,
      'extractionMs': extractionMs,
      'compositionMs': compositionMs,
      'totalMs': totalMs,
    };
  }
}

/// Information about data truncation applied for size limits.
class TruncationInfoModel {
  const TruncationInfoModel({
    this.segmentsTruncated = false,
    this.originalSegmentCount = 0,
    this.finalSegmentCount = 0,
    this.textTruncatedSegments = 0,
    this.maxSegmentTextChars = kMaxSegmentTextChars,
  });

  /// Whether segments were truncated (count exceeded limit).
  final bool segmentsTruncated;

  /// Original number of segments before truncation.
  final int originalSegmentCount;

  /// Final number of segments after truncation.
  final int finalSegmentCount;

  /// Number of segments with truncated text.
  final int textTruncatedSegments;

  /// Maximum characters allowed per segment text.
  final int maxSegmentTextChars;

  factory TruncationInfoModel.fromJson(Map<String, dynamic> json) {
    return TruncationInfoModel(
      segmentsTruncated: json['segmentsTruncated'] as bool? ?? false,
      originalSegmentCount: json['originalSegmentCount'] as int? ?? 0,
      finalSegmentCount: json['finalSegmentCount'] as int? ?? 0,
      textTruncatedSegments: json['textTruncatedSegments'] as int? ?? 0,
      maxSegmentTextChars:
          json['maxSegmentTextChars'] as int? ?? kMaxSegmentTextChars,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'segmentsTruncated': segmentsTruncated,
      'originalSegmentCount': originalSegmentCount,
      'finalSegmentCount': finalSegmentCount,
      'textTruncatedSegments': textTruncatedSegments,
      'maxSegmentTextChars': maxSegmentTextChars,
    };
  }
}
