import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/logger/log.dart';
import 'medical_lexicon_loader.dart';
import 'medical_transcript_post_processor.dart';
import 'medicalization/medicalization.dart';
import 'medicalization/transcript_cleaner.dart';
import 'note_ai_service.dart';
import 'structured_fields_parser.dart';
import 'structured_fields_prompt_v2.dart';
import 'structured_fields_schema_v1.dart';

// Dart-only replacement for kReleaseMode
const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');

/// Production implementation of NoteAIService using OpenAI APIs.
///
/// Architecture:
/// - Uses OpenAI Whisper API for audio transcription
/// - Uses OpenAI GPT-4 for structured medical note generation
/// - Clean separation between STT and LLM concerns
/// - No UI dependencies, no Firestore, pure business logic
///
/// Dependencies:
/// - Requires OpenAI API key via [OpenAIClient]
/// - Uses Dio for HTTP requests
///
/// Error handling:
/// - Throws [NoteAIException] for all domain-level errors
/// - Wraps API errors with user-friendly Spanish messages
class NoteAIServiceImpl implements NoteAIService {
  NoteAIServiceImpl({
    required OpenAIClient openAIClient,
    MedicalLexiconLoader? lexiconLoader,
    bool enablePhoneticMedicationMatching = false,
  }) : _openAIClient = openAIClient,
       _lexiconLoader = lexiconLoader ?? MedicalLexiconLoader(),
       _enablePhoneticMedicationMatching = enablePhoneticMedicationMatching {
    // A) Log Phase 1.5 status at construction time
    Log.info(
      '🔧 Phase 1.5 phonetic medication matching: '
      '${enablePhoneticMedicationMatching ? "ENABLED" : "DISABLED"}',
    );
  }

  final OpenAIClient _openAIClient;
  final MedicalLexiconLoader _lexiconLoader;

  /// Phase 1.5: Enable phonetic medication matching.
  /// When true, attempts to correct severely distorted medication names
  /// using phonetic similarity (e.g., "homem prazón" → "omeprazol").
  /// DISABLED by default for safety. Enable only after testing.
  final bool _enablePhoneticMedicationMatching;

  // ─────────────────────────────────────────────────────────────────────────
  // RATE LIMIT PROTECTION: Serialization lock to prevent concurrent calls
  // ─────────────────────────────────────────────────────────────────────────
  bool _transcriptionInFlight = false;

  /// Max retry attempts for rate limit errors (429)
  static const int _maxRetries = 2;

  /// Backoff delays in seconds for each retry attempt
  static const List<int> _retryDelaySeconds = [3, 8];

  /// Allowed field names that the AI can generate (LEGACY - v1 format).
  /// Any fields not in this list will be filtered out.
  /// @deprecated Use suggestStructuredFieldsV2 for new code.
  static const _allowedFields = {
    'motivoConsulta',
    'antecedentes',
    'exploracionFisicaOrl',
    'diagnostico',
    'planTratamiento',
    'resumen',
    'notaAdicional',
  };

  static const _allowedSurgicalFields = {
    'procedimientoRealizado',
    'diagnosticoPreoperatorio',
    'tecnicaQuirurgica',
    'hallazgosIntraoperatorios',
    'complicaciones',
    'diagnosticoPostoperatorio',
    'planPostoperatorio',
  };

