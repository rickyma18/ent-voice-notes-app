// lib/src/features/doctors/doctors_providers.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'data/datasources/doctors_remote_datasource.dart';
import 'data/repositories/doctors_repository_impl.dart';
import 'domain/repositories/doctors_repository.dart';
import 'domain/usecases/create_or_update_doctor_profile_use_case.dart';
import 'domain/usecases/get_current_doctor_profile_use_case.dart';
import 'domain/usecases/update_doctor_profile_use_case.dart';

part 'doctors_providers.g.dart';

/// Remote datasource provider for doctors
@riverpod
DoctorsRemoteDatasource doctorsRemoteDatasource(
  DoctorsRemoteDatasourceRef ref,
) {
  return DoctorsRemoteDatasourceImpl();
}

/// Repository provider for doctors
@riverpod
DoctorsRepository doctorsRepository(
  DoctorsRepositoryRef ref,
) {
  return DoctorsRepositoryImpl(
    remoteDatasource: ref.watch(doctorsRemoteDatasourceProvider),
  );
}

/// Use cases providers

@riverpod
GetCurrentDoctorProfileUseCase getCurrentDoctorProfileUseCase(
  GetCurrentDoctorProfileUseCaseRef ref,
) {
  return GetCurrentDoctorProfileUseCase(
    ref.watch(doctorsRepositoryProvider),
  );
}

@riverpod
CreateOrUpdateDoctorProfileUseCase createOrUpdateDoctorProfileUseCase(
  CreateOrUpdateDoctorProfileUseCaseRef ref,
) {
  return CreateOrUpdateDoctorProfileUseCase(
    ref.watch(doctorsRepositoryProvider),
  );
}

@riverpod
UpdateDoctorProfileUseCase updateDoctorProfileUseCase(
  UpdateDoctorProfileUseCaseRef ref,
) {
  return UpdateDoctorProfileUseCase(
    ref.watch(doctorsRepositoryProvider),
  );
}
