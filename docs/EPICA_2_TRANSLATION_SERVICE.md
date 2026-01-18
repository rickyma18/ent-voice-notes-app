# ÉPICA 2: TranslationService Clínico Controlado — Implementation Summary

**Date:** 2026-01-17  
**Status:** ✅ IMPLEMENTED

## Objective

Implement a clinical translation service (ES↔EN) that:
- Preserves negations, dosages, frequencies, laterality, and temporal markers
- Is safe for feeding MedGemma in English
- FAILS explicitly if clinical drift is detected
- Provides automatic fallback to ES pipeline

## Architectural Principles

### 1. NEVER Translate ClinicalFacts JSON

The TranslationService only translates **free clinical text**:
- Transcripts
- HPI narratives
- ROS symptom descriptions
- Plan text

ClinicalFacts JSON is used as a safety net for validation, not as translation input.

### 2. Deterministic Validation Only

Round-trip guard uses **deterministic checks only**:
- ✓ Placeholders intact
- ✓ Numbers/units intact  
- ✓ Laterality preserved (left/right)
- ✓ Negation count preserved

**NO semantic similarity** - only exact validation.

### 3. Context-Dependent Disambiguation

OD/OI are ambiguous without ClinicalContext:
- **No context**: Preserved as literal tokens `OD`, `OI`
- **ENT context**: OD → "right ear", OI → "left ear"
- **OPHTH context**: OD → "right eye", OI → "left eye"

## Files Created

### Domain (packages/docsoft_scribe_core/lib/src/translation/)

| File | Description |
|------|-------------|
| `translation_service.dart` | Interface with single `translateClinicalText()` method |
| `translation_models.dart` | TranslationResult, ClinicalContext, TranslationOptions, ProtectedToken |
| `translation_errors.dart` | TranslationDriftException, DriftType enum, AlteredToken |
| `translation.dart` | Barrel export |

### Runtime (packages/docsoft_scribe_runtime/lib/src/translation/)

| File | Description |
|------|-------------|
| `translation_service_impl.dart` | Main implementation with preprocess→API→postprocess flow |
| `translation_api_client.dart` | Mockeable API client abstraction |
| `clinical_translation_preprocessor.dart` | Placeholder protection for clinical markers |
| `clinical_translation_postprocessor.dart` | Placeholder restoration and drift validation |
| `translation_cache.dart` | Hash-based cache for verified translations |
| `translation.dart` | Barrel export |

### Tests

| File | Description |
|------|-------------|
| `test/translation_test.dart` | 17 unit tests covering all components |

## Protected Token Categories

```dart
enum TokenCategory {
  negation,              // niega, sin, no presenta → denies, without
  laterality,            // derecho, izquierdo → right, left
  dosage,                // 500 mg, 3 gotas → 500 mg, 3 drops
  frequency,             // c/8h, diario → q8h, daily
  temporal,              // hace 3 días, por 7 días → 3 days ago, for 7 days
  ambiguousAbbreviation, // OD, OI (context-dependent)
}
```

## Placeholder Format

```
[[CLN_0001]]
[[CLN_0002]]
...
```

Designed to:
- Pass through translation APIs unchanged
- Be easily detectable for validation
- Not conflict with clinical content

## Translation Flow

```
Input: "Paciente niega fiebre. Otalgia derecha desde hace 3 días."
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ PREPROCESS: Protect clinical markers                            │
│                                                                 │
│ → "Paciente [[CLN_0001]] fiebre. Otalgia [[CLN_0002]]          │
│    [[CLN_0003]]."                                               │
│                                                                 │
│ Tokens: niega→denies, derecha→right, desde hace 3 días→...     │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ TRANSLATE: API call with placeholders                           │
│                                                                 │
│ → "Patient [[CLN_0001]] fever. [[CLN_0002]] ear pain           │
│    [[CLN_0003]]."                                               │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│ POSTPROCESS: Restore and validate                               │
│                                                                 │
│ → "Patient denies fever. right ear pain for 3 days."           │
│                                                                 │
│ ✓ All placeholders restored                                    │
│ ✓ No drift detected                                            │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                          TranslationResult (VERIFIED)
```

## Drift Detection

If a placeholder is lost or altered, the system:

1. **With strictValidation=true (default)**: Throws `TranslationDriftException`
2. **With strictValidation=false**: Returns result with `quality=failed`

Drift types detected:
- `DriftType.negationLost` - Negation verb missing
- `DriftType.lateralityDrift` - Left/right changed or missing
- `DriftType.dosageDrift` - Numeric value or unit altered
- `DriftType.frequencyDrift` - Frequency specification altered
- `DriftType.temporalDrift` - Temporal marker lost
- `DriftType.missingPlaceholder` - Placeholder not found in output

## Usage Example

```dart
final service = TranslationServiceImpl(
  apiClient: MockTranslationApiClient(), // or real API client
);

try {
  final result = await service.translateClinicalText(
    text: 'Paciente niega fiebre. Otalgia derecha desde hace 3 días.',
    direction: TranslationDirection.estoEN,
    context: ClinicalContext.ent,
    options: TranslationOptions.strict,
  );

  if (result.isSafeForClinicalUse) {
    // Use result.translatedText for MedGemma
  }
} on TranslationDriftException catch (e) {
  // Fallback to Spanish pipeline
  print('Drift detected: ${e.driftType}');
}
```

## Test Coverage

All 17 tests pass:

```
✓ protects negation verbs
✓ protects laterality  
✓ protects dosages with units
✓ protects frequency markers
✓ protects temporal markers
✓ handles OD/OI with ENT context
✓ handles OD/OI without context - preserves literal
✓ complex clinical phrase
✓ restores all placeholders for ES→EN
✓ throws on missing placeholder with strict validation
✓ returns failed quality without strict validation
✓ full translation flow with mock API
✓ cache hit on repeated translation
✓ validates numbers are preserved
✓ fails on number mismatch
✓ fails on laterality swap
✓ fails on negation count mismatch
```

## Next Steps (ÉPICA 3+)

1. **Integrate with pipeline**: Add TranslationService to ProcessEncounterUseCase
2. **Implement real API client**: Connect to Google Translate / DeepL / OpenAI
3. **Add fallback logic**: Automatic ES pipeline fallback on drift
4. **MedGemma integration**: Use translated text for clinical analysis