  @override
  Future<String> transcribeAudio(String filePath) async {
    // ─────────────────────────────────────────────────────────────────────────
    // GUARD: Prevent concurrent transcription calls (serialization lock)
    // ─────────────────────────────────────────────────────────────────────────
    if (_transcriptionInFlight) {
      Log.warning('🔒 Transcription already in progress, rejecting new call');
      throw NoteAIException(
        'Transcripción en proceso. Intenta en unos segundos.',
      );
    }

    _transcriptionInFlight = true;
    Log.info('🔒 Transcription lock acquired');

    try {
      Log.info('🎙️ Starting audio transcription: $filePath');

      // Validate file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw NoteAIException('El archivo de audio no existe: $filePath');
      }

      // Validate file size (OpenAI limit is 25MB)
      final fileSize = await file.length();
      const maxFileSize = 25 * 1024 * 1024; // 25MB
      if (fileSize > maxFileSize) {
        throw NoteAIException(
          'El archivo de audio es demasiado grande. Máximo: 25MB',
        );
      }

      if (fileSize == 0) {
        throw NoteAIException('El archivo de audio está vacío');
      }

      Log.info('🎙️ File validated: $fileSize bytes');

      // Load medical prompt for Whisper context bias (cached)
      final medicalPrompt = await _lexiconLoader.getPrompt();
      if (medicalPrompt.isNotEmpty) {
        Log.info('🎙️ Using medical prompt (${medicalPrompt.length} chars)');
      }

      // ─────────────────────────────────────────────────────────────────────────
      // CALL WHISPER API WITH RETRY + BACKOFF FOR RATE LIMIT (429)
      // ─────────────────────────────────────────────────────────────────────────
      String? rawTranscript;
      int attempt = 0;
      Object? lastError;

      while (attempt <= _maxRetries) {
        try {
          Log.info(
            '🎙️ Whisper API call - attempt ${attempt + 1} of ${_maxRetries + 1}',
          );

          rawTranscript = await _openAIClient.transcribeAudio(
            filePath,
            prompt: medicalPrompt.isNotEmpty ? medicalPrompt : null,
          );

          // Success - exit retry loop
          Log.info('✅ Whisper API call successful on attempt ${attempt + 1}');
          break;
        } catch (e) {
          lastError = e;
          final errorMsg = e.toString().toLowerCase();

          // Log full error details for debugging
          Log.error('🛑 Whisper API error (attempt ${attempt + 1}): $e');

          // ─────────────────────────────────────────────────────────────────────
          // DETECT RATE LIMIT vs OTHER ERRORS
          // ─────────────────────────────────────────────────────────────────────
          final isRateLimit =
              errorMsg.contains('429') ||
              errorMsg.contains('rate limit') ||
              errorMsg.contains('rate_limit') ||
              errorMsg.contains('too many requests') ||
              errorMsg.contains('límite de solicitudes');

          // If NOT rate limit, do NOT retry - rethrow immediately
          if (!isRateLimit) {
            Log.warning('⚠️ Non-rate-limit error detected, not retrying');
            rethrow;
          }

          // If rate limit and retries remaining, apply backoff
          if (attempt < _maxRetries) {
            final delaySeconds = _retryDelaySeconds[attempt];
            Log.warning(
              '⏳ Rate limit hit. Waiting $delaySeconds seconds before retry ${attempt + 2}...',
            );
            await Future.delayed(Duration(seconds: delaySeconds));
            attempt++;
            continue;
          }

          // All retries exhausted
          Log.error(
            '❌ All ${_maxRetries + 1} attempts failed due to rate limit',
          );
          break;
        }
      }

      // ─────────────────────────────────────────────────────────────────────────
      // HANDLE FINAL RESULT
      // ─────────────────────────────────────────────────────────────────────────
      if (rawTranscript == null) {
        // All retries failed
        final errorStr = lastError?.toString() ?? 'Unknown error';
        Log.error('🛑 Final transcription failure: $errorStr');
        throw NoteAIException(
          'Error al transcribir: límite de solicitudes. Espera 10-20 segundos.',
        );
      }

      if (rawTranscript.trim().isEmpty) {
        throw NoteAIException(
          'La transcripción está vacía. Intenta grabar de nuevo.',
        );
      }

      Log.info('🎙️ Raw transcription: ${rawTranscript.length} chars');

      // Apply medical STT corrections (cached fixes + optional Phase 1.5)
      final fixes = await _lexiconLoader.getCommonFixes();

      // Load medications for Phase 1.5 if enabled
      Set<String>? medications;
      if (_enablePhoneticMedicationMatching) {
        medications = await _lexiconLoader.getMedications();
        // B) Log medication loading details
        Log.info('🔍 Phase 1.5 meds loaded: ${medications.length}');
        Log.info(
          '🔍 Contains "omeprazol": ${medications.contains("omeprazol")}',
        );
      } else {
        Log.info('🔍 Phase 1.5 DISABLED - skipping medication load');
      }

      // C) Log BEFORE post-processing (first 120 chars, safe for debug)
      final rawPreview = rawTranscript.length > 120
          ? '${rawTranscript.substring(0, 120)}...'
          : rawTranscript;
      Log.info('🔍 RAW TRANSCRIPT: "$rawPreview"');

      final transcript = postProcessMedicalTranscript(
        rawTranscript,
        fixes,
        knownMedications: medications,
        enablePhoneticMedicationMatching: _enablePhoneticMedicationMatching,
      );

      // C) Log AFTER post-processing (first 120 chars, safe for debug)
      final finalPreview = transcript.length > 120
          ? '${transcript.substring(0, 120)}...'
          : transcript;
      Log.info('🔍 FINAL TRANSCRIPT: "$finalPreview"');

      // D) Log whether corrections were applied
      if (transcript != rawTranscript) {
        Log.info('✅ Phase 1.5 or fixes applied corrections');
      } else {
        Log.info('⚪ No corrections applied (raw == final)');
      }

      Log.info('🎙️ Transcription successful: ${transcript.length} chars');
      return transcript;
    } on NoteAIException {
      rethrow;
    } catch (e) {
      Log.error('🎙️ Error transcribing audio: $e');
      throw NoteAIException('Error al transcribir el audio: ${e.toString()}');
    } finally {
      // ─────────────────────────────────────────────────────────────────────────
      // ALWAYS release the lock
      // ─────────────────────────────────────────────────────────────────────────
      _transcriptionInFlight = false;
      Log.info('🔓 Transcription lock released');
    }
  }

  @override
  Future<Map<String, String>> suggestStructuredFields(
    String rawTranscript,
  ) async {
    try {
      Log.info('🤖 Generating structured fields from transcript');

      if (rawTranscript.trim().isEmpty) {
        throw NoteAIException(
          'La transcripción está vacía. No se puede generar la nota.',
        );
      }

      // ─────────────────────────────────────────────────────────────────────────
      // AUDIT: Preserve original transcript for clinical safety review
      // Release: only HASH + LENGTH (no PHI in logs)
      // Debug: HASH + LENGTH + PREVIEW (first 150 chars)
      // ─────────────────────────────────────────────────────────────────────────
      Log.info('📝 [AUDIT] LENGTH=${rawTranscript.length}');
      Log.info('📝 [AUDIT] HASH=${rawTranscript.hashCode}');
      if (!kReleaseMode) {
        // Debug only: log preview for development/testing
        final preview = rawTranscript.length > 150
            ? '${rawTranscript.substring(0, 150)}...'
            : rawTranscript;
        Log.info('📝 [AUDIT][DEBUG] PREVIEW="$preview"');
      }

      // Build the LLM prompt
      final prompt = _buildStructuredFieldsPrompt(rawTranscript);

      // Call GPT-4 API
      final response = await _openAIClient.generateStructuredFields(prompt);

      // Parse and validate the response
      final fields = _parseAndValidateFields(response);

      Log.info(
        '🤖 Generated ${fields.length} fields: ${fields.keys.join(", ")}',
      );
      return fields;
    } on NoteAIException {
      rethrow;
    } catch (e) {
      Log.error('🤖 Error generating structured fields: $e');
      throw NoteAIException(
        'Error al generar campos estructurados: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<String, String>> suggestSurgicalFields(
    String rawTranscript,
  ) async {
    try {
      Log.info('🤖 Generating SURGICAL structured fields');

      if (rawTranscript.trim().isEmpty) {
        throw NoteAIException(
          'La transcripción está vacía. No se puede generar la nota quirúrgica.',
        );
      }

      // ─────────────────────────────────────────────────────────────────────────
      // AUDIT
      // ─────────────────────────────────────────────────────────────────────────
      Log.info('📝 [AUDIT][SURGICAL] LENGTH=${rawTranscript.length}');
      if (!kReleaseMode) {
        final preview = rawTranscript.length > 150
            ? '${rawTranscript.substring(0, 150)}...'
            : rawTranscript;
        Log.info('📝 [AUDIT][SURGICAL][DEBUG] PREVIEW="$preview"');
      }

      // Build the LLM prompt SPECIALIZED for SURGERY
      final prompt = _buildSurgicalFieldsPrompt(rawTranscript);

      // Call GPT-4 API
      final response = await _openAIClient.generateStructuredFields(prompt);

      // Parse and validate using SURGICAL allowed keys
      final fields = _parseAndValidateFields(
        response,
        allowedKeys: _allowedSurgicalFields,
      );

      if (fields.containsKey('complicaciones')) {
        fields['complicaciones'] = _sanitizeComplications(
          fields['complicaciones'] ?? '',
        );
      }

      Log.info('🤖 Generated surgical fields: ${fields.keys.join(", ")}');
      return fields;
    } on NoteAIException {
      rethrow;
    } catch (e) {
      Log.error('🤖 Error generating surgical fields: $e');
      throw NoteAIException(
        'Error al generar campos quirúrgicos: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> suggestStructuredFieldsV2(
    String rawTranscript,
  ) async {
    try {
      Log.info('🤖 [V2] Generating structured fields from transcript');

      if (rawTranscript.trim().isEmpty) {
        throw NoteAIException(
          'La transcripción está vacía. No se puede generar la nota.',
        );
      }

      // ─────────────────────────────────────────────────────────────────────────
      // AUDIT: Preserve original transcript for clinical safety review
      // ─────────────────────────────────────────────────────────────────────────
      Log.info('📝 [AUDIT][V2] LENGTH=${rawTranscript.length}');
      Log.info('📝 [AUDIT][V2] HASH=${rawTranscript.hashCode}');
      if (!kReleaseMode) {
        final preview = rawTranscript.length > 150
            ? '${rawTranscript.substring(0, 150)}...'
            : rawTranscript;
        Log.info('📝 [AUDIT][V2][DEBUG] PREVIEW="$preview"');
      }

      // Build prompts using v2 extraction-only prompt
      final userPrompt = StructuredFieldsPromptV2.buildUserPrompt(
        rawTranscript,
      );

      // ─────────────────────────────────────────────────────────────────────────
      // CALL GPT-4 API WITH STRUCTURED EXTRACTION
      // ─────────────────────────────────────────────────────────────────────────
      final response = await _openAIClient.generateStructuredFieldsV2(
        systemPrompt: StructuredFieldsPromptV2.systemPrompt,
        userPrompt: userPrompt,
        temperature: LLMTemperatureSettings.extraction,
      );

      // ─────────────────────────────────────────────────────────────────────────
      // PARSE AND VALIDATE RESPONSE
      // ─────────────────────────────────────────────────────────────────────────
      var parsed = StructuredFieldsParser.tryParse(response);

      if (parsed == null) {
        Log.warning('⚠️ [V2] Initial parse failed, attempting repair retry');
        parsed = await _attemptRepairRetry(response);
      }

      if (parsed == null) {
        Log.error(
          '❌ [V2] All parse attempts failed, falling back to empty schema',
        );
        parsed = getEmptySchemaV1();
      }

      // Validate structure
      final validationErrors = StructuredFieldsParser.validate(parsed);
      if (validationErrors.isNotEmpty) {
        Log.warning(
          '⚠️ [V2] Validation warnings: ${validationErrors.join(", ")}',
        );
      }

      Log.info(
        '🤖 [V2] Generated structured fields: ${parsed.keys.length} root keys',
      );

      return parsed;
    } on NoteAIException {
      rethrow;
    } catch (e) {
      Log.error('🤖 [V2] Error generating structured fields: $e');
      throw NoteAIException(
        'Error al generar campos estructurados: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // V3: LOCAL MEDICALIZATION → LLM EXTRACTION
  // ─────────────────────────────────────────────────────────────────────────

  /// Medicalization service instance (lazy-initialized).
  MedicalizationService? _medicalizationService;

  /// Last medicalization output (for debugging/traceability).
  MedicalizationOutput? _lastMedicalizationOutput;

  /// Generates structured fields with LOCAL clinical medicalization.
  ///
  /// Pipeline:
  /// 1. Raw transcript → LocalMedicalizationService (dictionary + matcher + negation)
  /// 2. Medicalized text → LLM (v2 extraction prompt)
  /// 3. LLM → Structured JSON (schema v1)
  ///
  /// The LLM only structures/formats - all term transformation is LOCAL and deterministic.
  ///
  /// Returns the same schema v1 JSON for backward compatibility with UI.
  ///
  /// Feature flag: Set [enableMedicalization] to false to skip local processing.
  Future<Map<String, dynamic>> suggestStructuredFieldsV3(
    String rawTranscript, {
    bool enableMedicalization = true,
  }) async {
    try {
      Log.info('🤖 [V3] Generating structured fields (LOCAL medicalization)');

      if (rawTranscript.trim().isEmpty) {
        throw NoteAIException(
          'La transcripción está vacía. No se puede generar la nota.',
        );
      }

      // ─────────────────────────────────────────────────────────────────────────
      // AUDIT: Preserve original transcript for clinical safety review
      // ─────────────────────────────────────────────────────────────────────────
      Log.info('📝 [AUDIT][V3] RAW_LENGTH=${rawTranscript.length}');
      Log.info('📝 [AUDIT][V3] RAW_HASH=${rawTranscript.hashCode}');

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 1: LOCAL MEDICALIZATION (deterministic, no LLM)
      // ─────────────────────────────────────────────────────────────────────────

      if (enableMedicalization) {
        // Initialize medicalization service (lazy, singleton)
        _medicalizationService ??= MedicalizationServiceFactory.create();

        // Apply local medicalization
        final output = await _medicalizationService!.medicalize(rawTranscript);
        _lastMedicalizationOutput = output;

        // Log transformation stats
        Log.info(
          '📖 [V3] LOCAL medicalization: '
          '${output.appliedMappings.length} terms replaced, '
          '${output.negationsPreserved} negations preserved',
        );

        if (!kReleaseMode && output.appliedMappings.isNotEmpty) {
          // Debug: log first 3 mappings applied
          final preview = output.appliedMappings
              .take(3)
              .map(
                (m) =>
                    '"${m.original}"→"${m.clinical}"${m.isNegated ? " [NEG]" : ""}',
              );
          Log.info('📖 [V3][DEBUG] Sample: ${preview.join(", ")}');
        }
      } else {
        Log.info('📖 [V3] Medicalization DISABLED, using raw transcript');
        _lastMedicalizationOutput = null;
      }

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 2: CLEAN NORMALIZED TRANSCRIPT (remove fillers/vacillations)
      // ─────────────────────────────────────────────────────────────────────────
      String? cleanedNormalized;
      if (enableMedicalization && _lastMedicalizationOutput != null) {
        // Clean the medicalized text to remove fillers before LLM
        cleanedNormalized = cleanTranscriptForExtraction(
          _lastMedicalizationOutput!.medicalizedText,
        );

        if (!kReleaseMode) {
          final beforeLen = _lastMedicalizationOutput!.medicalizedText.length;
          final afterLen = cleanedNormalized.length;
          if (beforeLen != afterLen) {
            Log.info(
              '🧹 [V3] Transcript cleaned: $beforeLen → $afterLen chars '
              '(removed ${beforeLen - afterLen} chars of fillers)',
            );
          }
        }
      }

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 3: LLM EXTRACTION WITH DUAL TRANSCRIPT
      // - NORMALIZADO: Use for clinical terminology in output (cleaned)
      // - ORIGINAL: Use as source of evidence / traceability (untouched)
      // ─────────────────────────────────────────────────────────────────────────
      final String userPrompt;

      if (enableMedicalization && cleanedNormalized != null) {
        // Pass BOTH transcripts to LLM (normalized is cleaned)
        userPrompt = _buildDualTranscriptPrompt(
          original: rawTranscript,
          normalized: cleanedNormalized,
        );
      } else {
        // Fallback to single transcript
        userPrompt = StructuredFieldsPromptV2.buildUserPrompt(rawTranscript);
      }

      final response = await _openAIClient.generateStructuredFieldsV2(
        systemPrompt: StructuredFieldsPromptV2.systemPrompt,
        userPrompt: userPrompt,
        temperature: LLMTemperatureSettings.extraction,
      );

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 4: PARSE AND VALIDATE RESPONSE
      // ─────────────────────────────────────────────────────────────────────────
      var parsed = StructuredFieldsParser.tryParse(response);

      if (parsed == null) {
        Log.warning('⚠️ [V3] Initial parse failed, attempting repair retry');
        parsed = await _attemptRepairRetry(response);
      }

      if (parsed == null) {
        Log.error(
          '❌ [V3] All parse attempts failed, falling back to empty schema',
        );
        parsed = getEmptySchemaV1();
      }

      // Validate structure
      final validationErrors = StructuredFieldsParser.validate(parsed);
      if (validationErrors.isNotEmpty) {
        Log.warning(
          '⚠️ [V3] Validation warnings: ${validationErrors.join(", ")}',
        );
      }

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 5: SANITIZE PARSED FIELDS (remove non-informative content)
      // ─────────────────────────────────────────────────────────────────────────
      // This deterministic post-processing removes:
      // - "no sé", "no que yo sepa", "desconozco" from antecedentes
      // - Empty/non-informative entries from arrays
      // - Residual fillers from text fields
      final sanitized = sanitizeStructuredFieldsV1(parsed);
      final meta = Map<String, dynamic>.from(
        sanitized['metadata'] as Map? ?? <String, dynamic>{},
      );
      meta['negatedFindingsCount'] =
          _lastMedicalizationOutput?.negatedFindings.length ?? 0;
      meta['pipelineUsed'] = 'v3_local';
      sanitized['metadata'] = meta;

      if (!kReleaseMode) {
        // Log any fields that were nulled by sanitizer
        _logSanitizationChanges(parsed, sanitized);
      }

      Log.info(
        '🤖 [V3] Generated medicalized fields: ${sanitized.keys.length} root keys',
      );

      return sanitized;
    } on NoteAIException {
      rethrow;
    } catch (e) {
      Log.error('🤖 [V3] Error generating structured fields: $e');
      throw NoteAIException(
        'Error al generar campos estructurados: ${e.toString()}',
      );
    }
  }

  /// Returns the last medicalization output for debugging/traceability.
  ///
  /// Returns null if medicalization was disabled or not yet run.
  MedicalizationOutput? get lastMedicalizationOutput =>
      _lastMedicalizationOutput;

  /// Logs differences between parsed and sanitized fields (debug only).
  void _logSanitizationChanges(
    Map<String, dynamic> parsed,
    Map<String, dynamic> sanitized,
  ) {
    final changes = <String>[];

    // Check antecedentes subfields
    if (parsed['antecedentes'] is Map && sanitized['antecedentes'] is Map) {
      final parsedAnt = parsed['antecedentes'] as Map;
      final sanitizedAnt = sanitized['antecedentes'] as Map;

      for (final key in parsedAnt.keys) {
        if (parsedAnt[key] != null && sanitizedAnt[key] == null) {
          changes.add('antecedentes.$key');
        }
      }
    }

    // Check top-level fields
    for (final key in [
      'motivo_consulta',
      'padecimiento_actual',
      'notas_adicionales',
    ]) {
      if (parsed[key] != null && sanitized[key] == null) {
        changes.add(key);
      }
    }

    if (changes.isNotEmpty) {
      Log.info('🧹 [V3] Sanitizer nulled fields: ${changes.join(", ")}');
    }
  }

  /// Builds a user prompt that includes BOTH transcripts.
  ///
  /// - NORMALIZADO: Pre-processed text with clinical terminology applied locally
  /// - ORIGINAL: Raw transcript for evidence/traceability
  ///
  /// Instructs the LLM to:
  /// - Use NORMALIZADO for clinical terms in output
  /// - Reference ORIGINAL when quoting evidence
  String _buildDualTranscriptPrompt({
    required String original,
    required String normalized,
  }) {
    return '''
TRANSCRIPCIÓN NORMALIZADA (usar para terminología clínica):
"""
$normalized
"""

TRANSCRIPCIÓN ORIGINAL (usar como fuente de evidencia):
"""
$original
"""

INSTRUCCIONES ESPECIALES:
- Para ESCRIBIR el contenido de cada campo, usa la versión NORMALIZADA (ya tiene terminología clínica).
- La TRANSCRIPCIÓN ORIGINAL es la fuente de verdad para HECHOS (síntomas, antecedentes, tiempos, medicamentos, dosis).
- Si hay discrepancia entre ORIGINAL y NORMALIZADA, usa la NORMALIZADA SOLO para el término clínico equivalente, pero SOLO si el hecho existe explícitamente en la ORIGINAL.
- Preserva todas las negaciones tal como aparecen ("niega", "sin", "no") y NO las conviertas en afirmaciones.

REGLA DE VERACIDAD (CRÍTICA):
- NO agregues ningún dato (síntoma, antecedente, medicamento, dosis, tiempo) que no esté explícito en la ORIGINAL.
- Si una frase solo aparece en la NORMALIZADA pero NO está respaldada por la ORIGINAL, NO la uses.
- Si hay duda o ambigüedad, conserva el texto original o usa null/[] según corresponda.

REGLA ANTI-BASURA (CRÍTICA):
- Frases de desconocimiento NO son contenido clínico. Si el paciente dice "no sé", "no que yo sepa", "desconozco", "ninguno", "nada" → usar null en ese campo, NO incluir esa frase como valor.
- Muletillas y vacilaciones ("eh", "este", "mmm", "o sea", "pues", "sí no sí no", repeticiones) NO deben aparecer en el JSON final. Ignóralas completamente.
- Si un campo quedaría con SOLO frases no-informativas → usar null.

SCHEMA JSON REQUERIDO (incluir TODAS las claves):
$kSchemaJsonExample

INSTRUCCIONES DE MAPEO:

1. motivo_consulta: Razón principal de la visita (síntoma guía).

2. padecimiento_actual: Evolución temporal del problema (inicio, duración, progresión, tratamientos previos).

3. antecedentes:
   - heredofamiliares: Enfermedades en familia → null si "no sé"/"desconozco"
   - no_patologicos: Hábitos (tabaco, alcohol, ejercicio) → null si "no sé"
   - patologicos: Enfermedades crónicas del paciente → null si "ninguno"/"nada"
   - alergias: Lista de alergias mencionadas → [] si "ninguna"/"no sé"
   - medicamentos_habituales: Lista de medicamentos actuales → [] si "ninguno"
   - quirurgicos: Cirugías previas → null si "ninguna"/"no que yo sepa"
   - gineco_obstetricos: Solo si aplica → null si no aplica o desconoce

4. exploracion_orl:
   - otoscopia, rinoscopia, orofaringe, cuello, laringoscopia

5. diagnostico:
   - texto: El diagnóstico mencionado
   - tipo: "definitivo"/"presuntivo"/"diferencial"

6. plan_tratamiento: Indicaciones terapéuticas.

7. estudios_indicados: Lista de estudios solicitados.

8. notas_adicionales: Otra info relevante (NO incluir muletillas ni basura).

9. contradicciones: Si el médico se corrigió.

10. metadata: idioma:"es", fuente:"dictado", version_schema:"1.0.0"

IMPORTANTE:
- Si no se menciona un campo → usar null (o [] para arrays)
- Si el paciente dice "no sé"/"desconozco" → usar null (NO poner esa frase)
- Preservar negaciones clínicas REALES ("niega fiebre", "sin dolor") ≠ desconocimiento
- NO agregar información que no esté en el dictado

Responde SOLO con el JSON, sin texto adicional.''';
  }

  /// Attempts to repair invalid JSON by sending it back to GPT with repair prompt.
  ///
  /// Returns parsed result or null if repair also fails.
  Future<Map<String, dynamic>?> _attemptRepairRetry(String invalidJson) async {
    try {
      Log.info('🔧 [V2] Attempting JSON repair retry');

      final errors = <String>[
        'JSON parsing failed or missing required structure',
      ];
      final repairPrompt = StructuredFieldsPromptV2.buildRepairPrompt(
        invalidJson,
        errors,
      );

      final response = await _openAIClient.generateStructuredFieldsV2(
        systemPrompt:
            'Eres un corrector de JSON. Corrige el JSON para que cumpla el schema.',
        userPrompt: repairPrompt,
        temperature: LLMTemperatureSettings.repair,
      );

      final parsed = StructuredFieldsParser.tryParse(response);

      if (parsed != null) {
        Log.info('✅ [V2] Repair retry successful');
        return parsed;
      }

      Log.warning('⚠️ [V2] Repair retry also failed');
      return null;
    } catch (e) {
      Log.error('❌ [V2] Repair retry error: $e');
      return null;
    }
  }

  /// Builds the LLM prompt for structured field generation.
  ///
  /// STRATEGY C: Correction + Structuring in a single GPT call.
  /// Optimized for production: ~50% fewer tokens than v1.
  /// v2: Optimized for medical interviews (patient voice vs clinical voice).
  ///
  /// Safety rules:
  /// - Only correct with HIGH certainty (>90%)
  /// - If in doubt, preserve original text
  /// - NEVER infer diagnoses
  /// - ALWAYS include all 7 keys (use "" if no data)
  String _buildStructuredFieldsPrompt(String rawTranscript) {
    return '''
Asistente médico ORL. Tarea: corregir errores STT + estructurar en JSON.

PASO 1: CORRECCIÓN STT (solo si certeza >90%, si hay duda NO corrijas)
- Medicamentos: "omeprasol"→"omeprazol", "metorfina"→"metformina"
- Dosis: "20 de omeprazol"→"omeprazol 20 mg" (solo si unidad es obvia)
- Abreviaturas: tx→tratamiento, dx→diagnóstico

REGLA CRÍTICA: Si hay CUALQUIER duda, conserva el texto original.
PROHIBIDO: Inventar diagnósticos, medicamentos o dosis.

PASO 2: REDACCIÓN CLÍNICA
- 1ª persona ("me duele", "tengo", "siento") = voz del PACIENTE → usar "refiere", "menciona", "niega".
- NO convertir quejas subjetivas en afirmaciones clínicas absolutas.
- motivoConsulta = síntoma guía (razón principal de la consulta).
- antecedentes incluye PADECIMIENTO ACTUAL = evolución temporal (inicio, duración, progresión).
- Si diagnóstico proviene SOLO de entrevista (sin exploración explícita), usar "sugestivo de", "probable", "a descartar".

PASO 3: JSON con TODAS estas claves (usar "" si no hay datos):
- motivoConsulta
- antecedentes (HEREDOFAMILIARES: / NO PATOLOGICOS: / PATOLOGICOS: / PADECIMIENTO ACTUAL:)
- exploracionFisicaOrl (OTOSCOPIA: / RINOSCOPIA: / OROFARINGE: / CUELLO: / LARINGOSCOPIA:)
- diagnostico
- planTratamiento
- resumen
- notaAdicional

IMPORTANTE: Incluir SIEMPRE las 7 claves. Si no hay info, usar "".

TRANSCRIPCIÓN:
"""
$rawTranscript
"""

JSON:''';
  }

  /// Builds prompt for SURGICAL NOTE.
  /// Specialized for extracting surgery-specific fields.
  String _buildSurgicalFieldsPrompt(String rawTranscript) {
    return '''
Asistente experto en documentación quirúrgica ORL.
Tarea: Extraer un JSON ESTRICTO a partir del dictado. NO inventes datos.

REGLAS ESTRICTAS (anti-alucinación):
0) EVIDENCIA: Solo llenes un campo si hay evidencia explícita en el dictado.
   - Si no hay evidencia, usa "".
   - NO completes con frases estándar ("sepsia", "campos", "hemostasia") si no se dictaron.

1) SEPARAR ACCIÓN vs OBSERVACIÓN (MUY IMPORTANTE):
   - ACCIÓN (lo que se HIZO) -> tecnicaQuirurgica
   - OBSERVACIÓN (lo que se VIO) -> hallazgosIntraoperatorios
   - Si una oración contiene ambas, DIVIDE la información:
     Ej: "Al elevar colgajo se observa desviación y se reseca cartílago"
     -> tecnica: "Elevación de colgajo. Resección de cartílago."
     -> hallazgos: "Desviación septal."

2) PROCEDIMIENTO REALIZADO:
   - Si se menciona explícitamente, úsalo.
   - Si NO se menciona, SOLO infiere si es inequívoco por la técnica.
     En ese caso escribe: "<procedimiento> (inferido)".
   - Si no es inequívoco, deja "".

3) DIAGNÓSTICO PREOP:
   - Extrae la razón de la cirugía si se dictó (ej: "Desviación septal obstructiva").
   - Si no se dictó, "".

4) TÉCNICA QUIRÚRGICA (LO QUE SE HIZO):
   - Incluye: incisiones, disecciones, resecciones, suturas, cauterio, instrumentación,
     materiales (Vicryl, Silastic), infiltración/anestésico local, colocación de férula/taponamiento.
   - Si dice "técnica habitual" o "técnica estándar", transcribir tal cual. NO expandas.

5) HALLAZGOS INTRAOPERATORIOS (LO QUE SE VIO):
   - Incluye: anatomía normal o alterada, patología, secreción, pólipos, colesteatoma, etc.
   - Incluye hallazgos negativos relevantes: "sin masas", "todo libre", "no se palpan adenoides".
   - Sangrado estimado (ej: "50 cc") va aquí si se menciona.

6) COMPLICACIONES:
   - Solo incidentes/eventos adversos explícitos (desgarro, lesión, sangrado de vaso, bradicardia, etc).
   - Si el dictado dice "sin complicaciones", "sin incidentes", "sin eventualidades", "sin novedad",
     "saldo blanco", entonces complicaciones = "" (vacío).

7) DIAGNÓSTICO POSTOP:
   - SOLO si se dictó explícitamente. NO repitas preop si no se mencionó.
   - Si no se dictó, "".

8) PLAN POSTOP:
   - Indicaciones de alta, antibióticos, taponamiento, curación, cita, patología, recuperación, etc.
   - Si no se dictó, "".

FORMATO:
- Devuelve SOLO un JSON válido (sin markdown, sin texto extra).
- Usa exactamente estas claves, TODAS presentes ("" si no hay datos):

{
  "procedimientoRealizado": "",
  "diagnosticoPreoperatorio": "",
  "tecnicaQuirurgica": "",
  "hallazgosIntraoperatorios": "",
  "complicaciones": "",
  "diagnosticoPostoperatorio": "",
  "planPostoperatorio": ""
}

TRANSCRIPCIÓN:
"""
$rawTranscript
"""
''';
  }

  String _sanitizeComplications(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return '';
    const negatives = [
      'sin complicaciones',
      'sin incidentes',
      'sin eventualidades',
      'sin novedad',
      'saldo blanco',
      'ninguna',
      'no hubo complicaciones',
    ];
    for (final n in negatives) {
      if (v.contains(n)) return '';
    }
    return value.trim();
  }

  @override
  Future<String> suggestTreatmentPlan({
    required String diagnostico,
    String? motivo,
    String? padecimientoActual,
    String? exploracionOrl,
  }) async {
    try {
      Log.info('💊 Generating treatment plan suggestion');

      if (diagnostico.trim().isEmpty) {
        throw NoteAIException(
          'Se requiere un diagnóstico para generar el plan de tratamiento.',
        );
      }

      // Build compact context string
      final prompt = _buildTreatmentPlanPrompt(
        diagnostico: diagnostico,
        motivo: motivo,
        padecimientoActual: padecimientoActual,
        exploracionOrl: exploracionOrl,
      );

      // Call GPT-4 API for treatment plan
      final response = await _openAIClient.generateTreatmentPlan(prompt);

      if (response.trim().isEmpty) {
        throw NoteAIException('No se pudo generar un plan. Intenta de nuevo.');
      }

      Log.info('💊 Treatment plan generated: ${response.length} chars');
      return response;
    } on NoteAIException {
      rethrow;
    } catch (e) {
      Log.error('💊 Error generating treatment plan: $e');
      throw NoteAIException(
        'Error al generar plan de tratamiento: ${e.toString()}',
      );
    }
  }

  /// Builds prompt for treatment plan generation.
  ///
  /// CLINICAL SAFETY RULES:
  /// - NO inventar alergias, comorbilidades, embarazo, peso, edad
  /// - Dosis genéricas si faltan datos (según peso/edad)
  /// - Siempre incluir disclaimer de revisión clínica
  /// - Idioma: Español clínico
  String _buildTreatmentPlanPrompt({
    required String diagnostico,
    String? motivo,
    String? padecimientoActual,
    String? exploracionOrl,
  }) {
    final contextParts = <String>[];

    contextParts.add('DIAGNÓSTICO: $diagnostico');

    if (motivo != null && motivo.trim().isNotEmpty) {
      contextParts.add('MOTIVO: $motivo');
    }
    if (padecimientoActual != null && padecimientoActual.trim().isNotEmpty) {
      contextParts.add('PADECIMIENTO: $padecimientoActual');
    }
    if (exploracionOrl != null && exploracionOrl.trim().isNotEmpty) {
      contextParts.add('EXPLORACIÓN ORL: $exploracionOrl');
    }

    final context = contextParts.join('\n');

    return '''
Asistente médico ORL. Genera plan de tratamiento.

REGLAS DE SEGURIDAD CLÍNICA:
- NO inventar: alergias, comorbilidades, embarazo, peso, edad
- Si faltan datos, usar dosis genéricas ("según peso/edad")
- Usar frases tipo "valorar", "considerar" si hay incertidumbre
- Solo tratamientos estándar para ORL

CONTEXTO CLÍNICO:
$context

Genera plan conciso (máx 200 palabras):
1. Tratamiento farmacológico (si aplica)
2. Medidas generales
3. Seguimiento/cita control

Al final incluir: "(Sugerencia: revisar contra guías y criterio clínico)"

PLAN:''';
  }

  /// Parses the LLM response and validates field names.
  ///
  /// Filters out any fields not in [_allowedFields].
  /// Ensures all values are strings.
  Map<String, String> _parseAndValidateFields(
    String response, {
    Set<String> allowedKeys = _allowedFields,
  }) {
    try {
      // Clean the response (remove markdown code blocks if present)
      String cleaned = response.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      // Parse JSON
      final dynamic decoded = jsonDecode(cleaned);

      if (decoded is! Map) {
        throw NoteAIException(
          'Respuesta inválida de la IA: se esperaba un objeto JSON',
        );
      }

      // Filter and validate fields
      final Map<String, String> validatedFields = {};

      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final value = entry.value;

        // Only keep allowed fields
        if (!allowedKeys.contains(key)) {
          Log.warning('🤖 Filtering out invalid field: $key');
          continue;
        }

        // Accept string values (including empty strings for missing data)
        if (value is String) {
          validatedFields[key] = value.trim();
        }
      }

      return validatedFields;
    } on FormatException catch (e) {
      Log.error('🤖 JSON parsing error: $e');
      throw NoteAIException(
        'Error al parsear la respuesta de la IA. Por favor intenta de nuevo.',
      );
    }
  }
}

/// OpenAI API client for Whisper and GPT-4.
///
/// Encapsulates all OpenAI API communication.
/// Uses Dio for HTTP requests.
class OpenAIClient {
  OpenAIClient({required this.apiKey, Dio? dio}) : _dio = dio ?? Dio();

  final String apiKey;
  final Dio _dio;

  static const _whisperEndpoint =
      'https://api.openai.com/v1/audio/transcriptions';
  static const _chatEndpoint = 'https://api.openai.com/v1/chat/completions';

  /// Whisper model to use for transcription.
  /// whisper-1 is the latest available model.
  static const _whisperModel = 'whisper-1';

  /// GPT model to use for structured field generation.
  /// gpt-4o is recommended for best quality/speed balance.
  /// Alternatives: gpt-4-turbo, gpt-4, gpt-3.5-turbo
  static const _gptModel = 'gpt-4o';

  /// Transcribes an audio file using OpenAI Whisper API.
  ///
  /// [filePath] must be a local file path to an audio file.
  /// Supported formats: m4a, mp3, wav, webm, etc.
  ///
  /// [prompt] Optional initial prompt for Whisper context bias.
  /// Used to improve recognition of medical terminology.
  /// See: https://platform.openai.com/docs/guides/speech-to-text/prompting
  ///
  /// Returns raw transcript text in Spanish.
  Future<String> transcribeAudio(String filePath, {String? prompt}) async {
    try {
      // Prepare multipart form data
      final Map<String, dynamic> formMap = {
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
        'model': _whisperModel,
        'language': 'es', // Spanish
        'response_format': 'text', // Plain text response
      };

      // Add medical prompt for context bias if provided
      if (prompt != null && prompt.trim().isNotEmpty) {
        formMap['prompt'] = prompt;
      }

      final formData = FormData.fromMap(formMap);

      // Make API request
      final response = await _dio.post(
        _whisperEndpoint,
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        // Response is plain text when response_format is 'text'
        return response.data.toString();
      } else if (response.statusCode == 401) {
        throw NoteAIException(
          'Error de autenticación con OpenAI. Verifica tu API key.',
        );
      } else if (response.statusCode == 429) {
        throw NoteAIException(
          'Límite de solicitudes excedido. Intenta más tarde.',
        );
      } else {
        final errorMsg =
            response.data?['error']?['message'] ?? 'Error desconocido';
        throw NoteAIException('Error de OpenAI: $errorMsg');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NoteAIException(
          'Tiempo de espera agotado. Verifica tu conexión a internet.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw NoteAIException(
          'No se pudo conectar con OpenAI. Verifica tu conexión a internet.',
        );
      }

      // DIAGNOSTIC LOG for 500/400 errors
      if (e.response != null) {
        Log.error(
          '🛑 STT ERROR (${e.response?.statusCode}): ${e.response?.data}',
        );
      }

      rethrow;
    }
  }

  /// Generates structured medical note fields using GPT-4.
  ///
  /// [prompt] should contain the full instruction and raw transcript.
  ///
  /// Returns the raw JSON string from the model.
  ///
  /// STRATEGY C: The prompt now includes STT correction instructions,
  /// so GPT-4 corrects transcription errors AND structures in one call.
  ///
  /// @deprecated Use generateStructuredFieldsV2 for new code.
  Future<String> generateStructuredFields(String prompt) async {
    try {
      final requestBody = {
        'model': _gptModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'Eres un asistente médico ORL. '
                'Tu trabajo: 1) Corregir errores STT (medicamentos, dosis), '
                '2) Estructurar en JSON. Solo corrige con alta certeza. '
                'Nunca inventes datos.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.3, // Lower temperature for more deterministic output
        'max_tokens': 2000,
        'response_format': {'type': 'json_object'}, // Enforce JSON output
      };

      final response = await _dio.post(
        _chatEndpoint,
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'];
        return content.toString();
      } else if (response.statusCode == 401) {
        throw NoteAIException(
          'Error de autenticación con OpenAI. Verifica tu API key.',
        );
      } else if (response.statusCode == 429) {
        throw NoteAIException(
          'Límite de solicitudes excedido. Intenta más tarde.',
        );
      } else {
        final errorMsg =
            response.data?['error']?['message'] ?? 'Error desconocido';
        throw NoteAIException('Error de OpenAI: $errorMsg');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NoteAIException(
          'Tiempo de espera agotado. Verifica tu conexión a internet.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw NoteAIException(
          'No se pudo conectar con OpenAI. Verifica tu conexión a internet.',
        );
      }
      rethrow;
    }
  }

  /// Generates structured medical note fields using GPT-4 with schema v1.
  ///
  /// [systemPrompt] - System instructions for the model.
  /// [userPrompt] - User prompt with transcript and schema.
  /// [temperature] - Temperature setting (0.0-1.0). Lower = more deterministic.
  /// [maxTokens] - Maximum tokens to generate. Default: 1500 (typical note).
  /// [model] - Model override. If null, uses default _gptModel.
  ///
  /// Returns the raw JSON string from the model.
  Future<String> generateStructuredFieldsV2({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.0, // 0 for maximum determinism and speed
    int maxTokens =
        1500, // Reduced from 3000 - typical note is under 1000 tokens
    String? model,
  }) async {
    // Use provided model or fallback to default
    final effectiveModel = model ?? _gptModel;
    var effectiveMaxTokens = maxTokens;
    var attempt = 0;
    const maxAttempts = 2;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        final requestBody = {
          'model': effectiveModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': temperature,
          'max_tokens': effectiveMaxTokens,
          'response_format': {'type': 'json_object'},
        };

        final response = await _dio.post(
          _chatEndpoint,
          data: requestBody,
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            validateStatus: (status) => status! < 500,
          ),
        );

        if (response.statusCode == 200) {
          final content = response.data['choices'][0]['message']['content'];
          return content.toString();
        } else if (response.statusCode == 401) {
          throw NoteAIException(
            'Error de autenticación con OpenAI. Verifica tu API key.',
          );
        } else if (response.statusCode == 429) {
          throw NoteAIException(
            'Límite de solicitudes excedido. Intenta más tarde.',
          );
        } else if (response.statusCode == 400) {
          final errorMsg =
              response.data?['error']?['message'] ?? 'Error desconocido';

          // Check for context length / max tokens error and retry with lower tokens
          if (errorMsg.contains('maximum context length') ||
              errorMsg.contains('max_tokens') ||
              errorMsg.contains('context_length_exceeded')) {
            if (attempt < maxAttempts) {
              // Reduce max_tokens by 40% and retry
              effectiveMaxTokens = (effectiveMaxTokens * 0.6).round().clamp(
                256,
                4000,
              );
              Log.warning(
                '[OpenAIClient] Context length error, retrying with max_tokens=$effectiveMaxTokens',
              );
              continue;
            }
          }
          throw NoteAIException('Error de OpenAI: $errorMsg');
        } else {
          final errorMsg =
              response.data?['error']?['message'] ?? 'Error desconocido';
          throw NoteAIException('Error de OpenAI: $errorMsg');
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          throw NoteAIException(
            'Tiempo de espera agotado. Verifica tu conexión a internet.',
          );
        } else if (e.type == DioExceptionType.connectionError) {
          throw NoteAIException(
            'No se pudo conectar con OpenAI. Verifica tu conexión a internet.',
          );
        }
        rethrow;
      }
    }

    // Should not reach here
    throw NoteAIException('Error inesperado después de $maxAttempts intentos');
  }

  /// Generates a treatment plan suggestion using GPT-4.
  ///
  /// [prompt] should contain clinical context and safety rules.
  ///
  /// Returns plain text (NOT JSON) with the treatment plan.
  /// Optimized for short responses (~200 words max).
  Future<String> generateTreatmentPlan(String prompt) async {
    try {
      final requestBody = {
        'model': _gptModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'Eres un asistente médico ORL. '
                'Generas planes de tratamiento concisos y seguros. '
                'Nunca inventes datos del paciente (alergias, peso, edad). '
                'Usa dosis genéricas si faltan datos.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.4,
        'max_tokens': 500, // Short response for treatment plan
      };

      final response = await _dio.post(
        _chatEndpoint,
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'];
        return content.toString().trim();
      } else if (response.statusCode == 401) {
        throw NoteAIException(
          'Error de autenticación con OpenAI. Verifica tu API key.',
        );
      } else if (response.statusCode == 429) {
        throw NoteAIException(
          'Límite de solicitudes excedido. Intenta más tarde.',
        );
      } else {
        final errorMsg =
            response.data?['error']?['message'] ?? 'Error desconocido';
        throw NoteAIException('Error de OpenAI: $errorMsg');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NoteAIException(
          'Tiempo de espera agotado. Verifica tu conexión a internet.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw NoteAIException(
          'No se pudo conectar con OpenAI. Verifica tu conexión a internet.',
        );
      }
      rethrow;
    }
  }

  /// Generates plain text response using Chat Completion API.
  ///
  /// Flexible method that supports custom [model], [temperature], and
  /// separate [systemPrompt] and [userPrompt].
  ///
  /// [maxTokens] - Optional limit on output tokens. If null, API default is used.
  ///               For SOAP notes, 1500-2000 is typically sufficient.
  ///
  /// Does NOT enforce JSON mode or specific response format.
  /// Returns the assistant's content string directly.
  Future<String> generateText({
    required String systemPrompt,
    required String userPrompt,
    String model = 'gpt-4o',
    double temperature = 0.2,
    int? maxTokens,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': temperature,
      };

      // Add max_tokens if specified (limits output length and can reduce latency)
      if (maxTokens != null) {
        requestBody['max_tokens'] = maxTokens;
      }

      final response = await _dio.post(
        _chatEndpoint,
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'];
        return content.toString();
      } else if (response.statusCode == 401) {
        throw NoteAIException(
          'Error de autenticación con OpenAI. Verifica tu API key.',
        );
      } else if (response.statusCode == 429) {
        throw NoteAIException(
          'Límite de solicitudes excedido. Intenta más tarde.',
        );
      } else {
        final errorMsg =
            response.data?['error']?['message'] ?? 'Error desconocido';
        throw NoteAIException('Error de OpenAI: $errorMsg');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NoteAIException(
          'Tiempo de espera agotado. Verifica tu conexión a internet.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw NoteAIException(
          'No se pudo conectar con OpenAI. Verifica tu conexión a internet.',
        );
      }
      rethrow;
    }
  }
}

/// Custom exception for AI service errors.
///
/// Contains user-friendly error messages in Spanish.
class NoteAIException implements Exception {
  NoteAIException(this.message);

  final String message;

  @override
  String toString() => message;
}
