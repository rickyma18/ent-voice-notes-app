// lib/src/features/medical_notes/data/datasources/medical_notes_remote_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/medical_note_model.dart';

/// Data source remoto para manejar notas médicas en Firestore.
///
/// Aquí solo trabajamos con [MedicalNoteModel] y mapas JSON.
/// La conversión a entidades de dominio se hace en el repositorio.
abstract base class MedicalNotesRemoteDatasource {
  /// Obtiene todas las notas de un paciente específico.
  ///
  /// IMPORTANT: Must filter by both patient_id AND doctor_id for security.
  /// Devuelve la lista de modelos ordenados por `created_at` (descendente).
  Future<List<MedicalNoteModel>> getNotesByPatient(
    String patientId,
    String doctorId,
  );

  /// US-D2: Obtiene todas las notas de un doctor específico.
  ///
  /// Devuelve la lista de modelos ordenados por `created_at` (descendente).
  Future<List<MedicalNoteModel>> getNotesByDoctor(String doctorId);

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

  /// Gets the most recent note for a patient (for prefill purposes).
  ///
  /// Returns null if no notes exist for this patient.
  /// Orders by created_at desc and limits to 1.
  Future<MedicalNoteModel?> getLatestNoteByPatient(
    String patientId,
    String doctorId,
  );
}

final class MedicalNotesRemoteDatasourceImpl
    implements MedicalNotesRemoteDatasource {
  MedicalNotesRemoteDatasourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('medical_notes');

  @override
  Future<List<MedicalNoteModel>> getNotesByPatient(
    String patientId,
    String doctorId,
  ) async {
    // CRITICAL: Filter by BOTH patient_id AND doctor_id for security rules
    final querySnapshot = await _collection
        .where('doctor_id', isEqualTo: doctorId)
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
  Future<List<MedicalNoteModel>> getNotesByDoctor(String doctorId) async {
    final querySnapshot = await _collection
        .where('doctor_id', isEqualTo: doctorId)
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
    final data = note.toJson();

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
  Future<void> updateNote(MedicalNoteModel note) async {
    final data = note.toJson();

    // Remove fields that shouldn't be updated
    data.remove('id');
    data.remove('created_at'); // Don't overwrite creation timestamp

    // Set server timestamp for update
    data['updated_at'] = FieldValue.serverTimestamp();

    await _collection.doc(note.id).update(data);
  }

  @override
  Future<void> deleteNote(String id) async {
    await _collection.doc(id).delete();
  }

  @override
  Future<MedicalNoteModel?> getLatestNoteByPatient(
    String patientId,
    String doctorId,
  ) async {
    assert(() {
      debugPrint('[Prefill][Firestore] QUERY: '
          'patientId="$patientId" doctorId="$doctorId"');
      return true;
    }());

    try {
      final querySnapshot = await _collection
          .where('doctor_id', isEqualTo: doctorId)
          .where('patient_id', isEqualTo: patientId)
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();

      assert(() {
        debugPrint('[Prefill][Firestore] RESULT: '
            'docsCount=${querySnapshot.docs.length}');
        return true;
      }());

      if (querySnapshot.docs.isEmpty) {
        assert(() {
          debugPrint('[Prefill][Firestore] NO DOCS found for patient');
          return true;
        }());
        return null;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();
      data['id'] ??= doc.id;

      assert(() {
        final createdAt = data['created_at'];
        debugPrint('[Prefill][Firestore] DOC: id="${doc.id}" '
            'created_at=$createdAt '
            'hasStructuredFields=${data['structured_fields'] != null} '
            'hasStructuredV1=${data['structured_v1'] != null} '
            'antecedentes.len=${(data['antecedentes'] as String?)?.length ?? 0}');
        return true;
      }());

      return MedicalNoteModel.fromJson(data);
    } catch (e, st) {
      // Log exception details (may be index missing or other Firestore error)
      assert(() {
        debugPrint('[Prefill][Firestore] EXCEPTION: $e');
        debugPrint('[Prefill][Firestore] STACK: $st');
        return true;
      }());
      // Also print in release for diagnostics
      debugPrint('[Prefill][Firestore] EXCEPTION: $e');
      rethrow;
    }
  }
}
