// lib/src/features/medical_notes/data/repositories/medical_notes_repository_impl.dart

import 'package:flutter/foundation.dart';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/patient_prefill.dart';
import '../../domain/repositories/medical_notes_repository.dart';
import '../datasources/medical_notes_local_datasource.dart';
import '../datasources/medical_notes_remote_datasource.dart';
import '../models/medical_note_model.dart';

/// Implementación del repositorio de notas médicas.
///
/// CURRENT STATE (US 1.1 - US 1.3):
/// - Currently using FakeMedicalNotesRemoteDatasource (in-memory storage)
///   wired through medical_notes_providers.dart
/// - All CRUD operations go through proper Clean Architecture layers:
///   UI → Controller → UseCase → Repository → FakeDatasource
///
/// TODO (EPIC 5 - Real Backend Integration):
/// - Replace FakeMedicalNotesRemoteDatasource with MedicalNotesRemoteDatasourceImpl
///   in medical_notes_providers.dart to use real Firestore
/// - This file (repository implementation) requires NO changes when switching
/// - Just update the provider to return MedicalNotesRemoteDatasourceImpl()
///
/// Architecture:
/// - Data layer: usa [MedicalNotesRemoteDatasource] (abstraction)
/// - Domain layer: expone y consume [MedicalNoteEntity]
final class MedicalNotesRepositoryImpl extends MedicalNotesRepository {
  MedicalNotesRepositoryImpl({
    required this.remoteDatasource,
    required this.localDatasource,
  });

  final MedicalNotesRemoteDatasource remoteDatasource;
  final MedicalNotesLocalDatasource localDatasource;

