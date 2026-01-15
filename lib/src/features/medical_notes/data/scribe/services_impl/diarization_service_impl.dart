// lib/src/features/medical_notes/data/scribe/services_impl/diarization_service_impl.dart

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/logger/log.dart';
import '../../../domain/scribe/entities/transcript_segment.dart';
import '../../../domain/scribe/entities/transcript_with_speakers.dart';
import '../../../domain/scribe/services/diarization_service.dart';

/// Configuration for the Pyannote diarization backend.
class DiarizationBackendConfig {
  const DiarizationBackendConfig({
    this.baseUrl = 'http://localhost:8000',
    this.endpoint = '/diarize',
    this.timeoutSeconds = 120,
    this.maxRetries = 2,
  });

  /// Base URL of the diarization service.
  final String baseUrl;

  /// Endpoint path for diarization.
  final String endpoint;

  /// Request timeout in seconds.
  final int timeoutSeconds;

  /// Maximum retry attempts.
  final int maxRetries;

  String get fullUrl => '$baseUrl$endpoint';
}

/// Response segment from the diarization backend.
class DiarizationBackendSegment {
  const DiarizationBackendSegment({
    required this.startMs,
    required this.endMs,
    required this.speaker,
  });

  final int startMs;
  final int endMs;
  final String speaker;

  factory DiarizationBackendSegment.fromJson(Map<String, dynamic> json) {
    return DiarizationBackendSegment(
      startMs: json['startMs'] as int? ?? json['start_ms'] as int? ?? 0,
      endMs: json['endMs'] as int? ?? json['end_ms'] as int? ?? 0,
      speaker: json['speaker'] as String? ?? 'unknown',
    );
  }
}

