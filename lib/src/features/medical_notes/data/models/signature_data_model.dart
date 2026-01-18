// lib/src/features/medical_notes/data/models/signature_data_model.dart

import '../../../../core/utility/firestore_timestamp_parser.dart';
import '../../domain/entities/signature_data_entity.dart';

/// Model for serializing/deserializing SignatureDataEntity to/from Firestore.
class SignatureDataModel extends SignatureDataEntity {
  const SignatureDataModel({
    required super.signedAt,
    required super.signedByDoctorId,
    required super.signedByDoctorDisplayName,
    required super.signatureSnapshotUrl,
    required super.signedPdfUrl,
    required super.signatureMethod,
  });

  /// Creates a model from Firestore JSON
  factory SignatureDataModel.fromJson(Map<String, dynamic> json) {
    return SignatureDataModel(
      signedAt:
          FirestoreTimestampParser.tryParse(json['signed_at']) ??
          DateTime.now(),
      signedByDoctorId: json['signed_by_doctor_id'] as String,
      signedByDoctorDisplayName:
          json['signed_by_doctor_display_name'] as String,
      signatureSnapshotUrl: json['signature_snapshot_url'] as String,
      signedPdfUrl: json['signed_pdf_url'] as String,
      signatureMethod: SignatureMethod.fromString(
        json['signature_method'] as String?,
      ),
    );
  }

  /// Converts to Firestore JSON
  Map<String, dynamic> toJson() {
    return {
      'signed_at': signedAt.toIso8601String(),
      'signed_by_doctor_id': signedByDoctorId,
      'signed_by_doctor_display_name': signedByDoctorDisplayName,
      'signature_snapshot_url': signatureSnapshotUrl,
      'signed_pdf_url': signedPdfUrl,
      'signature_method': signatureMethod.value,
    };
  }

  /// Creates a model from an entity
  factory SignatureDataModel.fromEntity(SignatureDataEntity entity) {
    return SignatureDataModel(
      signedAt: entity.signedAt,
      signedByDoctorId: entity.signedByDoctorId,
      signedByDoctorDisplayName: entity.signedByDoctorDisplayName,
      signatureSnapshotUrl: entity.signatureSnapshotUrl,
      signedPdfUrl: entity.signedPdfUrl,
      signatureMethod: entity.signatureMethod,
    );
  }

  /// Converts to entity
  SignatureDataEntity toEntity() {
    return SignatureDataEntity(
      signedAt: signedAt,
      signedByDoctorId: signedByDoctorId,
      signedByDoctorDisplayName: signedByDoctorDisplayName,
      signatureSnapshotUrl: signatureSnapshotUrl,
      signedPdfUrl: signedPdfUrl,
      signatureMethod: signatureMethod,
    );
  }
}
