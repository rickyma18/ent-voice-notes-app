// lib/src/features/medical_notes/data/datasources/medical_notes_fake_datasource.dart

import '../../domain/entities/note_status.dart';
import '../models/medical_note_model.dart';
import 'medical_notes_remote_datasource.dart';

/// FAKE in-memory implementation of MedicalNotesRemoteDatasource
///
/// PURPOSE:
/// - Temporary implementation for US 1.1 - US 1.3 to allow testing without Firebase/Firestore
/// - Stores all notes in static in-memory Map (_notesStore)
/// - Data persists during app session but is lost on restart
/// - Pre-populated with 4 sample medical notes for demo purposes
///
/// CURRENT USAGE:
/// - Wired through medical_notes_providers.dart as the current remote datasource
/// - All CRUD operations (create, read, update, delete) are fully functional
/// - Simulates network delays (300-500ms) for realistic behavior
///
/// TODO (EPIC 5 - Real Backend Integration):
/// - This class will remain in codebase for testing purposes
/// - Switch to MedicalNotesRemoteDatasourceImpl (Firestore) in medical_notes_providers.dart
/// - No changes needed to repository or other layers when switching
final class FakeMedicalNotesRemoteDatasource
    extends MedicalNotesRemoteDatasource {
  FakeMedicalNotesRemoteDatasource() {
    _initializeSampleData();
  }

  // In-memory storage: Map<noteId, MedicalNoteModel>
  static final Map<String, MedicalNoteModel> _notesStore = {};
  static int _idCounter = 1;

  /// Initialize with sample data for testing
  void _initializeSampleData() {
    if (_notesStore.isEmpty) {
      final now = DateTime.now();

      // Sample notes for demo patient
      final sampleNotes = [
        MedicalNoteModel(
          id: 'note-001',
          patientId: 'patient-demo-001',
          doctorId: 'doctor-001',
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(days: 2)),
          motivoConsulta: 'Dolor de oído derecho persistente',
          antecedentes: 'Paciente con antecedentes de otitis media crónica',
          exploracionFisicaOrl:
              'Otoscopia: membrana timpánica derecha hiperémia, sin perforación',
          diagnostico: 'Otitis media aguda derecha',
          planTratamiento:
              'Amoxicilina 500mg cada 8 horas por 7 días. Control en 1 semana.',
          rawTranscript:
              'Paciente refiere dolor de oído derecho desde hace 3 días...',
          resumen: 'Otitis media aguda derecha. Tratamiento antibiótico.',
          status: NoteStatus.signed,
          tags: const ['otitis', 'urgente'],
          isFavorite: false,
        ),
        MedicalNoteModel(
          id: 'note-002',
          patientId: 'patient-demo-001',
          doctorId: 'doctor-001',
          createdAt: now.subtract(const Duration(days: 7)),
          updatedAt: now.subtract(const Duration(days: 7)),
          motivoConsulta: 'Revisión de rinitis alérgica',
          antecedentes: 'Rinitis alérgica estacional diagnosticada hace 2 años',
          exploracionFisicaOrl:
              'Rinoscopia: mucosa nasal pálida y edematosa, cornetes hipertróficos',
          diagnostico: 'Rinitis alérgica perenne',
          planTratamiento:
              'Continuar con antihistamínicos. Corticoides nasales.',
          rawTranscript: 'Paciente con congestión nasal crónica...',
          resumen: 'Control de rinitis alérgica. Tratamiento sintomático.',
          status: NoteStatus.signed,
          tags: const ['rinitis', 'alergia'],
          isFavorite: true,
        ),
        MedicalNoteModel(
          id: 'note-003',
          patientId: 'patient-demo-001',
          doctorId: 'doctor-001',
          createdAt: now.subtract(const Duration(hours: 5)),
          updatedAt: now.subtract(const Duration(hours: 5)),
          motivoConsulta: 'Ronquidos nocturnos y somnolencia diurna',
          antecedentes: 'Sobrepeso. No antecedentes de apnea del sueño.',
          exploracionFisicaOrl:
              'Orofaringe: paladar redundante, úvula elongada. Amígdalas grado II.',
          diagnostico: 'Sospecha de síndrome de apnea obstructiva del sueño',
          planTratamiento:
              'Solicitar polisomnografía. Valorar CPAP según resultados.',
          rawTranscript:
              'Paciente refiere ronquidos intensos y cansancio durante el día...',
          status: NoteStatus.draft,
          tags: const ['apnea', 'ronquidos'],
          isFavorite: false,
        ),
        MedicalNoteModel(
          id: 'note-004',
          patientId: 'patient-demo-001',
          doctorId: 'doctor-001',
          createdAt: now.subtract(const Duration(days: 15)),
          updatedAt: now.subtract(const Duration(days: 15)),
          motivoConsulta: 'Pérdida de audición progresiva',
          antecedentes: 'Exposición a ruido laboral por 10 años',
          exploracionFisicaOrl:
              'Otoscopia bilateral normal. Audiometría: hipoacusia neurosensorial bilateral.',
          diagnostico: 'Hipoacusia neurosensorial por ruido',
          planTratamiento:
              'Valoración para adaptación de audífonos. Protección auditiva.',
          rawTranscript:
              'Paciente con dificultad para escuchar conversaciones...',
          resumen: 'Hipoacusia ocupacional. Requiere audífonos.',
          status: NoteStatus.sent,
          tags: const ['hipoacusia', 'laboral'],
          isFavorite: false,
        ),
      ];

      for (final note in sampleNotes) {
        _notesStore[note.id] = note;
      }

      _idCounter = 5; // Next available ID
    }
  }

  @override
  Future<List<MedicalNoteModel>> getNotesByPatient(
    String patientId,
    String doctorId,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // CRITICAL: Filter by BOTH patient_id AND doctor_id for security
    // Matches real Firestore implementation behavior
    final notes = _notesStore.values
        .where(
          (note) => note.patientId == patientId && note.doctorId == doctorId,
        )
        .toList();

    // Sort by createdAt descending (most recent first)
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return notes;
  }

  @override
  Future<List<MedicalNoteModel>> getNotesByDoctor(String doctorId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    final notes = _notesStore.values
        .where((note) => note.doctorId == doctorId)
        .toList();

    // Sort by createdAt descending (most recent first)
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return notes;
  }

  @override
  Future<MedicalNoteModel?> getNoteById(String id) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    return _notesStore[id];
  }

  @override
  Future<String> createNote(MedicalNoteModel note) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 400));

    // Generate a new ID
    final newId = 'note-${_idCounter.toString().padLeft(3, '0')}';
    _idCounter++;

    // Create a copy with the generated ID
    final newNote = MedicalNoteModel(
      id: newId,
      patientId: note.patientId,
      doctorId: note.doctorId,
      createdAt: note.createdAt,
      updatedAt: DateTime.now(),
      motivoConsulta: note.motivoConsulta,
      antecedentes: note.antecedentes,
      exploracionFisicaOrl: note.exploracionFisicaOrl,
      diagnostico: note.diagnostico,
      planTratamiento: note.planTratamiento,
      rawTranscript: note.rawTranscript,
      resumen: note.resumen,
      notaAdicional: note.notaAdicional,
      status: note.status,
      medicamentosRecetados: note.medicamentosRecetados,
      estudiosIndicados: note.estudiosIndicados,
      proximaCita: note.proximaCita,
      attachments: note.attachments,
      tags: note.tags,
      isFavorite: note.isFavorite,
    );

    _notesStore[newId] = newNote;

    return newId;
  }

  @override
  Future<void> updateNote(MedicalNoteModel note) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 400));

    if (!_notesStore.containsKey(note.id)) {
      throw Exception('Note with ID ${note.id} not found');
    }

    // Update the note with current timestamp
    final updatedNote = MedicalNoteModel(
      id: note.id,
      patientId: note.patientId,
      doctorId: note.doctorId,
      createdAt: note.createdAt,
      updatedAt: DateTime.now(),
      motivoConsulta: note.motivoConsulta,
      antecedentes: note.antecedentes,
      exploracionFisicaOrl: note.exploracionFisicaOrl,
      diagnostico: note.diagnostico,
      planTratamiento: note.planTratamiento,
      rawTranscript: note.rawTranscript,
      resumen: note.resumen,
      notaAdicional: note.notaAdicional,
      status: note.status,
      medicamentosRecetados: note.medicamentosRecetados,
      estudiosIndicados: note.estudiosIndicados,
      proximaCita: note.proximaCita,
      attachments: note.attachments,
      tags: note.tags,
      isFavorite: note.isFavorite,
    );

    _notesStore[note.id] = updatedNote;
  }

  @override
  Future<void> deleteNote(String id) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    if (!_notesStore.containsKey(id)) {
      throw Exception('Note with ID $id not found');
    }

    _notesStore.remove(id);
  }

  @override
  Future<MedicalNoteModel?> getLatestNoteByPatient(
    String patientId,
    String doctorId,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    final notes = _notesStore.values
        .where(
          (note) => note.patientId == patientId && note.doctorId == doctorId,
        )
        .toList();

    if (notes.isEmpty) {
      return null;
    }

    // Sort by createdAt descending and return the first one
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes.first;
  }

  /// Utility method to clear all data (useful for testing)
  static void clearAll() {
    _notesStore.clear();
    _idCounter = 1;
  }

  /// Utility method to get total count of notes in store
  static int get totalNotesCount => _notesStore.length;
}
