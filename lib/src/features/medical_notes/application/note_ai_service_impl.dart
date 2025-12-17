// lib/src/features/medical_notes/application/note_ai_service_impl.dart

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/logger/log.dart';
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
  }) : _openAIClient = openAIClient;

  final OpenAIClient _openAIClient;

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

      // Call Whisper API
      final transcript = await _openAIClient.transcribeAudio(filePath);

      if (transcript.trim().isEmpty) {
        throw NoteAIException(
          'La transcripción está vacía. Intenta grabar de nuevo.',
        );
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
  /// This prompt is critical for getting accurate, consistent medical notes.
  /// It instructs the model to:
  /// - Use Spanish medical terminology
  /// - Output ONLY valid JSON
  /// - Use exact field names
  /// - Omit fields when insufficient data
  /// - Not hallucinate diagnoses or medications
  String _buildStructuredFieldsPrompt(String rawTranscript) {
    return '''
Eres un asistente médico especializado en otorrinolaringología (ORL).

Tu tarea es convertir la siguiente transcripción de una consulta médica en una nota estructurada.

REGLAS ESTRICTAS:
1. Debes responder ÚNICAMENTE con un objeto JSON válido.
2. NO incluyas explicaciones, markdown, ni texto adicional.
3. SOLO usa las siguientes claves (nombres exactos):
   - motivoConsulta
   - antecedentes
   - exploracionFisicaOrl
   - diagnostico
   - planTratamiento
   - resumen
   - notaAdicional

4. Si no hay suficiente información para un campo, OMÍTELO (no lo incluyas en el JSON).
5. NO inventes diagnósticos si los datos son insuficientes.
6. NO inventes medicamentos ni dosis.
7. Usa terminología médica profesional en español.
8. Sé conciso y clínico.
9. Todos los valores deben ser strings.
10. NO uses arrays ni objetos anidados.

TRANSCRIPCIÓN:
"""
$rawTranscript
"""

Responde SOLO con el objeto JSON:''';
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

        // Ensure value is string and non-empty
        if (value is String && value.trim().isNotEmpty) {
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
  /// Returns raw transcript text in Spanish.
  Future<String> transcribeAudio(String filePath) async {
    try {
      // Prepare multipart form data
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
        'model': _whisperModel,
        'language': 'es', // Spanish
        'response_format': 'text', // Plain text response
      });

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
  Future<String> generateStructuredFields(String prompt) async {
    try {
      final requestBody = {
        'model': _gptModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'Eres un asistente médico especializado en '
                    'otorrinolaringología. Generas notas médicas '
                    'estructuradas en formato JSON válido.',
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
