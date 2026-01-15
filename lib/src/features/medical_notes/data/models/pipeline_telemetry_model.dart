// lib/src/features/medical_notes/data/models/pipeline_telemetry_model.dart
//
// Telemetry model for Scribe pipeline metrics.
// IMPORTANT: This model MUST NOT contain any PHI (Protected Health Information).
// Only timing, counters, flags, and backend identifiers are allowed.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Telemetry data for the Scribe V2 pipeline run.
///
/// This model captures non-PHI metrics for observability and debugging.
/// Stored at: `medical_notes/{noteId}/telemetry/latest`
///
/// **PHI-Free Guarantee:**
/// - No transcript text
/// - No clinical facts
/// - No patient/doctor identifiers
/// - No SOAP content
/// - Only timing, counters, and system metadata
class PipelineTelemetryModel {
  const PipelineTelemetryModel({
    required this.noteId,
    required this.timings,
    required this.counters,
    required this.backends,
    required this.flags,
    required this.createdAt,
    this.appVersion,
    this.platformInfo,
  });

  /// Note ID (non-PHI reference)
  final String noteId;

  /// Timing metrics for each pipeline stage
  final TelemetryTimings timings;

  /// Counters for pipeline elements
  final TelemetryCounters counters;

  /// Backend services used
  final TelemetryBackends backends;

  /// Boolean flags for pipeline state
  final TelemetryFlags flags;

  /// When telemetry was recorded
  final DateTime createdAt;

  /// App version string (e.g., '1.2.3+45')
  final String? appVersion;

  /// Platform info (e.g., 'android', 'ios', 'windows')
  final String? platformInfo;

  /// Creates telemetry from pipeline execution data.
  factory PipelineTelemetryModel.fromPipelineRun({
    required String noteId,
    required int transcriptionMs,
    required int diarizationMs,
    required int extractionMs,
    required int compositionMs,
    required int totalMs,
    int? sttChunksCount,
    int? segmentsCount,
    int? segmentsAfterTruncation,
    required String sttBackend,
    required String diarizationBackend,
    String? modelProvider,
    String? modelVersion,
    bool fallbackUsed = false,
    String? fallbackReason,
    bool truncationOccurred = false,
    bool qualityGateBlocked = false,
    String? appVersion,
    String? platformInfo,
  }) {
    return PipelineTelemetryModel(
      noteId: noteId,
      timings: TelemetryTimings(
        sttMs: transcriptionMs,
        diarizationMs: diarizationMs,
        extractionMs: extractionMs,
        compositionMs: compositionMs,
        totalMs: totalMs,
      ),
      counters: TelemetryCounters(
        sttChunksCount: sttChunksCount ?? 1,
        segmentsCount: segmentsCount ?? 0,
        segmentsAfterTruncation: segmentsAfterTruncation,
      ),
      backends: TelemetryBackends(
        sttBackend: sttBackend,
        diarizationBackend: diarizationBackend,
        modelProvider: modelProvider ?? 'openai',
        modelVersion: modelVersion,
      ),
      flags: TelemetryFlags(
        fallbackUsed: fallbackUsed,
        fallbackReason: fallbackReason,
        truncationOccurred: truncationOccurred,
        qualityGateBlocked: qualityGateBlocked,
      ),
      createdAt: DateTime.now(),
      appVersion: appVersion,
      platformInfo: platformInfo,
    );
  }

  /// Creates from Firestore document.
  factory PipelineTelemetryModel.fromFirestore(Map<String, dynamic> json) {
    return PipelineTelemetryModel(
      noteId: json['noteId'] as String? ?? '',
      timings: TelemetryTimings.fromJson(
        json['timings'] as Map<String, dynamic>? ?? {},
      ),
      counters: TelemetryCounters.fromJson(
        json['counters'] as Map<String, dynamic>? ?? {},
      ),
      backends: TelemetryBackends.fromJson(
        json['backends'] as Map<String, dynamic>? ?? {},
      ),
      flags: TelemetryFlags.fromJson(
        json['flags'] as Map<String, dynamic>? ?? {},
      ),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      appVersion: json['appVersion'] as String?,
      platformInfo: json['platformInfo'] as String?,
    );
  }

  /// Converts to Firestore document.
  ///
  /// **PHI-Free Guarantee:** This method only serializes non-PHI fields.
  Map<String, dynamic> toFirestore() {
    return {
      'noteId': noteId,
      'timings': timings.toJson(),
      'counters': counters.toJson(),
      'backends': backends.toJson(),
      'flags': flags.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      if (appVersion != null) 'appVersion': appVersion,
      if (platformInfo != null) 'platformInfo': platformInfo,
    };
  }

  /// Returns list of all field keys to verify no PHI fields are present.
  static List<String> get allowedFields => [
    'noteId',
    'timings',
    'counters',
    'backends',
    'flags',
    'createdAt',
    'appVersion',
    'platformInfo',
  ];

