import '../../../../core/utility/firestore_timestamp_parser.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/medical_note_type.dart';
import '../../domain/entities/medication_entity.dart';
import '../../domain/entities/note_status.dart';
import '../../domain/entities/study_entity.dart';
import '../../domain/entities/surgical_note_data_entity.dart';
import 'attachment_model.dart';
import 'medication_model.dart';
import 'study_model.dart';
import 'surgical_note_data_model.dart';

class MedicalNoteModel extends MedicalNoteEntity {
  const MedicalNoteModel({
    required super.id,
    required super.patientId,
    required super.doctorId,
    required super.createdAt,
    required super.updatedAt,
    super.type,
    required super.motivoConsulta,
    required super.antecedentes,
    required super.exploracionFisicaOrl,
    required super.diagnostico,
    required super.planTratamiento,
    required super.rawTranscript,
    super.resumen,
    super.notaAdicional,
    super.status,
    super.medicamentosRecetados,
    super.estudiosIndicados,
    super.proximaCita,
    super.attachments,
    super.tags,
    super.isFavorite,
    super.surgicalData,
  });

  factory MedicalNoteModel.fromJson(Map<String, dynamic> json) {
    // Parse note type (default to clinicalHistory for backward compatibility)
    final noteType = MedicalNoteType.fromString(json['type'] as String?);

    // Parse surgical data only if present
    SurgicalNoteDataModel? surgicalData;
    if (json['surgical_data'] != null && json['surgical_data'] is Map) {
      surgicalData = SurgicalNoteDataModel.fromJson(
        json['surgical_data'] as Map<String, dynamic>,
      );
    }

    return MedicalNoteModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      doctorId: json['doctor_id'] as String,
      // Use FirestoreTimestampParser to handle both Timestamp and ISO String
      createdAt:
          FirestoreTimestampParser.tryParse(json['created_at']) ??
          DateTime.now(),
      updatedAt:
          FirestoreTimestampParser.tryParse(json['updated_at']) ??
          DateTime.now(),
      // Note type (backward compatible - defaults to clinicalHistory)
      type: noteType,
      motivoConsulta: json['motivo_consulta'] as String,
      antecedentes: json['antecedentes'] as String,
      exploracionFisicaOrl: json['exploracion_fisica_orl'] as String,
      diagnostico: json['diagnostico'] as String,
      planTratamiento: json['plan_tratamiento'] as String,
      // Ensure raw_transcript is always present (fallback to empty string for legacy data)
      rawTranscript: (json['raw_transcript'] as String?) ?? '',
      resumen: json['resumen'] as String?,
      notaAdicional: json['nota_adicional'] as String?,
      status: _parseNoteStatus(json['status'] as String?),
      medicamentosRecetados:
          (json['medicamentos_recetados'] as List<dynamic>?)
              ?.map((e) => MedicationModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      estudiosIndicados:
          (json['estudios_indicados'] as List<dynamic>?)
              ?.map((e) => StudyModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      // Use FirestoreTimestampParser for optional timestamp
      proximaCita: FirestoreTimestampParser.tryParse(json['proxima_cita']),
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => AttachmentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      isFavorite: json['is_favorite'] as bool? ?? false,
      // Surgical note specific data
      surgicalData: surgicalData,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'type': type.toFirestoreString(),
      'motivo_consulta': motivoConsulta,
      'antecedentes': antecedentes,
      'exploracion_fisica_orl': exploracionFisicaOrl,
      'diagnostico': diagnostico,
      'plan_tratamiento': planTratamiento,
      'raw_transcript': rawTranscript,
      'resumen': resumen,
      'nota_adicional': notaAdicional,
      'status': _noteStatusToString(status),
      'medicamentos_recetados': medicamentosRecetados
          .map((e) => MedicationModel.fromEntity(e).toJson())
          .toList(),
      'estudios_indicados': estudiosIndicados
          .map((e) => StudyModel.fromEntity(e).toJson())
          .toList(),
      'proxima_cita': proximaCita?.toIso8601String(),
      'attachments': attachments
          .map((e) => AttachmentModel.fromEntity(e).toJson())
          .toList(),
      'tags': tags,
      'is_favorite': isFavorite,
    };

    // Only include surgical_data for surgical notes
    if (type == MedicalNoteType.surgicalNote && surgicalData != null) {
      data['surgical_data'] =
          SurgicalNoteDataModel.fromEntity(surgicalData!).toJson();
    }

    return data;
  }

  factory MedicalNoteModel.fromEntity(MedicalNoteEntity entity) {
    return MedicalNoteModel(
      id: entity.id,
      patientId: entity.patientId,
      doctorId: entity.doctorId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      type: entity.type,
      motivoConsulta: entity.motivoConsulta,
      antecedentes: entity.antecedentes,
      exploracionFisicaOrl: entity.exploracionFisicaOrl,
      diagnostico: entity.diagnostico,
      planTratamiento: entity.planTratamiento,
      rawTranscript: entity.rawTranscript,
      resumen: entity.resumen,
      notaAdicional: entity.notaAdicional,
      status: entity.status,
      medicamentosRecetados: entity.medicamentosRecetados,
      estudiosIndicados: entity.estudiosIndicados,
      proximaCita: entity.proximaCita,
      attachments: entity.attachments,
      tags: entity.tags,
      isFavorite: entity.isFavorite,
      surgicalData: entity.surgicalData,
    );
  }

  MedicalNoteEntity toEntity() {
    return MedicalNoteEntity(
      id: id,
      patientId: patientId,
      doctorId: doctorId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      type: type,
      motivoConsulta: motivoConsulta,
      antecedentes: antecedentes,
      exploracionFisicaOrl: exploracionFisicaOrl,
      diagnostico: diagnostico,
      planTratamiento: planTratamiento,
      rawTranscript: rawTranscript,
      resumen: resumen,
      notaAdicional: notaAdicional,
      status: status,
      medicamentosRecetados: medicamentosRecetados
          .map(
            (e) => MedicationEntity(
              nombre: e.nombre,
              dosis: e.dosis,
              frecuencia: e.frecuencia,
              duracion: e.duracion,
              viaAdministracion: e.viaAdministracion,
              indicaciones: e.indicaciones,
            ),
          )
          .toList(),
      estudiosIndicados: estudiosIndicados
          .map(
            (e) => StudyEntity(
              tipo: e.tipo,
              descripcion: e.descripcion,
              urgencia: e.urgencia,
              resultadoAdjunto: e.resultadoAdjunto,
              fechaRealizado: e.fechaRealizado,
            ),
          )
          .toList(),
      proximaCita: proximaCita,
      attachments: attachments
          .map(
            (e) => AttachmentEntity(
              id: e.id,
              nombre: e.nombre,
              url: e.url,
              tipo: e.tipo,
              size_in_bytes: e.size_in_bytes,
              fechaSubida: e.fechaSubida,
              thumbnail: e.thumbnail,
            ),
          )
          .toList(),
      tags: tags,
      isFavorite: isFavorite,
      surgicalData: surgicalData != null
          ? SurgicalNoteDataEntity(
              tecnicaQuirurgica: surgicalData!.tecnicaQuirurgica,
              hallazgos: surgicalData!.hallazgos,
              observaciones: surgicalData!.observaciones,
              complicaciones: surgicalData!.complicaciones,
            )
          : null,
    );
  }

  static NoteStatus _parseNoteStatus(String? value) {
    switch (value?.toLowerCase()) {
      case 'draft':
        return NoteStatus.draft;
      case 'inreview':
      case 'in_review':
        return NoteStatus.inReview;
      case 'signed':
        return NoteStatus.signed;
      case 'sent':
        return NoteStatus.sent;
      case 'archived':
        return NoteStatus.archived;
      default:
        return NoteStatus.draft;
    }
  }

  static String _noteStatusToString(NoteStatus status) {
    switch (status) {
      case NoteStatus.draft:
        return 'draft';
      case NoteStatus.inReview:
        return 'in_review';
      case NoteStatus.signed:
        return 'signed';
      case NoteStatus.sent:
        return 'sent';
      case NoteStatus.archived:
        return 'archived';
    }
  }
}
