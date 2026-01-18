// lib/src/features/patients/patients_providers.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

// import 'data/datasources/patients_fake_datasource.dart'; // For development/testing
import 'data/datasources/patients_remote_datasource.dart';
import 'data/repositories/patients_repository_impl.dart';
import 'domain/repositories/patients_repository.dart';
import 'domain/usecases/create_patient_use_case.dart';
import 'domain/usecases/delete_patient_use_case.dart';
import 'domain/usecases/get_patient_by_id_use_case.dart';
import 'domain/usecases/get_patients_use_case.dart';
import 'domain/usecases/update_patient_use_case.dart';

part 'patients_providers.g.dart';

/// Remote datasource provider
///
/// PRODUCTION MODE: Uses Firestore for patient data.
///
/// To switch to fake datasource (development/testing):
/// - Uncomment: return FakePatientsRemoteDatasource();
/// - Comment out: return PatientsRemoteDatasourceImpl();
@riverpod
PatientsRemoteDatasource patientsRemoteDatasource(
  PatientsRemoteDatasourceRef ref,
) {
  // Production: Use Firestore implementation
  return PatientsRemoteDatasourceImpl();

  // Development: Use fake in-memory datasource (for testing)
  // return FakePatientsRemoteDatasource();
}

/// Repository provider
@riverpod
PatientsRepository patientsRepository(PatientsRepositoryRef ref) {
  return PatientsRepositoryImpl(
    remoteDatasource: ref.watch(patientsRemoteDatasourceProvider),
  );
}

/// Use cases providers

@riverpod
GetPatientsUseCase getPatientsUseCase(GetPatientsUseCaseRef ref) {
  return GetPatientsUseCase(ref.watch(patientsRepositoryProvider));
}

@riverpod
GetPatientByIdUseCase getPatientByIdUseCase(GetPatientByIdUseCaseRef ref) {
  return GetPatientByIdUseCase(ref.watch(patientsRepositoryProvider));
}

@riverpod
CreatePatientUseCase createPatientUseCase(CreatePatientUseCaseRef ref) {
  return CreatePatientUseCase(ref.watch(patientsRepositoryProvider));
}

@riverpod
UpdatePatientUseCase updatePatientUseCase(UpdatePatientUseCaseRef ref) {
  return UpdatePatientUseCase(ref.watch(patientsRepositoryProvider));
}

@riverpod
DeletePatientUseCase deletePatientUseCase(DeletePatientUseCaseRef ref) {
  return DeletePatientUseCase(ref.watch(patientsRepositoryProvider));
}
