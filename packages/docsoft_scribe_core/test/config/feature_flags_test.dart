// packages/docsoft_scribe_core/test/config/feature_flags_test.dart
//
// Tests for FeatureFlags.

import 'package:test/test.dart';
import 'package:docsoft_scribe_core/src/config/feature_flags.dart';

void main() {
  group('FeatureFlags', () {
    test('default constructor has useMedGemmaExtractor = false', () {
      const flags = FeatureFlags();

      expect(flags.useMedGemmaExtractor, isFalse);
    });

    test('prod has useMedGemmaExtractor = false', () {
      expect(FeatureFlags.prod.useMedGemmaExtractor, isFalse);
      expect(FeatureFlags.prod.enableShadowMode, isFalse);
    });

    test('staging has shadow mode enabled but not MedGemma', () {
      expect(FeatureFlags.staging.useMedGemmaExtractor, isFalse);
      expect(FeatureFlags.staging.enableShadowMode, isTrue);
    });

    test('dev has shadow mode enabled but not MedGemma by default', () {
      expect(FeatureFlags.dev.useMedGemmaExtractor, isFalse);
      expect(FeatureFlags.dev.enableShadowMode, isTrue);
    });

    test('forEnvironment returns correct config', () {
      final prod = FeatureFlags.forEnvironment(ScribeEnvironment.prod);
      final staging = FeatureFlags.forEnvironment(ScribeEnvironment.staging);
      final dev = FeatureFlags.forEnvironment(ScribeEnvironment.dev);

      expect(prod.enableShadowMode, isFalse);
      expect(staging.enableShadowMode, isTrue);
      expect(dev.enableShadowMode, isTrue);
    });

    test('copyWith allows overriding single flag', () {
      const base = FeatureFlags.prod;

      final withMedGemma = base.copyWith(useMedGemmaExtractor: true);

      expect(withMedGemma.useMedGemmaExtractor, isTrue);
      expect(withMedGemma.enableShadowMode, isFalse); // Unchanged
    });

    test('copyWith allows overriding multiple flags', () {
      const base = FeatureFlags();

      final custom = base.copyWith(
        useMedGemmaExtractor: true,
        enableShadowMode: true,
      );

      expect(custom.useMedGemmaExtractor, isTrue);
      expect(custom.enableShadowMode, isTrue);
    });

    test('all environments have validation enabled by default', () {
      expect(FeatureFlags.prod.enablePreComposerValidation, isTrue);
      expect(FeatureFlags.staging.enablePreComposerValidation, isTrue);
      expect(FeatureFlags.dev.enablePreComposerValidation, isTrue);
    });
  });
}
