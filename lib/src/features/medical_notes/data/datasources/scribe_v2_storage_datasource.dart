// lib/src/features/medical_notes/data/datasources/scribe_v2_storage_datasource.dart
//
// Firestore datasource for persisting Scribe V2 pipeline results.
// Stores data as subdocument: medical_notes/{noteId}/scribe_v2/latest

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../../../core/logger/log.dart';
import '../models/pipeline_telemetry_model.dart';
import '../models/scribe_v2_result_model.dart';

/// Datasource for storing and retrieving Scribe V2 results in Firestore.
///
/// Storage location: `medical_notes/{noteId}/scribe_v2/latest`
///
/// This uses a subcollection approach to:
/// - Keep the main medical_notes document lean
/// - Allow independent access to Scribe V2 data
/// - Avoid document size issues with large transcripts
class ScribeV2StorageDatasource {
  ScribeV2StorageDatasource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Collection name for medical notes
  static const String _medicalNotesCollection = 'medical_notes';

  /// Subcollection name for Scribe V2 data
  static const String _scribeV2Subcollection = 'scribe_v2';

  /// Document ID for the latest result
  static const String _latestDocId = 'latest';

  /// Gets the reference to the scribe_v2/latest document for a note.
  DocumentReference<Map<String, dynamic>> _getLatestDocRef(String noteId) {
    return _firestore
        .collection(_medicalNotesCollection)
        .doc(noteId)
        .collection(_scribeV2Subcollection)
        .doc(_latestDocId);
  }

  /// Persists a Scribe V2 result to Firestore.
  ///
  /// Creates or overwrites the `scribe_v2/latest` subdocument.
  ///
  /// Returns [Result.success] with the stored model on success,
  /// or [Result.error] with a [Failure] on error.
  Future<Result<ScribeV2ResultModel, Failure>> persistResult({
    required String noteId,
    required ScribeV2ResultModel result,
  }) async {
    if (noteId.isEmpty) {
      return Result.error(
        Failure(
          type: FailureType.validation,
          message: 'Note ID cannot be empty',
        ),
      );
    }

    try {
      final docRef = _getLatestDocRef(noteId);
      final data = result.toFirestore();

      // Add/update timestamp
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: false));

      // Don't log full transcript in release mode
      assert(() {
        Log.info(
          '[ScribeV2Storage] Persisted result for note $noteId '
          '(${result.transcriptSegments.length} segments, '
          'source: ${result.metadata.source})',
        );
        return true;
      }());

