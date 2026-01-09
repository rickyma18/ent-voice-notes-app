// lib/src/features/doctors/domain/entities/doctor_entity.dart

import 'package:equatable/equatable.dart';

import 'gender.dart';

/// Doctor profile entity
///
/// Represents a doctor's profile in the system.
/// Linked to Firebase Auth user via uid.
class DoctorEntity extends Equatable {
  const DoctorEntity({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.gender,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// Doctor ID (same as Firebase Auth UID)
  final String id;

  /// Email address
  final String email;

  /// First name (optional)
  final String? firstName;

  /// Last name (optional)
  final String? lastName;

  /// Gender (optional, used for greeting)
  final Gender? gender;

  /// Profile photo URL from Firebase Storage (optional)
  final String? photoUrl;

  /// Profile creation timestamp
  final DateTime? createdAt;

  /// Last profile update timestamp
  final DateTime? updatedAt;

  /// Full name computed property
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    if (firstName != null) return firstName!;
    if (lastName != null) return lastName!;
    return email.split('@').first;
  }

  /// Copy with for immutability
  DoctorEntity copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    Gender? gender,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoctorEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Copy with allowing explicit null for photoUrl
  DoctorEntity copyWithPhotoUrl(String? photoUrl) {
    return DoctorEntity(
      id: id,
      email: email,
      firstName: firstName,
      lastName: lastName,
      gender: gender,
      photoUrl: photoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        firstName,
        lastName,
        gender,
        photoUrl,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() => 'DoctorEntity(id: $id, email: $email, '
      'fullName: $fullName)';
}
