import 'package:equatable/equatable.dart';

// Entidad para estudios médicos indicados
class StudyEntity extends Equatable {
  const StudyEntity({
    required this.tipo,
    required this.descripcion,
    this.urgencia = StudyUrgency.routine,
    this.resultadoAdjunto,
    this.fechaRealizado,
  });

  final String tipo; // ej: "Audiometría", "Radiografía", "Laboratorio"
  final String descripcion;
  final StudyUrgency urgencia;
  final String? resultadoAdjunto; // URL o path al resultado
  final DateTime? fechaRealizado;

  @override
  List<Object?> get props => [
        tipo,
        descripcion,
        urgencia,
        resultadoAdjunto,
        fechaRealizado,
      ];
}

enum StudyUrgency {
  urgent('Urgente'),
  priority('Prioritario'),
  routine('Rutina');

  const StudyUrgency(this.displayName);
  final String displayName;
}
