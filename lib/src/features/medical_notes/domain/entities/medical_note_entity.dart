// lib/src/features/medical_notes/domain/entities/medical_note.dart

import 'package:equatable/equatable.dart';

import 'attachment_entity.dart';
import 'medical_note_type.dart';
import 'medication_entity.dart';
import 'note_status.dart';
import 'study_entity.dart';
import 'surgical_note_data_entity.dart';

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
    // Note type (clinical_history or surgical_note)
    this.type = MedicalNoteType.clinicalHistory,
    // Datos clínicos estructurados
    required this.motivoConsulta,
    required this.antecedentes,
    required this.exploracionFisicaOrl,
    required this.diagnostico,
    required this.planTratamiento,
    // Signos vitales (vital signs)
    this.weightKg,
    this.heightCm,
    this.bpSystolic,
    this.bpDiastolic,
    this.heartRate,
    this.respiratoryRate,
    this.temperatureC,
    this.spo2,
    // Pronóstico (prognosis)
    this.prognosis,
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
    // Surgical note specific data (only for surgical notes)
    this.surgicalData,
  });

  // Identificadores
  final String id;
  final String patientId;
  final String doctorId;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  // Note type
  /// Type of medical note (clinical_history or surgical_note).
  /// Defaults to clinicalHistory for backward compatibility.
  final MedicalNoteType type;

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

  // Signos vitales (vital signs)
  /// Peso en kilogramos
  final double? weightKg;

  /// Talla en centímetros
  final double? heightCm;

  /// Presión arterial sistólica (mmHg)
  final int? bpSystolic;

  /// Presión arterial diastólica (mmHg)
  final int? bpDiastolic;

  /// Frecuencia cardíaca (latidos por minuto)
  final int? heartRate;

  /// Frecuencia respiratoria (respiraciones por minuto)
  final int? respiratoryRate;

  /// Temperatura corporal (°C)
  final double? temperatureC;

  /// Saturación de oxígeno (SpO2 %)
  final int? spo2;

  /// Pronóstico del paciente
  final String? prognosis;

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

  // Surgical note specific data
  /// Additional data for surgical notes (tecnica, hallazgos, etc.).
  /// Only populated when type == surgicalNote.
  final SurgicalNoteDataEntity? surgicalData;

  // Factory para crear nota vacía (borrador)
  factory MedicalNoteEntity.empty({
    required String patientId,
    required String doctorId,
    MedicalNoteType type = MedicalNoteType.clinicalHistory,
  }) {
    final now = DateTime.now();
    return MedicalNoteEntity(
      id: '', // Se generará en el repositorio
      patientId: patientId,
      doctorId: doctorId,
      createdAt: now,
      updatedAt: now,
      type: type,
      motivoConsulta: '',
      antecedentes: '',
      exploracionFisicaOrl: '',
      diagnostico: '',
      planTratamiento: '',
      rawTranscript: '',
      surgicalData: type == MedicalNoteType.surgicalNote
          ? SurgicalNoteDataEntity.empty()
          : null,
    );
  }

  // CopyWith para inmutabilidad
  MedicalNoteEntity copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    DateTime? createdAt,
    DateTime? updatedAt,
    MedicalNoteType? type,
    String? motivoConsulta,
    String? antecedentes,
    String? exploracionFisicaOrl,
    String? diagnostico,
    String? planTratamiento,
    double? weightKg,
    double? heightCm,
    int? bpSystolic,
    int? bpDiastolic,
    int? heartRate,
    int? respiratoryRate,
    double? temperatureC,
    int? spo2,
    String? prognosis,
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
    SurgicalNoteDataEntity? surgicalData,
  }) {
    return MedicalNoteEntity(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      motivoConsulta: motivoConsulta ?? this.motivoConsulta,
      antecedentes: antecedentes ?? this.antecedentes,
      exploracionFisicaOrl: exploracionFisicaOrl ?? this.exploracionFisicaOrl,
      diagnostico: diagnostico ?? this.diagnostico,
      planTratamiento: planTratamiento ?? this.planTratamiento,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      bpSystolic: bpSystolic ?? this.bpSystolic,
      bpDiastolic: bpDiastolic ?? this.bpDiastolic,
      heartRate: heartRate ?? this.heartRate,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      temperatureC: temperatureC ?? this.temperatureC,
      spo2: spo2 ?? this.spo2,
      prognosis: prognosis ?? this.prognosis,
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
      surgicalData: surgicalData ?? this.surgicalData,
    );
  }

  // Validación de completitud
  bool get isComplete {
    final baseComplete = motivoConsulta.isNotEmpty &&
        exploracionFisicaOrl.isNotEmpty &&
        diagnostico.isNotEmpty &&
        planTratamiento.isNotEmpty;

    // For surgical notes, also check surgical data fields
    if (type == MedicalNoteType.surgicalNote && surgicalData != null) {
      return baseComplete && surgicalData!.tecnicaQuirurgica.isNotEmpty;
    }

    return baseComplete;
  }

  /// Check if this is a surgical note
  bool get isSurgicalNote => type == MedicalNoteType.surgicalNote;

  /// Check if this is a clinical history note
  bool get isClinicalHistory => type == MedicalNoteType.clinicalHistory;

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
        type,
        motivoConsulta,
        antecedentes,
        exploracionFisicaOrl,
        diagnostico,
        planTratamiento,
        weightKg,
        heightCm,
        bpSystolic,
        bpDiastolic,
        heartRate,
        respiratoryRate,
        temperatureC,
        spo2,
        prognosis,
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
        surgicalData,
      ];

  @override
  String toString() => 'MedicalNoteEntity(id: $id, patientId: $patientId, '
      'type: $type, status: $status, createdAt: $createdAt)';
}