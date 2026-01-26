// lib/src/features/medical_notes/data/medgemma/models/job_status_model.dart
//
// Model for MedGemma job queue status (ÉPICA 18).
// PHI-safe: Does not contain clinical data, only job metadata.

/// Status of a job in the MedGemma queue.
enum JobState {
  /// Job is waiting in queue
  queued,

  /// Job is currently being processed
  running,

  /// Job completed successfully
  done,

  /// Job failed
  failed,

  /// Unknown state
  unknown,
}

/// Extension to parse JobState from string.
extension JobStateExtension on JobState {
  static JobState fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'queued':
        return JobState.queued;
      case 'running':
        return JobState.running;
      case 'done':
        return JobState.done;
      case 'failed':
        return JobState.failed;
      default:
        return JobState.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case JobState.queued:
        return 'queued';
      case JobState.running:
        return 'running';
      case JobState.done:
        return 'done';
      case JobState.failed:
        return 'failed';
      case JobState.unknown:
        return 'unknown';
    }
  }

  bool get isTerminal => this == JobState.done || this == JobState.failed;
  bool get isPending => this == JobState.queued || this == JobState.running;
}

/// Job status information from the queue.
///
/// PHI-safe: Contains only job metadata, no clinical content.
class JobStatusModel {
  const JobStatusModel({
    required this.requestId,
    required this.status,
    this.position,
    this.etaSeconds,
    this.result,
    this.error,
    this.fallbackUsed = false,
    this.contractWarnings,
    this.createdAt,
    this.updatedAt,
  });

  factory JobStatusModel.fromJson(Map<String, dynamic> json) {
    return JobStatusModel(
      requestId: json['requestId'] as String? ?? '',
      status: JobStateExtension.fromString(json['status'] as String?),
      position: json['position'] as int?,
      etaSeconds: json['etaSeconds'] as int?,
      result: json['result'] as Map<String, dynamic>?,
      error: json['error'] != null
          ? JobErrorInfo.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      fallbackUsed: json['fallbackUsed'] as bool? ?? false,
      contractWarnings: (json['contractWarnings'] as List?)?.cast<String>(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Unique request/job identifier.
  final String requestId;

  /// Current job state.
  final JobState status;

  /// Position in queue (1-based, null if running/done/failed).
  final int? position;

  /// Estimated time to completion in seconds.
  final int? etaSeconds;

  /// Result data when job is done (contains clinical data - PHI).
  /// PHI: NEVER log this field.
  final Map<String, dynamic>? result;

  /// Error information if job failed.
  final JobErrorInfo? error;

  /// Whether fallback processing was used.
  final bool fallbackUsed;

  /// Contract warnings from processing.
  final List<String>? contractWarnings;

  /// When the job was created.
  final DateTime? createdAt;

  /// When the job status was last updated.
  final DateTime? updatedAt;

  /// Creates a copy with updated fields.
  JobStatusModel copyWith({
    String? requestId,
    JobState? status,
    int? position,
    int? etaSeconds,
    Map<String, dynamic>? result,
    JobErrorInfo? error,
    bool? fallbackUsed,
    List<String>? contractWarnings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobStatusModel(
      requestId: requestId ?? this.requestId,
      status: status ?? this.status,
      position: position ?? this.position,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      result: result ?? this.result,
      error: error ?? this.error,
      fallbackUsed: fallbackUsed ?? this.fallbackUsed,
      contractWarnings: contractWarnings ?? this.contractWarnings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'status': status.toJson(),
        if (position != null) 'position': position,
        if (etaSeconds != null) 'etaSeconds': etaSeconds,
        // PHI: result not serialized to prevent accidental logging
        if (error != null) 'error': error!.toJson(),
        'fallbackUsed': fallbackUsed,
        if (contractWarnings != null) 'contractWarnings': contractWarnings,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  @override
  String toString() =>
      'JobStatusModel(requestId: $requestId, status: $status, '
      'position: $position, etaSeconds: $etaSeconds, fallbackUsed: $fallbackUsed)';
}

/// Error information for failed jobs.
class JobErrorInfo {
  const JobErrorInfo({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  factory JobErrorInfo.fromJson(Map<String, dynamic> json) {
    return JobErrorInfo(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? 'Unknown error',
      retryable: json['retryable'] as bool? ?? false,
    );
  }

  final String code;
  final String message;
  final bool retryable;

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'retryable': retryable,
      };
}

/// Response from enqueue endpoint.
class EnqueueResponse {
  const EnqueueResponse({
    required this.requestId,
    required this.status,
    this.position,
    this.etaSeconds,
    this.existingJobId,
  });

  factory EnqueueResponse.fromJson(Map<String, dynamic> json) {
    return EnqueueResponse(
      requestId: json['requestId'] as String? ?? '',
      status: JobStateExtension.fromString(json['status'] as String?),
      position: json['position'] as int?,
      etaSeconds: json['etaSeconds'] as int?,
      existingJobId: json['existingJobId'] as String?,
    );
  }

  /// The job ID (new or existing).
  final String requestId;

  /// Initial job state.
  final JobState status;

  /// Initial queue position.
  final int? position;

  /// Initial ETA estimate.
  final int? etaSeconds;

  /// If user already has a job in progress, this is its ID.
  /// When non-null, no new job was created (busy state).
  final String? existingJobId;

  /// Whether user was busy (had existing job).
  bool get isBusy => existingJobId != null;
}
