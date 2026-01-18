// lib/src/features/doctors/data/datasources/doctors_remote_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/doctor_model.dart';

/// Remote datasource for doctor profiles
///
/// Handles CRUD operations for doctors collection in Firestore.
/// Collection: 'doctors'
/// Document ID = Firebase Auth UID
abstract base class DoctorsRemoteDatasource {
  /// Get doctor profile by ID (Firebase UID)
  Future<DoctorModel?> getDoctorById(String id);

  /// Create or update doctor profile
  /// Uses set with merge to create if not exists, update if exists
  Future<void> createOrUpdateDoctor(DoctorModel doctor);

  /// Update doctor profile
  Future<void> updateDoctor(DoctorModel doctor);

  /// Delete doctor profile
  Future<void> deleteDoctor(String id);
}

/// Firestore implementation of DoctorsRemoteDatasource
final class DoctorsRemoteDatasourceImpl implements DoctorsRemoteDatasource {
  DoctorsRemoteDatasourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('doctors');

  @override
  Future<DoctorModel?> getDoctorById(String id) async {
    final doc = await _collection.doc(id).get();

    if (!doc.exists) {
      return null;
    }

    final data = doc.data();
    if (data == null) return null;

    // Ensure id field matches document ID
    data['id'] ??= doc.id;

    return DoctorModel.fromJson(data);
  }

  @override
  Future<void> createOrUpdateDoctor(DoctorModel doctor) async {
    final data = doctor.toJson();

    // Use server timestamp for created_at/updated_at
    final now = FieldValue.serverTimestamp();

    // Set created_at only if creating, always update updated_at
    await _collection.doc(doctor.id).set({
      ...data,
      'created_at': now,
      'updated_at': now,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateDoctor(DoctorModel doctor) async {
    // Use toJsonForUpdate() to exclude null values and preserve existing data
    final data = doctor.toJsonForUpdate();

    // Remove id from data since it's the document ID
    data.remove('id');

    // Update only updated_at
    data['updated_at'] = FieldValue.serverTimestamp();

    await _collection.doc(doctor.id).update(data);
  }

  @override
  Future<void> deleteDoctor(String id) async {
    await _collection.doc(id).delete();
  }
}
