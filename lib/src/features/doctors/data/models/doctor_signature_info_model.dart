// lib/src/features/doctors/data/models/doctor_signature_info_model.dart

import '../../../../core/utility/firestore_timestamp_parser.dart';
import '../../domain/entities/doctor_signature_info.dart';

/// Model for serializing/deserializing DoctorSignatureInfo to/from Firestore.
class DoctorSignatureInfoModel extends DoctorSignatureInfo {
  const DoctorSignatureInfoModel({
    required super.hasDefault,
    super.defaultUrl,
    super.updatedAt,
  });

  /// Creates a model from Firestore JSON
  factory DoctorSignatureInfoModel.fromJson(Map<String, dynamic> json) {
    return DoctorSignatureInfoModel(
      hasDefault: json['has_default'] as bool? ?? false,
      defaultUrl: json['default_url'] as String?,
      updatedAt: FirestoreTimestampParser.tryParse(json['updated_at']),
    );
  }

  /// Converts to Firestore JSON
  Map<String, dynamic> toJson() {
    return {
      'has_default': hasDefault,
      if (defaultUrl != null) 'default_url': defaultUrl,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Creates a model from an entity
  factory DoctorSignatureInfoModel.fromEntity(DoctorSignatureInfo entity) {
    return DoctorSignatureInfoModel(
      hasDefault: entity.hasDefault,
      defaultUrl: entity.defaultUrl,
      updatedAt: entity.updatedAt,
    );
  }

  /// Converts to entity
  DoctorSignatureInfo toEntity() {
    return DoctorSignatureInfo(
      hasDefault: hasDefault,
      defaultUrl: defaultUrl,
      updatedAt: updatedAt,
    );
  }
}
