// lib/src/features/patients/domain/entities/patient_entity.dart

import 'package:equatable/equatable.dart';

/// Entidad de dominio para Pacientes
///
/// Representa un paciente registrado en el sistema.
/// Incluye información demográfica básica y metadatos.
class PatientEntity extends Equatable {
  const PatientEntity({
    required this.id,
    required this.fullName,
    required this.age,
    required this.sex,
    this.phone,
    this.createdAt,
    this.updatedAt,
    this.doctorId,
  });

  /// Identificador único del paciente
  final String id;

  /// Nombre completo del paciente
  final String fullName;

  /// Edad del paciente en años
  final int age;

  /// Sexo del paciente: 'M' (Masculino), 'F' (Femenino), 'Otro'
  final String sex;

  /// Número de teléfono del paciente (opcional)
  final String? phone;

  /// Fecha de creación del registro
  final DateTime? createdAt;

  /// Fecha de última actualización del registro
  final DateTime? updatedAt;

  /// ID del doctor asignado (opcional, para soporte multi-doctor)
  final String? doctorId;

  /// CopyWith para inmutabilidad
  PatientEntity copyWith({
    String? id,
    String? fullName,
    int? age,
    String? sex,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? doctorId,
  }) {
    return PatientEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      doctorId: doctorId ?? this.doctorId,
    );
  }

  /// Retorna el sexo en formato legible
  String get sexDisplay {
    switch (sex.toUpperCase()) {
      case 'M':
        return 'Masculino';
      case 'F':
        return 'Femenino';
      default:
        return 'Otro';
    }
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        age,
        sex,
        phone,
        createdAt,
        updatedAt,
        doctorId,
      ];

  @override
  String toString() => 'PatientEntity(id: $id, fullName: $fullName, '
      'age: $age, sex: $sex)';
}
