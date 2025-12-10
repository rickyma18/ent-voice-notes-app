// lib/src/features/medical_notes/domain/entities/medical_note.dart

import 'package:equatable/equatable.dart';

import 'attachment_entity.dart';
import 'medication_entity.dart';
import 'note_status.dart';
import 'study_entity.dart';

/// Entidad de dominio para Notas Clínicas
/// 
/// Representa una nota clínica completa generada durante una consulta médica.
/// Incluye información estructurada del paciente, doctor, y detalles clínicos.
class MedicalNoteEntity extends Equatable {
  const MedicalNoteEntity({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.createdAt,
    required this.updatedAt,
    // Datos clínicos estructurados
    required this.motivoConsulta,
    required this.antecedentes,
    required this.exploracionFisicaOrl,
    required this.diagnostico,
    required this.planTratamiento,
    // Datos de transcripción y IA
    required this.rawTranscript,
    this.resumen,
    this.notaAdicional,
    // Metadatos adicionales
    this.status = NoteStatus.draft,
    this.medicamentosRecetados = const [],
    this.estudiosIndicados = const [],
    this.proximaCita,
    this.attachments = const [],
    this.tags = const [],
    this.isFavorite = false,
  });

  // Identificadores
  final String id;
  final String patientId;
  final String doctorId;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  // Datos clínicos estructurados (SOAP adaptado para ORL)
  /// Motivo de consulta principal del paciente
  final String motivoConsulta;

  /// Antecedentes médicos relevantes (personales, familiares, alergias)
  final String antecedentes;

  /// Exploración física otorrinolaringológica detallada
  final String exploracionFisicaOrl;

  /// Diagnóstico médico establecido
  final String diagnostico;

  /// Plan de tratamiento y recomendaciones
  final String planTratamiento;

  // Datos de transcripción y procesamiento IA
  /// Transcripción bruta del audio dictado por la doctora (Whisper)
  final String rawTranscript;

  /// Resumen generado por IA de la consulta completa
  final String? resumen;

  /// Notas adicionales o comentarios del doctor
  final String? notaAdicional;

  // Metadatos adicionales
  /// Estado actual de la nota (borrador, firmada, enviada, etc.)
  final NoteStatus status;

  /// Lista de medicamentos recetados en esta consulta
  final List<MedicationEntity> medicamentosRecetados;

  /// Estudios médicos indicados (laboratorios, imágenes, etc.)
  final List<StudyEntity> estudiosIndicados;

  /// Fecha y hora de la próxima cita programada
  final DateTime? proximaCita;

  /// Archivos adjuntos (imágenes, PDFs, resultados de estudios)
  final List<AttachmentEntity> attachments;

  /// Etiquetas para organización y búsqueda
  final List<String> tags;

  /// Marcador de favorito para acceso rápido
  final bool isFavorite;

  // Factory para crear nota vacía (borrador)
  factory MedicalNoteEntity.empty({
    required String patientId,
    required String doctorId,
  }) {
    final now = DateTime.now();
    return MedicalNoteEntity(
      id: '', // Se generará en el repositorio
      patientId: patientId,
      doctorId: doctorId,
      createdAt: now,
      updatedAt: now,
      motivoConsulta: '',
      antecedentes: '',
      exploracionFisicaOrl: '',
      diagnostico: '',
      planTratamiento: '',
      rawTranscript: '',
    );
  }

  // CopyWith para inmutabilidad
  MedicalNoteEntity copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? motivoConsulta,
    String? antecedentes,
    String? exploracionFisicaOrl,
    String? diagnostico,
    String? planTratamiento,
    String? rawTranscript,
    String? resumen,
    String? notaAdicional,
    NoteStatus? status,
    List<MedicationEntity>? medicamentosRecetados,
    List<StudyEntity>? estudiosIndicados,
    DateTime? proximaCita,
    List<AttachmentEntity>? attachments,
    List<String>? tags,
    bool? isFavorite,
  }) {
    return MedicalNoteEntity(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      motivoConsulta: motivoConsulta ?? this.motivoConsulta,
      antecedentes: antecedentes ?? this.antecedentes,
      exploracionFisicaOrl: exploracionFisicaOrl ?? this.exploracionFisicaOrl,
      diagnostico: diagnostico ?? this.diagnostico,
      planTratamiento: planTratamiento ?? this.planTratamiento,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      resumen: resumen ?? this.resumen,
      notaAdicional: notaAdicional ?? this.notaAdicional,
      status: status ?? this.status,
      medicamentosRecetados: medicamentosRecetados ?? this.medicamentosRecetados,
      estudiosIndicados: estudiosIndicados ?? this.estudiosIndicados,
      proximaCita: proximaCita ?? this.proximaCita,
      attachments: attachments ?? this.attachments,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // Validación de completitud
  bool get isComplete {
    return motivoConsulta.isNotEmpty &&
        exploracionFisicaOrl.isNotEmpty &&
        diagnostico.isNotEmpty &&
        planTratamiento.isNotEmpty;
  }

  // Verifica si la nota necesita atención (borrador antiguo)
  bool get needsAttention {
    return status == NoteStatus.draft &&
        DateTime.now().difference(createdAt).inDays > 1;
  }

  // Obtiene el tiempo transcurrido desde la creación
  String get timeAgo {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} año(s)';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} mes(es)';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} día(s)';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hora(s)';
    } else {
      return '${difference.inMinutes} minuto(s)';
    }
  }

  @override
  List<Object?> get props => [
        id,
        patientId,
        doctorId,
        createdAt,
        updatedAt,
        motivoConsulta,
        antecedentes,
        exploracionFisicaOrl,
        diagnostico,
        planTratamiento,
        rawTranscript,
        resumen,
        notaAdicional,
        status,
        medicamentosRecetados,
        estudiosIndicados,
        proximaCita,
        attachments,
        tags,
        isFavorite,
      ];

  @override
  String toString() => 'MedicalNoteEntity(id: $id, patientId: $patientId, '
      'status: $status, createdAt: $createdAt)';
}