// lib/src/features/medical_notes/application/scribe/finalize_service.dart
//
// Application service for ÉPICA 17 - MedGemma Finalize.
// Single LLM call to finalize reduce_draft using transcript evidence.
// PHI-safe: NO transcripts, prompts, outputs, or headers logged.

import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:medical_notes_app/src/core/logger/log.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart';

import 'prompt_templates/finalize_prompts.dart';

/// Result of finalize operation.
class FinalizeResult {
  const FinalizeResult({
    required this.structured,
    required this.metadata,
  });

  /// Finalized structured data (same shape as reduce_draft).
  final Map<String, dynamic> structured;

  /// Metadata about the finalization.
  final FinalizeMetadata metadata;
}

/// Metadata from finalize operation.
class FinalizeMetadata {
  const FinalizeMetadata({
    required this.confidenceOverall,
    required this.contractStatus,
    required this.contractWarnings,
    required this.finalizeUsedEvidence,
  });

  /// "alta" | "media" | "baja"
  final String confidenceOverall;

  /// "ok" | "warning" | "drift"
  final String contractStatus;

  /// Canonical warnings: empty_transcript, timeout:finalize_did_not_complete, etc.
  final List<String> contractWarnings;

  /// Whether transcript evidence was used.
  final bool finalizeUsedEvidence;
}

/// Canonical contract warnings.
abstract class FinalizeWarnings {
  static const emptyTranscript = 'empty_transcript';
  static const timeout = 'timeout:finalize_did_not_complete';
  static const error = 'error:finalize_failed';
  static const invalidJson = 'invalid_json:finalize_response';
  static const invalidReduceDraft = 'invalid_reduce_draft';

  // ignore: constant_identifier_names
  /// Used when FinalizeService provider is null (MedGemma not configured).
  static const finalize_disabled_no_client = 'finalize_disabled:no_client';

  static String unresolvedConflict(String topic) => 'unresolved_conflict:$topic';
  static String resolvedContradiction(String topic) =>
      'resolved_contradiction:$topic';
  static String missingField(String field) => 'missing_field:$field';
  static String missingEvidence(String field) => 'missing_evidence:$field';
}

/// Service to finalize reduce_draft using MedGemma.
///
/// Pipeline:
/// 1. Build prompts from templates (inject transcript + reduce_draft)
/// 2. Call MedGemma client ONCE (no retries)
/// 3. Parse response
/// 4. On any error → deterministic fallback (sanitized reduce_draft + warning metadata)
///
/// PHI-safe: Does NOT log transcripts, prompts, or clinical outputs.
class FinalizeService {
  FinalizeService({
    required MedGemmaServiceClient client,
    Duration? timeoutOverride,
  })  : _client = client,
        _timeoutOverride = timeoutOverride;

  final MedGemmaServiceClient _client;
  final Duration? _timeoutOverride;

