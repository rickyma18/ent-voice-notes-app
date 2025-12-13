// lib/src/features/patients/data/repositories/patients_repository_impl.dart

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../domain/entities/patient_entity.dart';
import '../../domain/repositories/patients_repository.dart';
import '../datasources/patients_remote_datasource.dart';
import '../models/patient_model.dart';

/// Implementación del repositorio de pacientes.
///
/// CURRENT STATE (US 4.1):
/// - Currently using FakePatientsRemoteDatasource (in-memory storage)
///   wired through patients_providers.dart
/// - All operations go through proper Clean Architecture layers:
///   UI → Controller → UseCase → Repository → FakeDatasource
///
/// TODO (Future - Real Backend Integration):
/// - Replace FakePatientsRemoteDatasource with PatientsRemoteDatasourceImpl
///   in patients_providers.dart to use real Firestore
/// - This file (repository implementation) requires NO changes when switching
final class PatientsRepositoryImpl extends PatientsRepository {
  PatientsRepositoryImpl({
    required this.remoteDatasource,
  });

  final PatientsRemoteDatasource remoteDatasource;

  @override
  Future<Result<List<PatientEntity>, Failure>> getPatients({
    String? doctorId,
  }) async {
    try {
      final models = await remoteDatasource.getPatients(doctorId: doctorId);
      final entities = models.map((m) => m.toEntity()).toList();

      return Result.success(entities);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<PatientEntity, Failure>> createPatient(
    PatientEntity patient,
  ) async {
    try {
      // 1) Convert entity to model
      final model = PatientModel.fromEntity(patient);

      // 2) Create in datasource
      final newId = await remoteDatasource.createPatient(model);

      // 3) Return created patient with the new ID
      final createdPatient = patient.copyWith(
        id: newId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return Result.success(createdPatient);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<PatientEntity, Failure>> updatePatient(
    PatientEntity patient,
  ) async {
    try {
      // 1) Convert entity to model
      final model = PatientModel.fromEntity(patient);

      // 2) Update in datasource
      final updatedModel = await remoteDatasource.updatePatient(model);

      // 3) Convert back to entity and return
      final updatedEntity = updatedModel.toEntity();

      return Result.success(updatedEntity);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<void, Failure>> deletePatient(String patientId) async {
    try {
      await remoteDatasource.deletePatient(patientId);
      return Result.success(null);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }
}
