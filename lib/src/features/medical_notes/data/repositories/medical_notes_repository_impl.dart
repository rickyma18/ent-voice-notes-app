// lib/src/features/medical_notes/data/repositories/medical_notes_repository_impl.dart

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/repositories/medical_notes_repository.dart';
import '../datasources/medical_notes_local_datasource.dart';
import '../datasources/medical_notes_remote_datasource.dart';
import '../models/medical_note_model.dart';

/// Implementación del repositorio de notas médicas.
///
/// - Data layer: usa [MedicalNotesRemoteDatasource] (Firestore) y, opcionalmente,
///   [MedicalNotesLocalDatasource] para cache/local (aún sin usar).
/// - Domain layer: expone y consume [MedicalNoteEntity].
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
  ) async {
    // 🔹 Solo usamos remoto por ahora. Más adelante puedes agregar cache local.
    final models = await remoteDatasource.getNotesByPatient(patientId);

    final entities = models.map((m) => m.toEntity()).toList();

    // ⛔ IMPORTANTE:
    // Ajusta esta línea según cómo se construye un Result exitoso en tu proyecto.
    return Result.success(entities);
  }

  @override
  Future<Result<MedicalNoteEntity?, Failure>> getNoteById(
    String id,
  ) async {
    final model = await remoteDatasource.getNoteById(id);

    final entity = model?.toEntity();

    return Result.success(entity);
  }

  @override
  Future<Result<MedicalNoteEntity, Failure>> createNote(
    MedicalNoteEntity note,
  ) async {
    // 1) Convertimos la entidad de dominio a modelo de datos
    final model = MedicalNoteModel.fromEntity(note);

    // 2) Creamos la nota en Firestore
    final newId = await remoteDatasource.createNote(model);

    // 3) Volvemos a leerla desde remoto para tener la versión "real"
    final createdModel = await remoteDatasource.getNoteById(newId);

    if (createdModel == null) {
      // Aquí podrías mapear a un Failure más específico
      throw Exception('Created medical note not found after Firestore insert.');
    }

    final entity = createdModel.toEntity();

    return Result.success(entity);
  }

  @override
  Future<Result<MedicalNoteEntity, Failure>> updateNote(
    MedicalNoteEntity note,
  ) async {
    // Convertimos la entidad a modelo
    final model = MedicalNoteModel.fromEntity(note);

    // Actualizamos en Firestore
    await remoteDatasource.updateNote(model);

    // Opciones:
    // - O vuelves a leer la nota desde remoto para asegurarte (más I/O),
    // - O devuelves la misma entidad que recibiste (más rápido).
    //
    // Aquí devolvemos la misma entidad que recibimos:
    return Result.success(note);
  }

  @override
  Future<Result<void, Failure>> deleteNote(String id) async {
    await remoteDatasource.deleteNote(id);

    // Según tu implementación de Result<void, Failure>, puede que no necesites
    // pasar ningún valor. Si tu Result tiene otra forma, ajusta esta línea.
    return Result.success(null);
  }
}
