import '../../domain/entities/patient_entity.dart';

class PatientModel extends PatientEntity {
  const PatientModel({
    required super.id,
    required super.fullName,
    required super.age,
    required super.sex,
    super.phone,
    super.createdAt,
    super.updatedAt,
    super.doctorId,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      age: json['age'] as int,
      sex: json['sex'] as String,
      phone: json['phone'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      doctorId: json['doctor_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'age': age,
      'sex': sex,
      'phone': phone,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'doctor_id': doctorId,
    };
  }

  factory PatientModel.fromEntity(PatientEntity entity) {
    return PatientModel(
      id: entity.id,
      fullName: entity.fullName,
      age: entity.age,
      sex: entity.sex,
      phone: entity.phone,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      doctorId: entity.doctorId,
    );
  }

  PatientEntity toEntity() {
    return PatientEntity(
      id: id,
      fullName: fullName,
      age: age,
      sex: sex,
      phone: phone,
      createdAt: createdAt,
      updatedAt: updatedAt,
      doctorId: doctorId,
    );
  }
}
