import '../../domain/entities/surgical_note_data_entity.dart';

/// Data model for surgical note specific data.
///
/// Handles fromJson/toJson conversion for Firestore storage.
class SurgicalNoteDataModel extends SurgicalNoteDataEntity {
  const SurgicalNoteDataModel({
    required super.tecnicaQuirurgica,
    required super.hallazgos,
    required super.observaciones,
    required super.complicaciones,
  });

  /// Parse from Firestore document map.
  /// Provides safe defaults for missing fields.
  factory SurgicalNoteDataModel.fromJson(Map<String, dynamic> json) {
    return SurgicalNoteDataModel(
      tecnicaQuirurgica: (json['tecnica_quirurgica'] as String?) ?? '',
      hallazgos: (json['hallazgos'] as String?) ?? '',
      observaciones: (json['observaciones'] as String?) ?? '',
      complicaciones: (json['complicaciones'] as String?) ?? '',
    );
  }

  /// Convert to Firestore document map.
  Map<String, dynamic> toJson() {
    return {
      'tecnica_quirurgica': tecnicaQuirurgica,
      'hallazgos': hallazgos,
      'observaciones': observaciones,
      'complicaciones': complicaciones,
    };
  }

  /// Create model from entity.
  factory SurgicalNoteDataModel.fromEntity(SurgicalNoteDataEntity entity) {
    return SurgicalNoteDataModel(
      tecnicaQuirurgica: entity.tecnicaQuirurgica,
      hallazgos: entity.hallazgos,
      observaciones: entity.observaciones,
      complicaciones: entity.complicaciones,
    );
  }

  /// Convert to entity.
  SurgicalNoteDataEntity toEntity() {
    return SurgicalNoteDataEntity(
      tecnicaQuirurgica: tecnicaQuirurgica,
      hallazgos: hallazgos,
      observaciones: observaciones,
      complicaciones: complicaciones,
    );
  }
}
