import 'package:equatable/equatable.dart';

// Entidad para medicamentos recetados
class MedicationEntity extends Equatable {
  const MedicationEntity({
    required this.nombre,
    required this.dosis,
    required this.frecuencia,
    required this.duracion,
    this.viaAdministracion = 'Oral',
    this.indicaciones,
  });

  final String nombre;
  final String dosis; // ej: "500mg"
  final String frecuencia; // ej: "cada 8 horas"
  final String duracion; // ej: "7 días"
  final String viaAdministracion;
  final String? indicaciones;

  @override
  List<Object?> get props => [
    nombre,
    dosis,
    frecuencia,
    duracion,
    viaAdministracion,
    indicaciones,
  ];
}
