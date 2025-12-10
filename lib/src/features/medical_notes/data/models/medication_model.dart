import '../../domain/entities/medication_entity.dart';

class MedicationModel extends MedicationEntity {
  const MedicationModel({
    required super.nombre,
    required super.dosis,
    required super.frecuencia,
    required super.duracion,
    super.viaAdministracion,
    super.indicaciones,
  });

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    return MedicationModel(
      nombre: json['nombre'] as String,
      dosis: json['dosis'] as String,
      frecuencia: json['frecuencia'] as String,
      duracion: json['duracion'] as String,
      viaAdministracion: json['via_administracion'] as String? ?? 'Oral',
      indicaciones: json['indicaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'dosis': dosis,
      'frecuencia': frecuencia,
      'duracion': duracion,
      'via_administracion': viaAdministracion,
      'indicaciones': indicaciones,
    };
  }

  factory MedicationModel.fromEntity(MedicationEntity entity) {
    return MedicationModel(
      nombre: entity.nombre,
      dosis: entity.dosis,
      frecuencia: entity.frecuencia,
      duracion: entity.duracion,
      viaAdministracion: entity.viaAdministracion,
      indicaciones: entity.indicaciones,
    );
  }

  MedicationEntity toEntity() {
    return MedicationEntity(
      nombre: nombre,
      dosis: dosis,
      frecuencia: frecuencia,
      duracion: duracion,
      viaAdministracion: viaAdministracion,
      indicaciones: indicaciones,
    );
  }
}
