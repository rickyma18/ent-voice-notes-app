// test/features/medical_notes/application/note_quality_gate_service_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_notes_app/src/features/medical_notes/application/note_quality_gate_service_impl.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/entities/medical_note_entity.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/entities/note_status.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/entities/quality_gate_result.dart';

void main() {
  late NoteQualityGateServiceImpl service;

  setUp(() {
    service = const NoteQualityGateServiceImpl();
  });

  group('NoteQualityGateService.evaluate', () {
    test('should PASS when all critical fields are filled', () {
      // Arrange
      final note = _createNote(
        motivoConsulta: 'Dolor de oído derecho desde hace 3 días',
        diagnostico: 'Otitis media aguda',
        planTratamiento: 'Amoxicilina 500mg cada 8 horas por 7 días',
      );

      // Act
      final result = service.evaluate(note);

      // Assert
      expect(result.pass, isTrue);
      expect(result.missingCritical, isEmpty);
    });

    test('should FAIL when motivo de consulta is missing', () {
      // Arrange
      final note = _createNote(
        motivoConsulta: '', // Empty
        diagnostico: 'Otitis media aguda',
        planTratamiento: 'Amoxicilina 500mg',
      );

      // Act
      final result = service.evaluate(note);

      // Assert
      expect(result.pass, isFalse);
      expect(result.missingCritical, contains(CriticalField.chiefComplaint));
      expect(result.missingCritical.length, 1);
    });

    test('should FAIL when diagnóstico is missing', () {
      // Arrange
      final note = _createNote(
        motivoConsulta: 'Dolor de oído',
        diagnostico: '', // Empty
        planTratamiento: 'Amoxicilina 500mg',
      );

      // Act
      final result = service.evaluate(note);

      // Assert
      expect(result.pass, isFalse);
      expect(result.missingCritical, contains(CriticalField.diagnosis));
      expect(result.missingCritical.length, 1);
    });

    test('should FAIL when plan de tratamiento is missing', () {
      // Arrange
      final note = _createNote(
        motivoConsulta: 'Dolor de oído',
        diagnostico: 'Otitis media aguda',
        planTratamiento: '', // Empty
      );

      // Act
      final result = service.evaluate(note);

      // Assert
      expect(result.pass, isFalse);
      expect(result.missingCritical, contains(CriticalField.plan));
      expect(result.missingCritical.length, 1);
    });

    test('should FAIL when multiple critical fields are missing', () {
      // Arrange
      final note = _createNote(
        motivoConsulta: '', // Empty
        diagnostico: '', // Empty
        planTratamiento: '', // Empty
      );

      // Act
      final result = service.evaluate(note);

      // Assert
      expect(result.pass, isFalse);
      expect(result.missingCritical.length, 3);
      expect(result.missingCritical, contains(CriticalField.chiefComplaint));
      expect(result.missingCritical, contains(CriticalField.diagnosis));
      expect(result.missingCritical, contains(CriticalField.plan));
    });

    test('should reject fields with only whitespace', () {
      // Arrange
      final note = _createNote(
        motivoConsulta: '   ', // Only whitespace
        diagnostico: '\t\n', // Only whitespace
        planTratamiento: 'Plan válido con más de 3 caracteres',
      );

      // Act
      final result = service.evaluate(note);

      // Assert
      expect(result.pass, isFalse);
      expect(result.missingCritical, contains(CriticalField.chiefComplaint));
      expect(result.missingCritical, contains(CriticalField.diagnosis));
    });

    test('should reject fields with less than minimum length', () {
      // Arrange (minimum is 3 characters)
      final note = _createNote(
        motivoConsulta: 'ab', // Only 2 chars
        diagnostico: 'Valid diagnosis text',
        planTratamiento: 'Valid plan text',
      );

      // Act
      final result = service.evaluate(note);

      // Assert
      expect(result.pass, isFalse);
      expect(result.missingCritical, contains(CriticalField.chiefComplaint));
    });

    test('should generate warnings for empty non-critical fields', () {
      // Arrange
      final note = _createNote(
        motivoConsulta: 'Dolor de oído',
        diagnostico: 'Otitis',
        planTratamiento: 'Amoxicilina',
        antecedentes: '', // Empty non-critical
        exploracionFisicaOrl: '', // Empty non-critical
      );

      // Act
      final result = service.evaluate(note);

      // Assert
      expect(result.pass, isTrue); // Should still pass
      expect(result.warnings, contains('Antecedentes no completados'));
      expect(result.warnings, contains('Exploración física no completada'));
    });

    test('errorMessage should list missing fields in Spanish', () {
      // Arrange
      final note = _createNote(
        motivoConsulta: '',
        diagnostico: '',
        planTratamiento: 'Plan válido',
      );

      // Act
      final result = service.evaluate(note);

      // Assert
      expect(result.errorMessage, contains('Motivo de consulta'));
      expect(result.errorMessage, contains('Diagnóstico'));
      expect(result.errorMessage, isNot(contains('Plan de tratamiento')));
    });
  });

  group('NoteQualityGateService.validateForSigning', () {
    test('should PASS for complete draft note', () {
      // Arrange
      final note = _createNote(
        motivoConsulta: 'Dolor de oído',
        diagnostico: 'Otitis media',
        planTratamiento: 'Antibióticos',
        status: NoteStatus.draft,
      );

      // Act
      final result = service.validateForSigning(note);

      // Assert
      expect(result.pass, isTrue);
    });

    test('should PASS for complete inReview note', () {
      // Arrange
      final note = _createNote(
        motivoConsulta: 'Dolor de oído',
        diagnostico: 'Otitis media',
        planTratamiento: 'Antibióticos',
        status: NoteStatus.inReview,
      );

      // Act
      final result = service.validateForSigning(note);

      // Assert
      expect(result.pass, isTrue);
    });

    test('should add warning for already signed note', () {
      // Arrange
      final note = _createNote(
        motivoConsulta: 'Dolor de oído',
        diagnostico: 'Otitis media',
        planTratamiento: 'Antibióticos',
        status: NoteStatus.signed,
      );

      // Act
      final result = service.validateForSigning(note);

      // Assert
      // Note: canSign is false for signed notes, so warning is added
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('Firmada')),
        isTrue,
      );
    });

    test('should FAIL when critical fields are missing', () {
      // Arrange
      final note = _createNote(
        motivoConsulta: '',
        diagnostico: 'Otitis',
        planTratamiento: '',
        status: NoteStatus.draft,
      );

      // Act
      final result = service.validateForSigning(note);

      // Assert
      expect(result.pass, isFalse);
      expect(result.missingCritical, contains(CriticalField.chiefComplaint));
      expect(result.missingCritical, contains(CriticalField.plan));
    });
  });

  group('QualityGateResult', () {
    test('passed factory creates passing result', () {
      // Act
      final result = QualityGateResult.passed();

      // Assert
      expect(result.pass, isTrue);
      expect(result.missingCritical, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.errorMessage, isEmpty);
    });

    test('failed factory creates failing result', () {
      // Act
      final result = QualityGateResult.failed(
        missingCritical: [CriticalField.chiefComplaint, CriticalField.diagnosis],
        warnings: ['Some warning'],
      );

      // Assert
      expect(result.pass, isFalse);
      expect(result.missingCritical.length, 2);
      expect(result.warnings.length, 1);
    });

    test('missingSummary joins field names', () {
      // Arrange
      final result = QualityGateResult.failed(
        missingCritical: [CriticalField.chiefComplaint, CriticalField.plan],
      );

      // Assert
      expect(result.missingSummary, contains('Motivo de consulta'));
      expect(result.missingSummary, contains('Plan de tratamiento'));
    });
  });

  group('CriticalField', () {
    test('displayName returns Spanish labels', () {
      expect(CriticalField.chiefComplaint.displayName, 'Motivo de consulta');
      expect(CriticalField.diagnosis.displayName, 'Diagnóstico');
      expect(CriticalField.plan.displayName, 'Plan de tratamiento');
    });
  });
}

/// Helper to create test notes with minimal boilerplate.
MedicalNoteEntity _createNote({
  String motivoConsulta = '',
  String diagnostico = '',
  String planTratamiento = '',
  String antecedentes = '',
  String exploracionFisicaOrl = '',
  NoteStatus status = NoteStatus.draft,
}) {
  final now = DateTime.now();
  return MedicalNoteEntity(
    id: 'test-note-id',
    patientId: 'test-patient-id',
    doctorId: 'test-doctor-id',
    createdAt: now,
    updatedAt: now,
    motivoConsulta: motivoConsulta,
    antecedentes: antecedentes,
    exploracionFisicaOrl: exploracionFisicaOrl,
    diagnostico: diagnostico,
    planTratamiento: planTratamiento,
    rawTranscript: '',
    status: status,
  );
}