      return Result.success(result);
    } on FirebaseException catch (e) {
      Log.error(
        '[ScribeV2Storage] Firebase error persisting result: ${e.message}',
      );
      return Result.error(Failure.mapExceptionToFailure(e));
    } catch (e, st) {
      Log.error('[ScribeV2Storage] Unexpected error persisting result: $e');
      return Result.error(
        Failure(
          type: FailureType.unknown,
          message: 'Error inesperado al guardar resultado Scribe V2: $e',
          stackTrace: st,
        ),
      );
    }
  }

  /// Retrieves the latest Scribe V2 result for a note.
  ///
  /// Returns [Result.success] with the model if found,
  /// [Result.success] with null if not found,
  /// or [Result.error] on failure.
  Future<Result<ScribeV2ResultModel?, Failure>> getLatestResult(
    String noteId,
  ) async {
    if (noteId.isEmpty) {
      return Result.error(
        Failure(
          type: FailureType.validation,
          message: 'Note ID cannot be empty',
        ),
      );
    }

    try {
      final docRef = _getLatestDocRef(noteId);
      final snapshot = await docRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        return const Result.success(null);
      }

      final model = ScribeV2ResultModel.fromFirestore(snapshot.data()!);
      return Result.success(model);
    } on FirebaseException catch (e) {
      Log.error(
        '[ScribeV2Storage] Firebase error getting result: ${e.message}',
      );
      return Result.error(Failure.mapExceptionToFailure(e));
    } catch (e, st) {
      Log.error('[ScribeV2Storage] Unexpected error getting result: $e');
      return Result.error(
        Failure(
          type: FailureType.unknown,
          message: 'Error inesperado al obtener resultado Scribe V2: $e',
          stackTrace: st,
        ),
      );
    }
  }

  /// Checks if a Scribe V2 result exists for a note.
  Future<Result<bool, Failure>> hasResult(String noteId) async {
    if (noteId.isEmpty) {
      return Result.error(
        Failure(
          type: FailureType.validation,
          message: 'Note ID cannot be empty',
        ),
      );
    }

    try {
      final docRef = _getLatestDocRef(noteId);
      final snapshot = await docRef.get();
      return Result.success(snapshot.exists);
    } on FirebaseException catch (e) {
      return Result.error(Failure.mapExceptionToFailure(e));
    } catch (e, st) {
      return Result.error(
        Failure(
          type: FailureType.unknown,
          message: 'Error inesperado: $e',
          stackTrace: st,
        ),
      );
    }
  }

  /// Deletes the Scribe V2 result for a note.
  ///
  /// Called when a note is deleted to clean up associated data.
  Future<Result<void, Failure>> deleteResult(String noteId) async {
    if (noteId.isEmpty) {
      return Result.error(
        Failure(
          type: FailureType.validation,
          message: 'Note ID cannot be empty',
        ),
      );
    }

    try {
      final docRef = _getLatestDocRef(noteId);
      await docRef.delete();

      assert(() {
        Log.info('[ScribeV2Storage] Deleted result for note $noteId');
        return true;
      }());

      return const Result.success(null);
    } on FirebaseException catch (e) {
      Log.error(
        '[ScribeV2Storage] Firebase error deleting result: ${e.message}',
      );
      return Result.error(Failure.mapExceptionToFailure(e));
    } catch (e, st) {
      Log.error('[ScribeV2Storage] Unexpected error deleting result: $e');
      return Result.error(
        Failure(
          type: FailureType.unknown,
          message: 'Error inesperado al eliminar resultado Scribe V2: $e',
          stackTrace: st,
        ),
      );
    }
  }

  /// Persists Scribe V2 telemetry metrics to Firestore.
  ///
  /// Stores data at: `medical_notes/{noteId}/telemetry/latest`
  ///
  /// This subcollection stores ONLY non-PHI technical metrics.
  Future<Result<void, Failure>> persistTelemetry({
    required String noteId,
    required PipelineTelemetryModel telemetry,
  }) async {
    if (noteId.isEmpty) {
      return Result.error(
        Failure(
          type: FailureType.validation,
          message: 'Note ID cannot be empty',
        ),
      );
    }

    try {
      final telemetryRef = _firestore
          .collection(_medicalNotesCollection)
          .doc(noteId)
          .collection('telemetry')
          .doc('latest');

      final data = telemetry.toFirestore();

      // Ensure server timestamp match
      data['createdAt'] = FieldValue.serverTimestamp();

      await telemetryRef.set(data, SetOptions(merge: false));

      assert(() {
        Log.info(
          '[ScribeV2Storage] Persisted telemetry for note $noteId '
          '(total: ${telemetry.timings.totalMs}ms)',
        );
        return true;
      }());

      return const Result.success(null);
    } on FirebaseException catch (e) {
      Log.error(
        '[ScribeV2Storage] Firebase error persisting telemetry: ${e.message}',
      );
      // Don't fail the whole operation if telemetry fails
      return Result.error(Failure.mapExceptionToFailure(e));
    } catch (e, st) {
      Log.error('[ScribeV2Storage] Unexpected error persisting telemetry: $e');
      return Result.error(
        Failure(
          type: FailureType.unknown,
          message: 'Error inesperado al guardar telemetría: $e',
          stackTrace: st,
        ),
      );
    }
  }
}
