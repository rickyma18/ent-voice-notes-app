import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/patients/data/models/patient_model.dart';
import 'package:medical_notes_app/src/features/patients/domain/entities/biological_sex.dart';
import 'package:medical_notes_app/src/features/patients/domain/entities/patient_entity.dart';

void main() {
  group('BiologicalSex', () {
    test('values are M and F only', () {
      expect(BiologicalSex.values.length, equals(2));
      expect(BiologicalSex.male.code, equals('M'));
      expect(BiologicalSex.female.code, equals('F'));
    });

    test('tryFromCode returns correct values for M', () {
      expect(BiologicalSex.tryFromCode('M'), equals(BiologicalSex.male));
      expect(BiologicalSex.tryFromCode('m'), equals(BiologicalSex.male));
      expect(BiologicalSex.tryFromCode(' M '), equals(BiologicalSex.male));
    });

    test('tryFromCode returns correct values for F', () {
      expect(BiologicalSex.tryFromCode('F'), equals(BiologicalSex.female));
      expect(BiologicalSex.tryFromCode('f'), equals(BiologicalSex.female));
      expect(BiologicalSex.tryFromCode(' F '), equals(BiologicalSex.female));
    });

    test('tryFromCode returns null for invalid values', () {
      expect(BiologicalSex.tryFromCode('O'), isNull);
      expect(BiologicalSex.tryFromCode('Otro'), isNull);
      expect(BiologicalSex.tryFromCode('X'), isNull);
      expect(BiologicalSex.tryFromCode(''), isNull);
      expect(BiologicalSex.tryFromCode(null), isNull);
    });

    test('fromCode throws for invalid values', () {
      expect(() => BiologicalSex.fromCode('O'), throwsArgumentError);
      expect(() => BiologicalSex.fromCode('Otro'), throwsArgumentError);
      expect(() => BiologicalSex.fromCode('X'), throwsArgumentError);
    });

    test('isValidCode returns correct results', () {
      expect(BiologicalSex.isValidCode('M'), isTrue);
      expect(BiologicalSex.isValidCode('F'), isTrue);
      expect(BiologicalSex.isValidCode('m'), isTrue);
      expect(BiologicalSex.isValidCode('f'), isTrue);
      expect(BiologicalSex.isValidCode('O'), isFalse);
      expect(BiologicalSex.isValidCode('Otro'), isFalse);
      expect(BiologicalSex.isValidCode(null), isFalse);
    });

    test('displayName returns correct values', () {
      expect(BiologicalSex.male.displayName, equals('Masculino'));
      expect(BiologicalSex.female.displayName, equals('Femenino'));
    });
  });

  group('PatientEntity', () {
    test('sexDisplay returns Masculino for M', () {
      const patient = PatientEntity(
        id: '1',
        fullName: 'Test',
        age: 30,
        sex: 'M',
      );
      expect(patient.sexDisplay, equals('Masculino'));
    });

    test('sexDisplay returns Femenino for F', () {
      const patient = PatientEntity(
        id: '1',
        fullName: 'Test',
        age: 30,
        sex: 'F',
      );
      expect(patient.sexDisplay, equals('Femenino'));
    });

    test('sexDisplay returns No especificado for legacy values', () {
      const patient = PatientEntity(
        id: '1',
        fullName: 'Test',
        age: 30,
        sex: 'O', // Legacy value
      );
      expect(patient.sexDisplay, equals('No especificado'));
    });

    test('hasValidSex returns true for M and F', () {
      const malePatient = PatientEntity(
        id: '1',
        fullName: 'Test',
        age: 30,
        sex: 'M',
      );
      const femalePatient = PatientEntity(
        id: '1',
        fullName: 'Test',
        age: 30,
        sex: 'F',
      );
      expect(malePatient.hasValidSex, isTrue);
      expect(femalePatient.hasValidSex, isTrue);
    });

    test('hasValidSex returns false for legacy values', () {
      const legacyPatient = PatientEntity(
        id: '1',
        fullName: 'Test',
        age: 30,
        sex: 'Otro',
      );
      expect(legacyPatient.hasValidSex, isFalse);
    });
  });

  group('PatientModel.fromEntity validation', () {
    test('accepts M as valid sex', () {
      const entity = PatientEntity(
        id: '1',
        fullName: 'Test Patient',
        age: 30,
        sex: 'M',
        doctorId: 'doc1',
      );

      // Should not throw
      final model = PatientModel.fromEntity(entity);
      expect(model.sex, equals('M'));
    });

    test('accepts F as valid sex', () {
      const entity = PatientEntity(
        id: '1',
        fullName: 'Test Patient',
        age: 30,
        sex: 'F',
        doctorId: 'doc1',
      );

      // Should not throw
      final model = PatientModel.fromEntity(entity);
      expect(model.sex, equals('F'));
    });

    test('rejects O as invalid sex', () {
      const entity = PatientEntity(
        id: '1',
        fullName: 'Test Patient',
        age: 30,
        sex: 'O',
        doctorId: 'doc1',
      );

      expect(() => PatientModel.fromEntity(entity), throwsArgumentError);
    });

    test('rejects Otro as invalid sex', () {
      const entity = PatientEntity(
        id: '1',
        fullName: 'Test Patient',
        age: 30,
        sex: 'Otro',
        doctorId: 'doc1',
      );

      expect(() => PatientModel.fromEntity(entity), throwsArgumentError);
    });

    test('rejects empty string as invalid sex', () {
      const entity = PatientEntity(
        id: '1',
        fullName: 'Test Patient',
        age: 30,
        sex: '',
        doctorId: 'doc1',
      );

      expect(() => PatientModel.fromEntity(entity), throwsArgumentError);
    });

    test('error message is user-friendly', () {
      const entity = PatientEntity(
        id: '1',
        fullName: 'Test Patient',
        age: 30,
        sex: 'X',
        doctorId: 'doc1',
      );

      try {
        PatientModel.fromEntity(entity);
        fail('Should have thrown');
      } on ArgumentError catch (e) {
        expect(e.message, contains('Sexo inválido'));
        expect(e.message, contains('Masculino'));
        expect(e.message, contains('Femenino'));
      }
    });
  });
}