  /// Validates that the model contains no PHI fields.
  /// Returns true if safe, throws if PHI detected.
  bool validateNoPhi() {
    // This is a compile-time guarantee via the model structure,
    // but this method can be used in tests.
    final json = toFirestore();
    final forbiddenKeys = [
      'transcript',
      'transcriptSegments',
      'clinicalFacts',
      'facts',
      'soapText',
      'composerSoap',
      'evidenceMap',
      'patientId',
      'patientName',
      'doctorId',
      'doctorName',
    ];

    for (final key in forbiddenKeys) {
      if (json.containsKey(key)) {
        throw StateError('PHI field detected in telemetry: $key');
      }
    }
    return true;
  }
}

/// Timing metrics for pipeline stages.
class TelemetryTimings {
  const TelemetryTimings({
    required this.sttMs,
    required this.diarizationMs,
    required this.extractionMs,
    required this.compositionMs,
    required this.totalMs,
  });

  /// Speech-to-text duration in milliseconds
  final int sttMs;

  /// Diarization duration in milliseconds
  final int diarizationMs;

  /// Clinical facts extraction duration in milliseconds
  final int extractionMs;

  /// Note composition duration in milliseconds
  final int compositionMs;

  /// Total pipeline duration in milliseconds
  final int totalMs;

  factory TelemetryTimings.fromJson(Map<String, dynamic> json) {
    return TelemetryTimings(
      sttMs: json['sttMs'] as int? ?? 0,
      diarizationMs: json['diarizationMs'] as int? ?? 0,
      extractionMs: json['extractionMs'] as int? ?? 0,
      compositionMs: json['compositionMs'] as int? ?? 0,
      totalMs: json['totalMs'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sttMs': sttMs,
      'diarizationMs': diarizationMs,
      'extractionMs': extractionMs,
      'compositionMs': compositionMs,
      'totalMs': totalMs,
    };
  }
}

/// Counter metrics for pipeline elements.
class TelemetryCounters {
  const TelemetryCounters({
    required this.sttChunksCount,
    required this.segmentsCount,
    this.segmentsAfterTruncation,
  });

  /// Number of audio chunks processed by STT (VAD/chunking)
  final int sttChunksCount;

  /// Number of transcript segments before truncation
  final int segmentsCount;

  /// Number of segments after truncation (if truncated)
  final int? segmentsAfterTruncation;

  factory TelemetryCounters.fromJson(Map<String, dynamic> json) {
    return TelemetryCounters(
      sttChunksCount: json['sttChunksCount'] as int? ?? 1,
      segmentsCount: json['segmentsCount'] as int? ?? 0,
      segmentsAfterTruncation: json['segmentsAfterTruncation'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sttChunksCount': sttChunksCount,
      'segmentsCount': segmentsCount,
      if (segmentsAfterTruncation != null)
        'segmentsAfterTruncation': segmentsAfterTruncation,
    };
  }
}

/// Backend service identifiers used in the pipeline.
class TelemetryBackends {
  const TelemetryBackends({
    required this.sttBackend,
    required this.diarizationBackend,
    required this.modelProvider,
    this.modelVersion,
  });

  /// STT backend: 'whisper', 'chirp3', 'none'
  final String sttBackend;

  /// Diarization backend: 'pyannote', 'stub', 'none'
  final String diarizationBackend;

  /// LLM provider: 'openai', 'anthropic', etc.
  final String modelProvider;

  /// LLM model version: 'gpt-4o-mini', 'gpt-4-turbo', etc.
  final String? modelVersion;

  factory TelemetryBackends.fromJson(Map<String, dynamic> json) {
    return TelemetryBackends(
      sttBackend: json['sttBackend'] as String? ?? 'unknown',
      diarizationBackend: json['diarizationBackend'] as String? ?? 'unknown',
      modelProvider: json['modelProvider'] as String? ?? 'unknown',
      modelVersion: json['modelVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sttBackend': sttBackend,
      'diarizationBackend': diarizationBackend,
      'modelProvider': modelProvider,
      if (modelVersion != null) 'modelVersion': modelVersion,
    };
  }
}

/// Boolean flags for pipeline state.
class TelemetryFlags {
  const TelemetryFlags({
    required this.fallbackUsed,
    this.fallbackReason,
    required this.truncationOccurred,
    required this.qualityGateBlocked,
  });

  /// Whether fallback to legacy service was used
  final bool fallbackUsed;

  /// Reason for fallback (if used)
  final String? fallbackReason;

  /// Whether transcript was truncated due to size limits
  final bool truncationOccurred;

  /// Whether Quality Gate blocked the note from signing
  final bool qualityGateBlocked;

  factory TelemetryFlags.fromJson(Map<String, dynamic> json) {
    return TelemetryFlags(
      fallbackUsed: json['fallbackUsed'] as bool? ?? false,
      fallbackReason: json['fallbackReason'] as String?,
      truncationOccurred: json['truncationOccurred'] as bool? ?? false,
      qualityGateBlocked: json['qualityGateBlocked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fallbackUsed': fallbackUsed,
      if (fallbackReason != null) 'fallbackReason': fallbackReason,
      'truncationOccurred': truncationOccurred,
      'qualityGateBlocked': qualityGateBlocked,
    };
  }
}
