// lib/src/features/medical_notes/application/note_ai_service_impl.dart

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

import '../../../core/logger/log.dart';
import 'medical_lexicon_loader.dart';
import 'medical_transcript_post_processor.dart';
import 'note_ai_service.dart';

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
  })  : _openAIClient = openAIClient,
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

  /// Allowed field names that the AI can generate.
  /// Any fields not in this list will be filtered out.
  static const _allowedFields = {
    'motivoConsulta',
    'antecedentes',
    'exploracionFisicaOrl',
    'diagnostico',
    'planTratamiento',
    'resumen',
    'notaAdicional',
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
        throw NoteAIException(
          'El archivo de audio no existe: $filePath',
        );
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
        throw NoteAIException(
          'El archivo de audio está vacío',
        );
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
          Log.info('🎙️ Whisper API call - attempt ${attempt + 1} of ${_maxRetries + 1}');

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
          final isRateLimit = errorMsg.contains('429') ||
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
          Log.error('❌ All ${_maxRetries + 1} attempts failed due to rate limit');
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
      throw NoteAIException(
        'Error al transcribir el audio: ${e.toString()}',
      );
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
        throw NoteAIException(
          'No se pudo generar un plan. Intenta de nuevo.',
        );
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
  Map<String, String> _parseAndValidateFields(String response) {
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
        if (!_allowedFields.contains(key)) {
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
  OpenAIClient({
    required this.apiKey,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final String apiKey;
  final Dio _dio;

  static const _whisperEndpoint =
      'https://api.openai.com/v1/audio/transcriptions';
  static const _chatEndpoint =
      'https://api.openai.com/v1/chat/completions';

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
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
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
        throw NoteAIException(
          'Error de OpenAI: $errorMsg',
        );
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

  /// Generates structured medical note fields using GPT-4.
  ///
  /// [prompt] should contain the full instruction and raw transcript.
  ///
  /// Returns the raw JSON string from the model.
  ///
  /// STRATEGY C: The prompt now includes STT correction instructions,
  /// so GPT-4 corrects transcription errors AND structures in one call.
  Future<String> generateStructuredFields(String prompt) async {
    try {
      final requestBody = {
        'model': _gptModel,
        'messages': [
          {
            'role': 'system',
            'content': 'Eres un asistente médico ORL. '
                'Tu trabajo: 1) Corregir errores STT (medicamentos, dosis), '
                '2) Estructurar en JSON. Solo corrige con alta certeza. '
                'Nunca inventes datos.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
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
        throw NoteAIException(
          'Error de OpenAI: $errorMsg',
        );
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
            'content': 'Eres un asistente médico ORL. '
                'Generas planes de tratamiento concisos y seguros. '
                'Nunca inventes datos del paciente (alergias, peso, edad). '
                'Usa dosis genéricas si faltan datos.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
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
        throw NoteAIException(
          'Error de OpenAI: $errorMsg',
        );
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