/// Real implementation of [DiarizationService] using Pyannote backend.
///
/// Calls a FastAPI service running pyannote-audio for speaker diarization.
/// Falls back to stub behavior if the backend is unavailable.
class DiarizationServiceImpl implements DiarizationService {
  DiarizationServiceImpl({
    DiarizationBackendConfig config = const DiarizationBackendConfig(),
    DiarizationService? fallbackService,
    Dio? dio,
  }) : _config = config,
       _fallbackService = fallbackService,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: Duration(seconds: config.timeoutSeconds ~/ 2),
               receiveTimeout: Duration(seconds: config.timeoutSeconds),
               sendTimeout: Duration(seconds: config.timeoutSeconds ~/ 2),
             ),
           );

  final DiarizationBackendConfig _config;
  final DiarizationService? _fallbackService;
  final Dio _dio;

  @override
  Future<TranscriptWithSpeakers> diarize(
    String audioFilePath,
    TranscriptWithSpeakers transcript, {
    DiarizationOptions options = const DiarizationOptions(),
  }) async {
    Log.info('[Diarization] Starting real diarization via backend');

    // Skip if single segment (no benefit from diarization)
    if (transcript.segments.length <= 1) {
      Log.info('[Diarization] Single segment, skipping');
      return transcript;
    }

    try {
      // Call backend with retries
      final backendSegments = await _callBackendWithRetry(
        audioFilePath,
        options,
      );

      if (backendSegments.isEmpty) {
        Log.warning('[Diarization] Backend returned no segments');
        return _fallbackOrReturn(audioFilePath, transcript, options);
      }

      // Map backend speakers to transcript segments
      return _mapSpeakersToTranscript(
        transcript,
        backendSegments,
        options.speakerLabels,
      );
    } on DiarizationException catch (e) {
      Log.error('[Diarization] Backend error: ${e.message}');
      return _fallbackOrReturn(audioFilePath, transcript, options);
    } catch (e) {
      Log.error('[Diarization] Unexpected error: $e');
      return _fallbackOrReturn(audioFilePath, transcript, options);
    }
  }

  /// Calls the backend with retry logic.
  Future<List<DiarizationBackendSegment>> _callBackendWithRetry(
    String audioFilePath,
    DiarizationOptions options,
  ) async {
    Exception? lastError;

    for (int attempt = 0; attempt <= _config.maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          Log.info('[Diarization] Retry attempt $attempt');
          await Future.delayed(Duration(seconds: attempt * 2));
        }

        return await _callBackend(audioFilePath, options);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        Log.warning('[Diarization] Attempt $attempt failed: $e');
      }
    }

    throw DiarizationException('All retry attempts failed', cause: lastError);
  }

  /// Makes actual HTTP call to the diarization backend.
  Future<List<DiarizationBackendSegment>> _callBackend(
    String audioFilePath,
    DiarizationOptions options,
  ) async {
    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw const DiarizationException('Audio file not found');
    }

    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        audioFilePath,
        filename: file.uri.pathSegments.last,
      ),
      'min_speakers': options.minSpeakers,
      if (options.maxSpeakers != null) 'max_speakers': options.maxSpeakers,
      'labels': jsonEncode(options.speakerLabels),
    });

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _config.fullUrl,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode != 200) {
        throw DiarizationException(
          'Backend returned status ${response.statusCode}',
        );
      }

      final data = response.data!;
      final segments = data['segments'] as List<dynamic>? ?? [];

      return segments
          .map(
            (s) =>
                DiarizationBackendSegment.fromJson(s as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Maps backend speaker segments to transcript segments.
  TranscriptWithSpeakers _mapSpeakersToTranscript(
    TranscriptWithSpeakers transcript,
    List<DiarizationBackendSegment> backendSegments,
    List<String> speakerLabels,
  ) {
    // Build speaker lookup: speaker_0 -> "Doctor", speaker_1 -> "Paciente"
    final speakerMap = <String, String>{};

    final diarizedSegments = <TranscriptSegment>[];

    for (final seg in transcript.segments) {
      final segStartMs = seg.startMs ?? 0;
      final segEndMs = seg.endMs ?? segStartMs + 1000;

      // Find overlapping backend segment
      String speaker = 'unknown';
      int maxOverlap = 0;

      for (final backendSeg in backendSegments) {
        final overlapStart = segStartMs > backendSeg.startMs
            ? segStartMs
            : backendSeg.startMs;
        final overlapEnd = segEndMs < backendSeg.endMs
            ? segEndMs
            : backendSeg.endMs;
        final overlap = overlapEnd - overlapStart;

        if (overlap > maxOverlap) {
          maxOverlap = overlap;

          // Map speaker ID to label
          if (!speakerMap.containsKey(backendSeg.speaker)) {
            final labelIndex = speakerMap.length;
            if (labelIndex < speakerLabels.length) {
              speakerMap[backendSeg.speaker] = speakerLabels[labelIndex];
            } else {
              speakerMap[backendSeg.speaker] = backendSeg.speaker;
            }
          }
          speaker = speakerMap[backendSeg.speaker]!;
        }
      }

      diarizedSegments.add(
        TranscriptSegment(
          text: seg.text,
          speaker: speaker,
          startMs: seg.startMs,
          endMs: seg.endMs,
        ),
      );
    }

    if (kDebugMode) {
      Log.info(
        '[Diarization] Mapped ${speakerMap.length} speakers: '
        '${speakerMap.values.toSet().join(", ")}',
      );
    }

    return TranscriptWithSpeakers(
      segments: diarizedSegments,
      language: transcript.language,
      durationMs: transcript.durationMs,
    );
  }

  /// Falls back to alternative service or returns original transcript.
  Future<TranscriptWithSpeakers> _fallbackOrReturn(
    String audioFilePath,
    TranscriptWithSpeakers transcript,
    DiarizationOptions options,
  ) async {
    if (_fallbackService != null) {
      Log.info('[Diarization] Using fallback service');
      return _fallbackService.diarize(
        audioFilePath,
        transcript,
        options: options,
      );
    }

    Log.warning('[Diarization] No fallback, returning original transcript');
    return transcript;
  }

  /// Handles Dio errors.
  DiarizationException _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return DiarizationException('Backend timeout', cause: e);

      case DioExceptionType.connectionError:
        return DiarizationException(
          'Cannot connect to diarization backend at ${_config.baseUrl}',
          cause: e,
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        return DiarizationException(
          'Backend error: status $statusCode',
          cause: e,
        );

      default:
        return DiarizationException('Network error: ${e.message}', cause: e);
    }
  }
}