  /// Finalizes reduce_draft using transcript evidence.
  ///
  /// Single LLM call. If finalize fails for ANY reason, returns
  /// deterministic fallback: sanitized reduce_draft with warning metadata.
  ///
  /// [transcript] - Raw transcript text (may be empty)
  /// [reduceDraft] - Schema V1 structured data from reduce step
  ///
  /// Always returns a valid [FinalizeResult], never throws.
  Future<FinalizeResult> finalize({
    required String transcript,
    required Map<String, dynamic> reduceDraft,
  }) async {
    // PHI-safe: Log operation start, not content
    Log.info('[FINALIZE-SERVICE] Starting finalize operation');

    // Handle empty transcript
    if (transcript.trim().isEmpty) {
      Log.info('[FINALIZE-SERVICE] Empty transcript - returning reduce_draft unchanged');
      return _buildFallbackResult(
        reduceDraft: reduceDraft,
        warnings: [FinalizeWarnings.emptyTranscript],
        usedEvidence: false,
      );
    }

    // Build prompts
    final userPrompt = _buildUserPrompt(
      transcript: transcript,
      reduceDraft: reduceDraft,
    );

    try {
      // Single LLM call
      final response = await _client.finalize(
        systemPrompt: finalizeSystemPrompt,
        userPrompt: userPrompt,
        timeoutOverride: _timeoutOverride,
      );

      // Handle client-level error response
      if (!response.success || response.structured == null) {
        Log.warning(
          '[FINALIZE-SERVICE] Client returned error - using fallback. '
          'code=${response.error?.code}',
        );
        return _buildFallbackResult(
          reduceDraft: reduceDraft,
          warnings: [FinalizeWarnings.error],
          usedEvidence: false,
        );
      }

      // Validate response structure
      final metadata = response.metadata;
      if (metadata == null) {
        Log.warning('[FINALIZE-SERVICE] Missing metadata in response - using fallback');
        return _buildFallbackResult(
          reduceDraft: reduceDraft,
          warnings: [FinalizeWarnings.invalidJson],
          usedEvidence: false,
        );
      }

      // Success - return finalized result
      Log.info(
        '[FINALIZE-SERVICE] Finalize successful. '
        'contractStatus=${metadata.contractStatus} '
        'confidence=${metadata.confidenceOverall}',
      );

      return FinalizeResult(
        structured: response.structured!,
        metadata: FinalizeMetadata(
          confidenceOverall: metadata.confidenceOverall ?? 'baja',
          contractStatus: metadata.contractStatus ?? 'warning',
          contractWarnings: metadata.contractWarnings ?? [],
          finalizeUsedEvidence: metadata.finalizeUsedEvidence ?? true,
        ),
      );
    } on DioException catch (e) {
      // Timeout or network error
      final isTimeout = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;

      final warning = isTimeout ? FinalizeWarnings.timeout : FinalizeWarnings.error;

      Log.warning(
        '[FINALIZE-SERVICE] DioException - using fallback. '
        'type=${e.type} isTimeout=$isTimeout',
      );

      return _buildFallbackResult(
        reduceDraft: reduceDraft,
        warnings: [warning],
        usedEvidence: false,
      );
    } on MedGemmaUnauthorizedException catch (e) {
      Log.warning('[FINALIZE-SERVICE] Unauthorized - using fallback. ${e.message}');
      return _buildFallbackResult(
        reduceDraft: reduceDraft,
        warnings: [FinalizeWarnings.error],
        usedEvidence: false,
      );
    } on FormatException catch (e) {
      Log.warning('[FINALIZE-SERVICE] JSON parse error - using fallback. $e');
      return _buildFallbackResult(
        reduceDraft: reduceDraft,
        warnings: [FinalizeWarnings.invalidJson],
        usedEvidence: false,
      );
    } catch (e) {
      // Any other unexpected error
      Log.error('[FINALIZE-SERVICE] Unexpected error - using fallback. $e');
      return _buildFallbackResult(
        reduceDraft: reduceDraft,
        warnings: [FinalizeWarnings.error],
        usedEvidence: false,
      );
    }
  }

  /// Builds the user prompt by replacing placeholders.
  String _buildUserPrompt({
    required String transcript,
    required Map<String, dynamic> reduceDraft,
  }) {
    final reduceDraftJson = const JsonEncoder.withIndent('  ').convert(reduceDraft);

    return finalizeUserPromptTemplate
        .replaceAll('{{TRANSCRIPT}}', transcript)
        .replaceAll('{{REDUCE_DRAFT_JSON}}', reduceDraftJson);
  }

  /// Builds deterministic fallback result.
  ///
  /// Returns sanitized reduce_draft (trimmed strings, valid JSON)
  /// with warning metadata.
  FinalizeResult _buildFallbackResult({
    required Map<String, dynamic> reduceDraft,
    required List<String> warnings,
    required bool usedEvidence,
  }) {
    return FinalizeResult(
      structured: _sanitizeReduceDraft(reduceDraft),
      metadata: FinalizeMetadata(
        confidenceOverall: 'baja',
        contractStatus: 'warning',
        contractWarnings: warnings,
        finalizeUsedEvidence: usedEvidence,
      ),
    );
  }

  /// Sanitizes reduce_draft for fallback.
  ///
  /// - Trims string values
  /// - Preserves structure exactly (no key additions/removals)
  /// - Returns valid Map
  Map<String, dynamic> _sanitizeReduceDraft(Map<String, dynamic> reduceDraft) {
    return _deepSanitize(reduceDraft) as Map<String, dynamic>;
  }

  /// Recursively sanitizes values (trims strings).
  dynamic _deepSanitize(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      return value.trim();
    }

    if (value is Map<String, dynamic>) {
      return value.map((k, v) => MapEntry(k, _deepSanitize(v)));
    }

    if (value is List) {
      return value.map(_deepSanitize).toList();
    }

    // Primitives (int, double, bool) pass through
    return value;
  }
}
