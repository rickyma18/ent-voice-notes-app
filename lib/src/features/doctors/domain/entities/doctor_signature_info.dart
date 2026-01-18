// lib/src/features/doctors/domain/entities/doctor_signature_info.dart

import 'package:equatable/equatable.dart';

/// Entity representing a doctor's default signature information.
///
/// This is stored as part of the doctor profile and can be reused
/// when signing medical notes.
class DoctorSignatureInfo extends Equatable {
  const DoctorSignatureInfo({
    required this.hasDefault,
    this.defaultUrl,
    this.updatedAt,
  });

  /// Whether the doctor has a default signature saved
  final bool hasDefault;

  /// Storage URL for the default signature image
  /// Path: doctors/{doctorId}/signature/default.png
  final String? defaultUrl;

  /// When the default signature was last updated
  final DateTime? updatedAt;

  /// Factory for empty/no signature state
  factory DoctorSignatureInfo.empty() {
    return const DoctorSignatureInfo(hasDefault: false);
  }

  DoctorSignatureInfo copyWith({
    bool? hasDefault,
    String? defaultUrl,
    DateTime? updatedAt,
  }) {
    return DoctorSignatureInfo(
      hasDefault: hasDefault ?? this.hasDefault,
      defaultUrl: defaultUrl ?? this.defaultUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [hasDefault, defaultUrl, updatedAt];

  @override
  String toString() =>
      'DoctorSignatureInfo('
      'hasDefault: $hasDefault, '
      'defaultUrl: $defaultUrl, '
      'updatedAt: $updatedAt)';
}
