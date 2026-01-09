// lib/src/features/doctors/doctors_providers.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'data/datasources/doctors_remote_datasource.dart';
import 'data/datasources/profile_photo_storage_datasource.dart';
import 'data/repositories/doctors_repository_impl.dart';
import 'domain/repositories/doctors_repository.dart';
import 'domain/usecases/create_or_update_doctor_profile_use_case.dart';
import 'domain/usecases/delete_account_use_case.dart';
import 'domain/usecases/delete_doctor_photo_use_case.dart';
import 'domain/usecases/get_current_doctor_profile_use_case.dart';
import 'domain/usecases/update_doctor_photo_use_case.dart';
import 'domain/usecases/update_doctor_profile_use_case.dart';

part 'doctors_providers.g.dart';

/// Remote datasource provider for doctors
@riverpod
DoctorsRemoteDatasource doctorsRemoteDatasource(
  DoctorsRemoteDatasourceRef ref,
) {
  return DoctorsRemoteDatasourceImpl();
}

/// Storage datasource provider for profile photos
@riverpod
ProfilePhotoStorageDatasource profilePhotoStorageDatasource(
  ProfilePhotoStorageDatasourceRef ref,
) {
  return ProfilePhotoStorageDatasource();
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

@riverpod
UpdateDoctorPhotoUseCase updateDoctorPhotoUseCase(
  UpdateDoctorPhotoUseCaseRef ref,
) {
  return UpdateDoctorPhotoUseCase(
    repository: ref.watch(doctorsRepositoryProvider),
    storageDatasource: ref.watch(profilePhotoStorageDatasourceProvider),
  );
}

@riverpod
DeleteDoctorPhotoUseCase deleteDoctorPhotoUseCase(
  DeleteDoctorPhotoUseCaseRef ref,
) {
  return DeleteDoctorPhotoUseCase(
    repository: ref.watch(doctorsRepositoryProvider),
    storageDatasource: ref.watch(profilePhotoStorageDatasourceProvider),
  );
}

@riverpod
DeleteAccountUseCase deleteAccountUseCase(
  DeleteAccountUseCaseRef ref,
) {
  return DeleteAccountUseCase(
    repository: ref.watch(doctorsRepositoryProvider),
    storageDatasource: ref.watch(profilePhotoStorageDatasourceProvider),
  );
}
