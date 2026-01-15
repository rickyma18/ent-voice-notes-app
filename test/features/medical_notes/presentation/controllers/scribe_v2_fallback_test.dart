// test/features/medical_notes/presentation/controllers/scribe_v2_fallback_test.dart
//
// Tests for Scribe V2 feature flag and fallback configuration.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medical_notes_app/src/features/medical_notes/medical_notes_providers.dart';
import 'package:medical_notes_app/src/features/medical_notes/presentation/controllers/medical_notes_controller.dart';

void main() {
  group('Scribe V2 Feature Flag Tests', () {
    test('useScribeV2ForNoteCreation default value is false', () {
      // Arrange
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Act
      final flagValue = container.read(useScribeV2ForNoteCreationProvider);

      // Assert
      expect(flagValue, isFalse);
    });

    test('useScribeV2ForNoteCreation can be overridden to true', () {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          useScribeV2ForNoteCreationProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final flagValue = container.read(useScribeV2ForNoteCreationProvider);

      // Assert
      expect(flagValue, isTrue);
    });

    test('MedicalNotesController.isScribeV2EnabledForCreation reflects flag', () {
      // Test with flag OFF
      final containerOff = ProviderContainer(
        overrides: [
          useScribeV2ForNoteCreationProvider.overrideWithValue(false),
        ],
      );
      addTearDown(containerOff.dispose);

      final controllerOff =
          containerOff.read(medicalNotesControllerProvider.notifier);
      expect(controllerOff.isScribeV2EnabledForCreation, isFalse);

      // Test with flag ON
      final containerOn = ProviderContainer(
        overrides: [
          useScribeV2ForNoteCreationProvider.overrideWithValue(true),
        ],
      );
      addTearDown(containerOn.dispose);

      final controllerOn =
          containerOn.read(medicalNotesControllerProvider.notifier);
      expect(controllerOn.isScribeV2EnabledForCreation, isTrue);
    });

    test('Source constants are defined correctly', () {
      expect(MedicalNotesController.kSourceScribeV2, 'scribe_v2');
      expect(MedicalNotesController.kSourceLegacy, 'legacy');
      expect(
        MedicalNotesController.kSourceFallback,
        'fallback_from_scribe_v2',
      );
    });
  });

  group('NoteQualityGateService Provider Tests', () {
    test('noteQualityGateServiceProvider is available', () {
      // Arrange
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Act & Assert - should not throw
      final service = container.read(noteQualityGateServiceProvider);
      expect(service, isNotNull);
    });
  });
}
