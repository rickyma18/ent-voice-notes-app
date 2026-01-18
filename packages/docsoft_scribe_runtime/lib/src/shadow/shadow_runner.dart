// packages/docsoft_scribe_runtime/lib/src/shadow/shadow_runner.dart
//
// ÉPICA 3: Orchestrator for shadow extraction pipeline.
//
// Flow:
// 1. Translate transcript ES→EN via TranslationService
// 2. Call MedGemma extraction
// 3. Validate schema
// 4. Adapt to DTO
// 5. Compare with production
// 6. Persist diff report if enabled
// 7. NEVER throw exceptions to production

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/shadow/shadow.dart';
import 'package:docsoft_scribe_core/src/translation/translation.dart';

import '../translation/translation.dart';
import 'medgemma_extractor_service_impl.dart';
import 'shadow_diff_analyzer.dart';

/// Orchestrator for shadow extraction.
///
/// Runs MedGemma extraction in parallel to production without affecting it.
/// All exceptions are caught and logged, never propagated.
class ShadowRunner {
  ShadowRunner({
    required TranslationService translationService,
    required MedGemmaExtractorServiceImpl medgemmaService,
    required ShadowConfig config,
    ShadowDiffAnalyzer? analyzer,
  })  : _translationService = translationService,
        _medgemmaService = medgemmaService,
        _config = config,
        _analyzer = analyzer ?? const ShadowDiffAnalyzer();

  final TranslationService _translationService;
  final MedGemmaExtractorServiceImpl _medgemmaService;
  final ShadowConfig _config;
  final ShadowDiffAnalyzer _analyzer;

  /// Run shadow extraction.
  ///
  /// [transcript] - Spanish transcript.
  /// [productionFacts] - Facts from production pipeline.
  /// [productionDurationMs] - Duration of production extraction.
  ///
  /// Returns diff report. Never throws.
  Future<ShadowDiffReport?> run({
    required String transcript,
    required ClinicalFactsDTO productionFacts,
    required int productionDurationMs,
  }) async {
    if (!_config.enabled) return null;

    final transcriptHash = _computeHash(transcript);
    final stopwatch = Stopwatch()..start();

    try {
      // Step 1: Translate ES→EN
      final translationResult = await _translationService
          .translateClinicalText(
            text: transcript,
            direction: TranslationDirection.estoEN,
            context: ClinicalContext.ent,
            options: const TranslationOptions(
              strictValidation: true,
              useCache: true,
            ),
          )
          .timeout(_config.timeout);

      if (!translationResult.isSafeForClinicalUse) {
        return _errorReport(
          transcriptHash: transcriptHash,
          productionDurationMs: productionDurationMs,
          shadowDurationMs: stopwatch.elapsedMilliseconds,
          errorType: ShadowErrorType.translationFailed,
          message: 'Translation not safe for clinical use',
        );
      }

      // Step 2: Extract with MedGemma
      final extractionResult = await _medgemmaService
          .extract(translationResult.translatedText)
          .timeout(_config.timeout);

      stopwatch.stop();

      // Step 3: Compare with production
      final diffResult = _analyzer.analyze(
        production: productionFacts,
        shadow: extractionResult.facts,
      );

      // Step 4: Build report
      final report = ShadowDiffReport(
        timestamp: DateTime.now(),
        transcriptHash: transcriptHash,
        productionDurationMs: productionDurationMs,
        shadowDurationMs: stopwatch.elapsedMilliseconds,
        added: diffResult.added,
        missing: diffResult.missing,
        contradictions: diffResult.contradictions,
        missingEvidence: diffResult.missingEvidence,
      );

      // Step 5: Persist if enabled
      if (_config.persistReports) {
        await _persistReport(report, transcriptHash);
      }

      return report;
    } on TimeoutException {
      return _errorReport(
        transcriptHash: transcriptHash,
        productionDurationMs: productionDurationMs,
        shadowDurationMs: stopwatch.elapsedMilliseconds,
        errorType: ShadowErrorType.apiTimeout,
        message:
            'Shadow extraction timed out after ${_config.timeout.inSeconds}s',
      );
    } on TranslationDriftException catch (e) {
      return _errorReport(
        transcriptHash: transcriptHash,
        productionDurationMs: productionDurationMs,
        shadowDurationMs: stopwatch.elapsedMilliseconds,
        errorType: ShadowErrorType.translationFailed,
        message: 'Translation drift: ${e.message}',
      );
    } on MedGemmaExtractionException catch (e) {
      return _errorReport(
        transcriptHash: transcriptHash,
        productionDurationMs: productionDurationMs,
        shadowDurationMs: stopwatch.elapsedMilliseconds,
        errorType: ShadowErrorType.schemaValidationFailed,
        message: e.message,
      );
    } catch (e, s) {
      return _errorReport(
        transcriptHash: transcriptHash,
        productionDurationMs: productionDurationMs,
        shadowDurationMs: stopwatch.elapsedMilliseconds,
        errorType: ShadowErrorType.unknown,
        message: e.toString(),
        stackTrace: s.toString(),
      );
    }
  }

  ShadowDiffReport _errorReport({
    required String transcriptHash,
    required int productionDurationMs,
    required int shadowDurationMs,
    required ShadowErrorType errorType,
    required String message,
    String? stackTrace,
  }) {
    return ShadowDiffReport(
      timestamp: DateTime.now(),
      transcriptHash: transcriptHash,
      productionDurationMs: productionDurationMs,
      shadowDurationMs: shadowDurationMs,
      error: ShadowError(
        type: errorType,
        message: message,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<void> _persistReport(ShadowDiffReport report, String hash) async {
    try {
      final dir = Directory(_config.reportsPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File('${_config.reportsPath}/$hash.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report.toJson()),
      );
    } catch (_) {
      // Silently fail - persistence is non-critical
    }
  }

  String _computeHash(String text) {
    // Simple hash for correlation
    return text.hashCode.toRadixString(16).padLeft(8, '0');
  }
}