  @override
  Future<Result<List<MedicalNoteEntity>, Failure>> getNotesByPatient(
    String patientId,
    String doctorId,
  ) async {
    try {
      // CRITICAL: Pass both patientId and doctorId for security
      // This ensures Firestore security rules can validate the query
      final models = await remoteDatasource.getNotesByPatient(
        patientId,
        doctorId,
      );

      final entities = models.map((m) => m.toEntity()).toList();

      return Result.success(entities);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<List<MedicalNoteEntity>, Failure>> getNotesByDoctor(
    String doctorId,
  ) async {
    try {
      final models = await remoteDatasource.getNotesByDoctor(doctorId);
      final entities = models.map((m) => m.toEntity()).toList();
      return Result.success(entities);
    } catch (e) {
      return Result.error(Failure.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<MedicalNoteEntity?, Failure>> getNoteById(String id) async {
    try {
      final model = await remoteDatasource.getNoteById(id);
      final entity = model?.toEntity();

      return Result.success(entity);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<MedicalNoteEntity, Failure>> createNote(
    MedicalNoteEntity note,
  ) async {
    try {
      // 1) Dominio → modelo
      final model = MedicalNoteModel.fromEntity(note);

      // 2) Crear en Firestore
      final newId = await remoteDatasource.createNote(model);

      // 3) Releer para obtener la versión persistida
      final createdModel = await remoteDatasource.getNoteById(newId);

      if (createdModel == null) {
        return Result.error(
          const Failure(
            type: FailureType.unknown,
            message: 'Created medical note not found after Firestore insert.',
          ),
        );
      }

      final entity = createdModel.toEntity();
      return Result.success(entity);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<MedicalNoteEntity, Failure>> updateNote(
    MedicalNoteEntity note,
  ) async {
    try {
      final model = MedicalNoteModel.fromEntity(note);

      await remoteDatasource.updateNote(model);

      // Podríamos releer desde remoto, pero por simplicidad devolvemos la misma entidad.
      return Result.success(note);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<void, Failure>> deleteNote(String id) async {
    try {
      await remoteDatasource.deleteNote(id);
      return const Result.success(null);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<PatientPrefill?, Failure>> getPatientPrefill(
    String patientId,
    String doctorId,
  ) async {
    try {
      final model = await remoteDatasource.getLatestNoteByPatient(
        patientId,
        doctorId,
      );

      if (model == null) {
        return const Result.success(null);
      }

      // Extract prefill: try structured fields first, fallback to regex parsing
      final prefill = _extractPrefillFromModel(model, patientId);
      return Result.success(prefill);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  /// Extracts prefill data from MedicalNoteModel.
  ///
  /// Priority:
  /// 1. structuredFields.antecedentes (new format)
  /// 2. structuredV1.antecedentes (legacy structured)
  /// 3. Regex parsing of antecedentes string (legacy fallback)
  PatientPrefill _extractPrefillFromModel(
    MedicalNoteModel model,
    String patientId,
  ) {
    final noteId = model.id;
    final noteDate = model.createdAt;

    assert(() {
      debugPrint('[Prefill][Repo] EXTRACT: noteId="$noteId" '
          'antecedentes.len=${model.antecedentes.length} '
          'structuredFields.keys=${model.structuredFields?.keys.toList()} '
          'structuredV1.keys=${model.structuredV1?.keys.toList()}');
      return true;
    }());

    String heredofamiliares = '';
    String noPatologicos = '';
    String patologicos = '';

    // Priority 1: structuredFields.antecedentes
    if (model.structuredFields != null) {
      final antecedentes =
          model.structuredFields!['antecedentes'] as Map<String, dynamic>?;
      if (antecedentes != null) {
        assert(() {
          debugPrint('[Prefill][Repo] FOUND structuredFields.antecedentes: '
              'keys=${antecedentes.keys.toList()}');
          return true;
        }());

        heredofamiliares = _extractString(antecedentes, 'heredofamiliares');
        noPatologicos = _extractString(antecedentes, 'noPatologicos').isNotEmpty
            ? _extractString(antecedentes, 'noPatologicos')
            : _extractString(antecedentes, 'no_patologicos');
        patologicos = _extractString(antecedentes, 'patologicos');

        if (heredofamiliares.isNotEmpty ||
            noPatologicos.isNotEmpty ||
            patologicos.isNotEmpty) {
          assert(() {
            debugPrint('[Prefill][Repo] RETURN from structuredFields: '
                'heredo.len=${heredofamiliares.length} '
                'noPato.len=${noPatologicos.length} '
                'pato.len=${patologicos.length}');
            return true;
          }());
          return PatientPrefill(
            patientId: patientId,
            sourceNoteId: noteId,
            sourceNoteDate: noteDate,
            heredofamiliares: heredofamiliares,
            noPatologicos: noPatologicos,
            patologicos: patologicos,
          );
        }
      }
    }

    // Priority 2: structuredV1.antecedentes
    if (model.structuredV1 != null) {
      final antecedentes =
          model.structuredV1!['antecedentes'] as Map<String, dynamic>?;
      if (antecedentes != null) {
        assert(() {
          debugPrint('[Prefill][Repo] FOUND structuredV1.antecedentes: '
              'keys=${antecedentes.keys.toList()}');
          return true;
        }());

        heredofamiliares = _extractString(antecedentes, 'heredofamiliares');
        noPatologicos = _extractString(antecedentes, 'noPatologicos').isNotEmpty
            ? _extractString(antecedentes, 'noPatologicos')
            : _extractString(antecedentes, 'no_patologicos');
        patologicos = _extractString(antecedentes, 'patologicos');

        if (heredofamiliares.isNotEmpty ||
            noPatologicos.isNotEmpty ||
            patologicos.isNotEmpty) {
          assert(() {
            debugPrint('[Prefill][Repo] RETURN from structuredV1: '
                'heredo.len=${heredofamiliares.length} '
                'noPato.len=${noPatologicos.length} '
                'pato.len=${patologicos.length}');
            return true;
          }());
          return PatientPrefill(
            patientId: patientId,
            sourceNoteId: noteId,
            sourceNoteDate: noteDate,
            heredofamiliares: heredofamiliares,
            noPatologicos: noPatologicos,
            patologicos: patologicos,
          );
        }
      }
    }

    // Priority 3: Legacy fallback - parse antecedentes string with regex
    assert(() {
      debugPrint('[Prefill][Repo] FALLBACK to legacy regex parsing');
      return true;
    }());

    final result = _extractPrefillFromLegacyString(
      model.antecedentes,
      patientId,
      noteId,
      noteDate,
    );

    assert(() {
      debugPrint('[Prefill][Repo] LEGACY RESULT: '
          'heredo.len=${result.heredofamiliares.length} '
          'noPato.len=${result.noPatologicos.length} '
          'pato.len=${result.patologicos.length}');
      return true;
    }());

    return result;
  }

  /// Safely extracts a string from a map, handling null.
  String _extractString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String) return value.trim();
    return '';
  }

  /// Legacy fallback: parse antecedentes structured string with regex.
  PatientPrefill _extractPrefillFromLegacyString(
    String antecedentes,
    String patientId,
    String noteId,
    DateTime noteDate,
  ) {
    String heredofamiliares = '';
    String noPatologicos = '';
    String patologicos = '';

    if (antecedentes.isNotEmpty) {
      // Check if structured format exists
      final hasStructuredFormat = RegExp(
        r'(HEREDOFAMILIARES?|NO PATOL[OÓ]GICOS?|PATOL[OÓ]GICOS?):',
        caseSensitive: false,
      ).hasMatch(antecedentes);

      if (hasStructuredFormat) {
        // Parse structured format
        final heredoMatch = RegExp(
          r'HEREDOFAMILIARES?:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
          caseSensitive: false,
        ).firstMatch(antecedentes);

        final noPatoMatch = RegExp(
          r'NO PATOL[OÓ]GICOS?:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
          caseSensitive: false,
        ).firstMatch(antecedentes);

        final patoMatch = RegExp(
          r'(?<!NO )PATOL[OÓ]GICOS?:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
          caseSensitive: false,
        ).firstMatch(antecedentes);

        heredofamiliares = heredoMatch?.group(1)?.trim() ?? '';
        noPatologicos = noPatoMatch?.group(1)?.trim() ?? '';
        patologicos = patoMatch?.group(1)?.trim() ?? '';
      } else {
        // Unstructured: put all in heredofamiliares as fallback
        heredofamiliares = antecedentes;
      }
    }

    return PatientPrefill(
      patientId: patientId,
      sourceNoteId: noteId,
      sourceNoteDate: noteDate,
      heredofamiliares: heredofamiliares,
      noPatologicos: noPatologicos,
      patologicos: patologicos,
    );
  }
}
