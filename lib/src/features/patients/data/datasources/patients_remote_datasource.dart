import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/patient_model.dart';

/// Remote datasource interface for patients
///
/// Defines the contract for fetching patient data from a remote source
/// (Firebase, REST API, etc.). For US 4.1, we use a fake in-memory implementation.
///
/// SECURITY: All list queries MUST filter by doctorId to enforce multi-tenant isolation.
abstract base class PatientsRemoteDatasource {
  /// Gets all patients for a specific doctor.
  ///
  /// CRITICAL: doctorId is REQUIRED for security - ensures multi-tenant isolation.
  Future<List<PatientModel>> getPatients(String doctorId);

  /// Crea un nuevo paciente y retorna su ID generado (US 4.3)
  Future<String> createPatient(PatientModel patient);

  /// Actualiza un paciente existente (US 4.5)
  Future<PatientModel> updatePatient(PatientModel patient);

  /// Elimina un paciente por ID (US 4.6)
  Future<void> deletePatient(String patientId);

  /// Obtiene un paciente por ID (US-D2)
  Future<PatientModel?> getPatientById(String id);
}

/// Firestore implementation of PatientsRemoteDatasource
///
/// Handles CRUD operations for patients in Firestore.
/// Collection: 'patients'
final class PatientsRemoteDatasourceImpl implements PatientsRemoteDatasource {
  PatientsRemoteDatasourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('patients');

  @override
  Future<List<PatientModel>> getPatients(String doctorId) async {
    // CRITICAL: ALWAYS filter by doctor_id for multi-tenant isolation
    // This ensures Firestore security rules can validate the query
    final querySnapshot = await _collection
        .where('doctor_id', isEqualTo: doctorId)
        .orderBy('created_at', descending: true)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      // Ensure id field matches document ID
      data['id'] ??= doc.id;
      return PatientModel.fromJson(data);
    }).toList();
  }

  @override
  Future<String> createPatient(PatientModel patient) async {
    final data = patient.toJson();

    // Remove id from data since Firestore will generate it
    data.remove('id');

    // Set server timestamps for create
    data['created_at'] = FieldValue.serverTimestamp();
    data['updated_at'] = FieldValue.serverTimestamp();

    final docRef = await _collection.add(data);

    // Update with generated ID (model expects id field)
    await docRef.update({'id': docRef.id});

    return docRef.id;
  }

  @override
  Future<PatientModel> updatePatient(PatientModel patient) async {
    final data = patient.toJson();

    // Remove id from data since it's the document ID
    data.remove('id');
    // Don't overwrite creation timestamp
    data.remove('created_at');
    // Set server timestamp for update
    data['updated_at'] = FieldValue.serverTimestamp();

    await _collection.doc(patient.id).update(data);

    // Return the updated patient
    return patient;
  }

  @override
  Future<void> deletePatient(String patientId) async {
    await _collection.doc(patientId).delete();
  }

  @override
  Future<PatientModel?> getPatientById(String id) async {
    final doc = await _collection.doc(id).get();

    if (!doc.exists) {
      return null;
    }

    final data = doc.data();
    if (data == null) return null;

    // Ensure id field matches document ID
    data['id'] ??= doc.id;

    return PatientModel.fromJson(data);
  }
}
