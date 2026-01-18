// lib/src/features/medical_notes/data/datasources/medical_notes_local_datasource.dart

import '../models/medical_note_model.dart';

/// Data source local para notas médicas.
///
/// De momento es solo un esqueleto: no persiste nada realmente.
/// Más adelante lo puedes conectar a Hive, Isar, SharedPreferences, etc.
abstract base class MedicalNotesLocalDatasource {
  /// Obtiene las notas en caché para un paciente.
  Future<List<MedicalNoteModel>> getCachedNotes(String patientId);

  /// Guarda en caché las notas de un paciente.
  Future<void> cacheNotes(String patientId, List<MedicalNoteModel> notes);

  /// Limpia la caché de notas de un paciente.
  Future<void> clearCachedNotes(String patientId);
}

/// Implementación "no-op" (no hace nada) por ahora.
/// Sirve solo para que el resto de la arquitectura compile.
final class MedicalNotesLocalDatasourceImpl
    implements MedicalNotesLocalDatasource {
  MedicalNotesLocalDatasourceImpl();

  // En memoria temporal (solo para evitar null, no es persistente)
  final Map<String, List<MedicalNoteModel>> _cache = {};

  @override
  Future<List<MedicalNoteModel>> getCachedNotes(String patientId) async {
    return _cache[patientId] ?? const <MedicalNoteModel>[];
  }

  @override
  Future<void> cacheNotes(
    String patientId,
    List<MedicalNoteModel> notes,
  ) async {
    _cache[patientId] = List<MedicalNoteModel>.from(notes);
  }

  @override
  Future<void> clearCachedNotes(String patientId) async {
    _cache.remove(patientId);
  }
}
