// lib/src/features/patients/data/datasources/patients_fake_datasource.dart

import '../models/patient_model.dart';
import 'patients_remote_datasource.dart';

/// FAKE in-memory implementation of PatientsRemoteDatasource
///
/// PURPOSE:
/// - Temporary implementation for US 4.1 to allow testing without Firebase/Firestore
/// - Stores all patients in static in-memory List (_patientsStore)
/// - Data persists during app session but is lost on restart
/// - Pre-populated with 3 sample patients for demo purposes
///
/// CURRENT USAGE:
/// - Wired through patients_providers.dart as the current remote datasource
/// - Simulates network delays (300ms) for realistic behavior
///
/// TODO (Future - Real Backend Integration):
/// - This class will remain in codebase for testing purposes
/// - Switch to PatientsRemoteDatasourceImpl (Firestore) in patients_providers.dart
final class FakePatientsRemoteDatasource extends PatientsRemoteDatasource {
  FakePatientsRemoteDatasource() {
    _initializeSampleData();
  }

  // In-memory storage: List<PatientModel>
  static final List<PatientModel> _patientsStore = [];
  static int _idCounter = 4; // Start from 4 since we have 3 demo patients

  /// Initialize with sample data for testing
  void _initializeSampleData() {
    if (_patientsStore.isEmpty) {
      final now = DateTime.now();

      // Sample patients for demo
      // IMPORTANT: patient-demo-001 matches the patient ID used in medical notes fake data
      final samplePatients = [
        PatientModel(
          id: 'patient-demo-001',
          fullName: 'Juan Pérez García',
          age: 32,
          sex: 'M',
          phone: '555-123-4567',
          doctorId: 'doctor-demo-001',
          createdAt: DateTime(2024, 1, 10),
          updatedAt: now,
        ),
        PatientModel(
          id: 'patient-002',
          fullName: 'María López Hernández',
          age: 28,
          sex: 'F',
          phone: '555-987-6543',
          doctorId: 'doctor-demo-001',
          createdAt: DateTime(2024, 2, 15),
          updatedAt: now,
        ),
        PatientModel(
          id: 'patient-003',
          fullName: 'Carlos Ramírez Soto',
          age: 45,
          sex: 'M',
          phone: null,
          doctorId: 'doctor-demo-001',
          createdAt: DateTime(2024, 3, 20),
          updatedAt: now,
        ),
      ];

      _patientsStore.addAll(samplePatients);
    }
  }

  @override
  Future<List<PatientModel>> getPatients({String? doctorId}) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    if (doctorId == null) {
      return List.from(_patientsStore);
    }

    return _patientsStore
        .where((patient) => patient.doctorId == doctorId)
        .toList();
  }

  @override
  Future<String> createPatient(PatientModel patient) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 400));

    // Generate a new ID
    final newId = 'patient-${_idCounter.toString().padLeft(3, '0')}';
    _idCounter++;

    // Create a new patient with the generated ID
    final newPatient = PatientModel(
      id: newId,
      fullName: patient.fullName,
      age: patient.age,
      sex: patient.sex,
      phone: patient.phone,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      doctorId: patient.doctorId,
    );

    _patientsStore.add(newPatient);

    return newId;
  }

  @override
  Future<PatientModel> updatePatient(PatientModel patient) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 400));

    // Find the patient by ID
    final index = _patientsStore.indexWhere((p) => p.id == patient.id);

    if (index == -1) {
      throw Exception('Patient with id ${patient.id} not found');
    }

    // Update the patient with new data, preserving createdAt
    final updatedPatient = PatientModel(
      id: patient.id,
      fullName: patient.fullName,
      age: patient.age,
      sex: patient.sex,
      phone: patient.phone,
      createdAt: _patientsStore[index].createdAt, // Preserve original
      updatedAt: DateTime.now(),
      doctorId: patient.doctorId,
    );

    _patientsStore[index] = updatedPatient;

    return updatedPatient;
  }

  @override
  Future<void> deletePatient(String patientId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Remove the patient by ID
    _patientsStore.removeWhere((p) => p.id == patientId);
  }

  @override
  Future<PatientModel?> getPatientById(String id) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      return _patientsStore.firstWhere((p) => p.id == id);
    } catch (e) {
      return null; // Patient not found
    }
  }

  /// Utility method to clear all data (useful for testing)
  static void clearAll() {
    _patientsStore.clear();
    _idCounter = 4;
  }

  /// Utility method to get total count of patients in store
  static int get totalPatientsCount => _patientsStore.length;
}
