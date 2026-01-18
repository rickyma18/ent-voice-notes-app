import '../../../../core/utility/firestore_timestamp_parser.dart';
import '../../domain/entities/study_entity.dart';

class StudyModel extends StudyEntity {
  const StudyModel({
    required super.tipo,
    required super.descripcion,
    super.urgencia,
    super.resultadoAdjunto,
    super.fechaRealizado,
  });

  factory StudyModel.fromJson(Map<String, dynamic> json) {
    return StudyModel(
      tipo: json['tipo'] as String,
      descripcion: json['descripcion'] as String,
      urgencia: _parseStudyUrgency(json['urgencia'] as String?),
      resultadoAdjunto: json['resultado_adjunto'] as String?,
      // Use FirestoreTimestampParser to handle both Timestamp and ISO String
      fechaRealizado: FirestoreTimestampParser.tryParse(
        json['fecha_realizado'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo': tipo,
      'descripcion': descripcion,
      'urgencia': _studyUrgencyToString(urgencia),
      'resultado_adjunto': resultadoAdjunto,
      'fecha_realizado': fechaRealizado?.toIso8601String(),
    };
  }

  factory StudyModel.fromEntity(StudyEntity entity) {
    return StudyModel(
      tipo: entity.tipo,
      descripcion: entity.descripcion,
      urgencia: entity.urgencia,
      resultadoAdjunto: entity.resultadoAdjunto,
      fechaRealizado: entity.fechaRealizado,
    );
  }

  StudyEntity toEntity() {
    return StudyEntity(
      tipo: tipo,
      descripcion: descripcion,
      urgencia: urgencia,
      resultadoAdjunto: resultadoAdjunto,
      fechaRealizado: fechaRealizado,
    );
  }

  static StudyUrgency _parseStudyUrgency(String? value) {
    switch (value?.toLowerCase()) {
      case 'urgent':
        return StudyUrgency.urgent;
      case 'priority':
        return StudyUrgency.priority;
      case 'routine':
      default:
        return StudyUrgency.routine;
    }
  }

  static String _studyUrgencyToString(StudyUrgency urgency) {
    switch (urgency) {
      case StudyUrgency.urgent:
        return 'urgent';
      case StudyUrgency.priority:
        return 'priority';
      case StudyUrgency.routine:
        return 'routine';
    }
  }
}
