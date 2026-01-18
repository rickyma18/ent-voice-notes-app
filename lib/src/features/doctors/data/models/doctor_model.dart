// lib/src/features/doctors/data/models/doctor_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utility/firestore_timestamp_parser.dart';
import '../../domain/entities/doctor_entity.dart';
import '../../domain/entities/doctor_signature_info.dart';
import 'doctor_signature_info_model.dart';

class DoctorModel extends DoctorEntity {
  const DoctorModel({
    required super.id,
    required super.email,
    super.firstName,
    super.lastName,
    super.photoUrl,
    super.signatureInfo,
    super.createdAt,
    super.updatedAt,
  });

  /// From Firestore document
  /// Uses FirestoreTimestampParser to handle both Timestamp and ISO String
  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    // Parse signature info if present
    DoctorSignatureInfoModel? signatureInfo;
    if (json['signature_info'] != null && json['signature_info'] is Map) {
      signatureInfo = DoctorSignatureInfoModel.fromJson(
        json['signature_info'] as Map<String, dynamic>,
      );
    }

    return DoctorModel(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      signatureInfo: signatureInfo,
      createdAt: FirestoreTimestampParser.tryParse(json['created_at']),
      updatedAt: FirestoreTimestampParser.tryParse(json['updated_at']),
    );
  }

  /// To Firestore document (includes all fields, even null)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'photo_url': photoUrl,
      if (signatureInfo != null)
        'signature_info': DoctorSignatureInfoModel.fromEntity(
          signatureInfo!,
        ).toJson(),
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// To Firestore document for partial updates.
  /// Excludes null values to avoid overwriting existing data with null.
  /// Use this when updating only specific fields (e.g., name/email without photo).
  Map<String, dynamic> toJsonForUpdate() {
    return {
      'id': id,
      'email': email,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (photoUrl != null) 'photo_url': photoUrl,
    };
  }

  /// From entity
  factory DoctorModel.fromEntity(DoctorEntity entity) {
    return DoctorModel(
      id: entity.id,
      email: entity.email,
      firstName: entity.firstName,
      lastName: entity.lastName,
      photoUrl: entity.photoUrl,
      signatureInfo: entity.signatureInfo,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// To entity
  DoctorEntity toEntity() {
    return DoctorEntity(
      id: id,
      email: email,
      firstName: firstName,
      lastName: lastName,
      photoUrl: photoUrl,
      signatureInfo: signatureInfo != null
          ? DoctorSignatureInfo(
              hasDefault: signatureInfo!.hasDefault,
              defaultUrl: signatureInfo!.defaultUrl,
              updatedAt: signatureInfo!.updatedAt,
            )
          : null,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
