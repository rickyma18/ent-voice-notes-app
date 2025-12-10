// lib/src/features/medical_notes/data/datasources/medical_notes_remote_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/medical_note_model.dart';

/// Data source remoto para manejar notas médicas en Firestore.
///
/// Aquí solo trabajamos con [MedicalNoteModel] y mapas JSON.
/// La conversión a entidades de dominio se hace en el repositorio.
abstract base class MedicalNotesRemoteDatasource {
  /// Obtiene todas las notas de un paciente específico.
  ///
  /// Devuelve la lista de modelos ordenados por `created_at` (descendente),
  /// siempre que el campo exista.
  Future<List<MedicalNoteModel>> getNotesByPatient(String patientId);

  /// Obtiene una nota médica por su ID de documento en Firestore.
  ///
  /// Devuelve null si el documento no existe.
  Future<MedicalNoteModel?> getNoteById(String id);

  /// Crea una nueva nota médica en Firestore.
  ///
  /// Devuelve el documentId generado por Firestore.
  Future<String> createNote(MedicalNoteModel note);

  /// Actualiza una nota médica existente en Firestore.
  Future<void> updateNote(MedicalNoteModel note);

  /// Elimina una nota médica por su ID.
  Future<void> deleteNote(String id);
}

final class MedicalNotesRemoteDatasourceImpl
    implements MedicalNotesRemoteDatasource {
  MedicalNotesRemoteDatasourceImpl({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('medical_notes');

  @override
  Future<List<MedicalNoteModel>> getNotesByPatient(
    String patientId,
  ) async {
    final querySnapshot = await _collection
        .where('patient_id', isEqualTo: patientId)
        .orderBy('created_at', descending: true)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();

      // Aseguramos que el campo "id" interno coincida con doc.id
      data['id'] ??= doc.id;

      return MedicalNoteModel.fromJson(data);
    }).toList();
  }

  @override
  Future<MedicalNoteModel?> getNoteById(String id) async {
    final docSnapshot = await _collection.doc(id).get();

    if (!docSnapshot.exists) {
      return null;
    }

    final data = docSnapshot.data();
    if (data == null) return null;

    data['id'] ??= docSnapshot.id;

    return MedicalNoteModel.fromJson(data);
  }

  @override
  Future<String> createNote(MedicalNoteModel note) async {
    // Tomamos el JSON tal cual lo define el modelo
    final data = note.toJson();

    // Para evitar inconsistencias, quitamos cualquier "id" que venga del modelo
    data.remove('id');

    final docRef = await _collection.add(data);

    // Guardamos el id también dentro del documento, ya que tu modelo lo usa
    await docRef.update({'id': docRef.id});

    return docRef.id;
  }

  @override
  Future<void> updateNote(MedicalNoteModel note) async {
    // El modelo ya tiene un id lógico
    final noteId = note.id;

    final data = note.toJson()
      ..['id'] = noteId; // Aseguramos que el campo id coincida

    await _collection.doc(noteId).update(data);
  }

  @override
  Future<void> deleteNote(String id) async {
    await _collection.doc(id).delete();
  }
}
