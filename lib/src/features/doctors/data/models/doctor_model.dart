// lib/src/features/doctors/data/models/doctor_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utility/firestore_timestamp_parser.dart';
import '../../domain/entities/doctor_entity.dart';

class DoctorModel extends DoctorEntity {
  const DoctorModel({
    required super.id,
    required super.email,
    super.firstName,
    super.lastName,
    super.photoUrl,
    super.createdAt,
    super.updatedAt,
  });

  /// From Firestore document
  /// Uses FirestoreTimestampParser to handle both Timestamp and ISO String
  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdAt: FirestoreTimestampParser.tryParse(json['created_at']),
      updatedAt: FirestoreTimestampParser.tryParse(json['updated_at']),
    );
  }

  /// To Firestore document
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'photo_url': photoUrl,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
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
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
