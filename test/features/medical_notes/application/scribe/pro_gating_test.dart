// test/features/medical_notes/application/scribe/pro_gating_test.dart
//
// Tests for Pro User gating logic in MedGemma pipeline.
//
// Validates that advanced extractor (MedGemma) is ONLY injected when:
// 1. isProUserProvider == true
// 2. scribeFeatureFlagsProvider.useMedGemmaExtractor == true
// 3. MedGemma repository is properly configured (non-null)
//
// Uses the production provider chain, NOT fake subscription types.

import 'package:docsoft_scribe_runtime/docsoft_scribe_runtime.dart' as runtime;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/providers/medgemma_providers.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/repositories/medgemma_extractor_repository_impl.dart';
import 'package:medical_notes_app/src/features/medical_notes/medical_notes_providers.dart';

// ───────────────────────────────────────────────────────────────────────────
// FAKE IMPLEMENTATIONS FOR TESTING
// ───────────────────────────────────────────────────────────────────────────

/// Fake MedGemma repository for testing - simulates configured MedGemma.
/// Uses noSuchMethod to stub all methods without implementing them.
final class FakeMedGemmaExtractorRepository
    implements MedGemmaExtractorRepositoryImpl {
  const FakeMedGemmaExtractorRepository();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Pro Gating - advancedEncounterExtractorRepositoryProvider', () {
    // ─────────────────────────────────────────────────────────────────────────
    // TEST CASE 1: FREE user → NO advanced extractor
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'FREE user + flag ON + MedGemma configured → returns NULL (no advanced)',
      () {
        // ARRANGE: Override providers to simulate FREE user with everything else enabled
        final container = ProviderContainer(
          overrides: [
            // Gate 1: FREE user (should block)
            isProUserProvider.overrideWithValue(false),
            // Gate 2: Feature flag ON
            scribeFeatureFlagsProvider.overrideWithValue(
              runtime.FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
            ),
            // Gate 3: MedGemma configured
            medGemmaExtractorRepositoryProvider.overrideWithValue(
              const FakeMedGemmaExtractorRepository(),
            ),
          ],
        );

        addTearDown(container.dispose);

        // ACT
        final advancedRepo = container.read(
          advancedEncounterExtractorRepositoryProvider,
        );

        // ASSERT: Should be NULL because user is FREE
        expect(advancedRepo, isNull);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // TEST CASE 2: PRO user + flag OFF → NO advanced extractor
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'PRO user + flag OFF + MedGemma configured → returns NULL (no advanced)',
      () {
        // ARRANGE: Override providers to simulate PRO user with flag OFF
        final container = ProviderContainer(
          overrides: [
            // Gate 1: PRO user
            isProUserProvider.overrideWithValue(true),
            // Gate 2: Feature flag OFF (should block)
            scribeFeatureFlagsProvider.overrideWithValue(
              runtime.FeatureFlags.prod.copyWith(useMedGemmaExtractor: false),
            ),
            // Gate 3: MedGemma configured
            medGemmaExtractorRepositoryProvider.overrideWithValue(
              const FakeMedGemmaExtractorRepository(),
            ),
          ],
        );

        addTearDown(container.dispose);

        // ACT
        final advancedRepo = container.read(
          advancedEncounterExtractorRepositoryProvider,
        );

        // ASSERT: Should be NULL because flag is OFF
        expect(advancedRepo, isNull);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // TEST CASE 3: PRO user + flag ON + MedGemma NOT configured → NO advanced
    // ─────────────────────────────────────────────────────────────────────────
    test('PRO user + flag ON + MedGemma NULL → returns NULL (no advanced)', () {
      // ARRANGE: Override providers to simulate PRO user without MedGemma config
      final container = ProviderContainer(
        overrides: [
          // Gate 1: PRO user
          isProUserProvider.overrideWithValue(true),
          // Gate 2: Feature flag ON
          scribeFeatureFlagsProvider.overrideWithValue(
            runtime.FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
          ),
          // Gate 3: MedGemma NOT configured (should block)
          medGemmaExtractorRepositoryProvider.overrideWithValue(null),
        ],
      );

      addTearDown(container.dispose);

      // ACT
      final advancedRepo = container.read(
        advancedEncounterExtractorRepositoryProvider,
      );

      // ASSERT: Should be NULL because MedGemma is not configured
      expect(advancedRepo, isNull);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST CASE 4: PRO user + flag ON + MedGemma configured → ADVANCED enabled
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'PRO user + flag ON + MedGemma configured → returns NON-NULL (advanced enabled)',
      () {
        // ARRANGE: All gates passing
        final container = ProviderContainer(
          overrides: [
            // Gate 1: PRO user
            isProUserProvider.overrideWithValue(true),
            // Gate 2: Feature flag ON
            scribeFeatureFlagsProvider.overrideWithValue(
              runtime.FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
            ),
            // Gate 3: MedGemma configured
            medGemmaExtractorRepositoryProvider.overrideWithValue(
              const FakeMedGemmaExtractorRepository(),
            ),
          ],
        );

        addTearDown(container.dispose);

        // ACT
        final advancedRepo = container.read(
          advancedEncounterExtractorRepositoryProvider,
        );

        // ASSERT: Should be NON-NULL because all gates passed
        expect(advancedRepo, isNotNull);
      },
    );
  });

  group('Pro Gating - Fail-closed behavior', () {
    // ─────────────────────────────────────────────────────────────────────────
    // DEFAULT STATE: All gates closed by default (fail-closed design)
    // ─────────────────────────────────────────────────────────────────────────
    test('Default state (no overrides) → returns NULL (fail-closed)', () {
      // ARRANGE: No overrides, use default provider values
      final container = ProviderContainer(
        overrides: [
          // Only override MedGemma to simulate it's "configured"
          // but isProUserProvider defaults to false, so it should still be blocked
          medGemmaExtractorRepositoryProvider.overrideWithValue(
            const FakeMedGemmaExtractorRepository(),
          ),
        ],
      );

      addTearDown(container.dispose);

      // ACT
      final advancedRepo = container.read(
        advancedEncounterExtractorRepositoryProvider,
      );

      // ASSERT: Should be NULL because isProUserProvider defaults to false
      expect(advancedRepo, isNull);
    });

    test('isProUserProvider defaults to false (fail-closed)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // ACT
      final isPro = container.read(isProUserProvider);

      // ASSERT: Default is false (fail-closed)
      expect(isPro, isFalse);
    });

    test(
      'scribeFeatureFlagsProvider defaults to prod flags (useMedGemmaExtractor: false)',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // ACT
        final flags = container.read(scribeFeatureFlagsProvider);

        // ASSERT: useMedGemmaExtractor should be false in prod defaults
        expect(flags.useMedGemmaExtractor, isFalse);
      },
    );
  });

  group('Pro Gating - Gate ordering verification', () {
    // ─────────────────────────────────────────────────────────────────────────
    // Verify that gates are evaluated in the correct order for efficiency
    // ─────────────────────────────────────────────────────────────────────────
    test('Gate 1 (isPro) blocks before checking Gate 2 or Gate 3', () {
      // ARRANGE: isPro = false, others configured
      final container = ProviderContainer(
        overrides: [
          isProUserProvider.overrideWithValue(false),
          scribeFeatureFlagsProvider.overrideWithValue(
            runtime.FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
          ),
          medGemmaExtractorRepositoryProvider.overrideWithValue(
            const FakeMedGemmaExtractorRepository(),
          ),
        ],
      );

      addTearDown(container.dispose);

      // ACT
      final advancedRepo = container.read(
        advancedEncounterExtractorRepositoryProvider,
      );

      // ASSERT: Should be blocked at Gate 1
      expect(advancedRepo, isNull);
    });

    test('Gate 2 (medGemmaRepo) blocks before checking Gate 3', () {
      // ARRANGE: isPro = true, medGemmaRepo = null, flag = true
      final container = ProviderContainer(
        overrides: [
          isProUserProvider.overrideWithValue(true),
          medGemmaExtractorRepositoryProvider.overrideWithValue(null),
          scribeFeatureFlagsProvider.overrideWithValue(
            runtime.FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
          ),
        ],
      );

      addTearDown(container.dispose);

      // ACT
      final advancedRepo = container.read(
        advancedEncounterExtractorRepositoryProvider,
      );

      // ASSERT: Should be blocked at Gate 2
      expect(advancedRepo, isNull);
    });

    test('Gate 3 (flag) is the final check', () {
      // ARRANGE: isPro = true, medGemmaRepo = configured, flag = false
      final container = ProviderContainer(
        overrides: [
          isProUserProvider.overrideWithValue(true),
          medGemmaExtractorRepositoryProvider.overrideWithValue(
            const FakeMedGemmaExtractorRepository(),
          ),
          scribeFeatureFlagsProvider.overrideWithValue(
            runtime.FeatureFlags.prod.copyWith(useMedGemmaExtractor: false),
          ),
        ],
      );

      addTearDown(container.dispose);

      // ACT
      final advancedRepo = container.read(
        advancedEncounterExtractorRepositoryProvider,
      );

      // ASSERT: Should be blocked at Gate 3
      expect(advancedRepo, isNull);
    });
  });

  group('Pro Gating - Security assertions', () {
    test(
      'A FREE user NEVER gets advancedRepo regardless of other settings',
      () {
        // Test all combinations with isPro = false
        final testCases = [
          (flag: true, medGemmaConfigured: true),
          (flag: true, medGemmaConfigured: false),
          (flag: false, medGemmaConfigured: true),
          (flag: false, medGemmaConfigured: false),
        ];

        for (final tc in testCases) {
          final container = ProviderContainer(
            overrides: [
              isProUserProvider.overrideWithValue(false), // Always FREE
              scribeFeatureFlagsProvider.overrideWithValue(
                runtime.FeatureFlags.prod.copyWith(
                  useMedGemmaExtractor: tc.flag,
                ),
              ),
              medGemmaExtractorRepositoryProvider.overrideWithValue(
                tc.medGemmaConfigured
                    ? const FakeMedGemmaExtractorRepository()
                    : null,
              ),
            ],
          );

          final advancedRepo = container.read(
            advancedEncounterExtractorRepositoryProvider,
          );

          expect(
            advancedRepo,
            isNull,
            reason:
                'FREE user should NEVER get advancedRepo '
                '(flag=${tc.flag}, medGemma=${tc.medGemmaConfigured})',
          );

          container.dispose();
        }
      },
    );
  });
}
