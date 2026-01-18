import 'package:equatable/equatable.dart';

/// Entity containing surgical note specific data.
///
/// This entity holds the additional fields required for surgical notes:
/// - tecnicaQuirurgica: Surgical technique used
/// - hallazgos: Intraoperative findings
/// - observaciones: Additional observations
/// - complicaciones: Any complications during the procedure
class SurgicalNoteDataEntity extends Equatable {
  const SurgicalNoteDataEntity({
    required this.tecnicaQuirurgica,
    required this.hallazgos,
    required this.observaciones,
    required this.complicaciones,
  });

  /// Surgical technique used during the procedure
  final String tecnicaQuirurgica;

  /// Intraoperative findings
  final String hallazgos;

  /// Additional observations
  final String observaciones;

  /// Complications during the procedure (if any)
  final String complicaciones;

  /// Factory to create an empty surgical note data
  factory SurgicalNoteDataEntity.empty() {
    return const SurgicalNoteDataEntity(
      tecnicaQuirurgica: '',
      hallazgos: '',
      observaciones: '',
      complicaciones: '',
    );
  }

  /// CopyWith for immutability
  SurgicalNoteDataEntity copyWith({
    String? tecnicaQuirurgica,
    String? hallazgos,
    String? observaciones,
    String? complicaciones,
  }) {
    return SurgicalNoteDataEntity(
      tecnicaQuirurgica: tecnicaQuirurgica ?? this.tecnicaQuirurgica,
      hallazgos: hallazgos ?? this.hallazgos,
      observaciones: observaciones ?? this.observaciones,
      complicaciones: complicaciones ?? this.complicaciones,
    );
  }

  /// Check if the surgical data has any content
  bool get hasContent {
    return tecnicaQuirurgica.isNotEmpty ||
        hallazgos.isNotEmpty ||
        observaciones.isNotEmpty ||
        complicaciones.isNotEmpty;
  }

  @override
  List<Object?> get props => [
    tecnicaQuirurgica,
    hallazgos,
    observaciones,
    complicaciones,
  ];

  @override
  String toString() =>
      'SurgicalNoteDataEntity(tecnicaQuirurgica: $tecnicaQuirurgica, '
      'hallazgos: $hallazgos, observaciones: $observaciones, '
      'complicaciones: $complicaciones)';
}
