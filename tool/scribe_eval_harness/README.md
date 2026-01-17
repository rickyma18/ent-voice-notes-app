# Scribe V2 Clinical Evaluation Harness

> **ÉPICA 0: ✅ COMPLETADA** (2026-01-17)  
> Baseline clínico congelado. Ver [`docs/EPICA_0_COMPLETION_REPORT.md`](../../docs/EPICA_0_COMPLETION_REPORT.md)

Standalone evaluation harness for the Scribe V2 pipeline that measures accuracy,
evidence coverage, coherence, and hallucinations.

## ⚠️ Baseline Freeze Notice

The following files are **FROZEN** as of ÉPICA 0 completion:

- `data/expected_facts/*.json` — 16 test cases
- `data/thresholds.json` — Quality thresholds
- `data/expected_soap/` — SOAP expectations

**Rule:** Any pipeline improvement must demonstrate increased metrics **without** modifying these baseline files. Adding new test cases is allowed and encouraged.

## Overview

This harness runs transcripts through the Scribe V2 pipeline and compares the
extracted clinical facts against expected ground truth. It does NOT modify
production code and can be run in isolation.

## Directory Structure

```
tool/scribe_eval_harness/
├── bin/
│   └── run_eval.dart              # CLI with --mode support
├── lib/
│   ├── runner/
│   │   └── eval_runner.dart       # Main evaluation runner
│   ├── snapshot/
│   │   ├── snapshot.dart          # Barrel export
│   │   ├── snapshot_model.dart    # Snapshot data model
│   │   ├── snapshot_store.dart    # Read/write snapshots
│   │   ├── recording_pipeline_runner.dart  # Record mode wrapper
│   │   └── replay_pipeline_runner.dart     # Replay mode loader
│   ├── models/
│   │   ├── test_case.dart         # Test case definition
│   │   ├── evaluation_result.dart # Result models
│   │   └── metrics.dart           # Aggregate metrics
│   ├── comparators/
│   │   └── fact_comparator.dart   # Field-level comparison
│   ├── validators/
│   │   ├── evidence_validator.dart        # Evidence coverage
│   │   ├── coherence_validator.dart       # Internal coherence
│   │   ├── hallucination_detector.dart    # LLM hallucinations
│   │   ├── laterality_validator.dart      # Laterality consistency (OD/OI)
│   │   ├── dosage_preservation_validator.dart # Dosage/frequency preservation
│   │   └── negation_temporal_validator.dart   # Temporal negation handling
│   └── report/
│       └── report_generator.dart  # Report generation
├── data/
│   ├── input_transcripts/         # Raw transcript .txt files
│   ├── expected_facts/            # Expected clinical facts JSON
│   └── expected_soap/             # Expected SOAP notes (optional)
├── test/
│   ├── threshold_gating_test.dart     # CI gating tests
│   ├── clinical_validators_test.dart  # Clinical validator tests
│   └── snapshot_test.dart             # Record/replay mode tests
└── output/
    ├── report.json                # Evaluation report (gitignored)
    └── snapshots/                 # Recorded pipeline outputs (gitignored)
        └── <case>.actual.json     # Per-case snapshot
```

## Test Case Format

### Transcripts (`data/input_transcripts/*.txt`)

Plain text transcripts in Spanish. Example:

```
Paciente refiere dolor de oído derecho de 3 días de evolución.
Niega fiebre, niega otorrea. El dolor es punzante, exacerba de noche.
```

### Expected Facts (`data/expected_facts/*.json`)

JSON matching the `ClinicalFactsDTO` schema:

```json
{
  "chiefComplaint": {
    "text": "Otalgia derecha"
  },
  "ros": {
    "positives": ["otalgia"],
    "negatives": ["fiebre", "otorrea"]
  },
  "hpi": {
    "narrative": "Paciente refiere dolor de oído derecho de 3 días de evolución..."
  },
  "assessment": {
    "primary": "Otalgia derecha a estudio"
  },
  "plan": {
    "treatments": [],
    "diagnostics": [],
    "followUp": null
  }
}
```

## Running the Harness

The harness supports three execution modes, **all runnable with `dart run` (no Flutter required)**:

| Mode | Description | LLM Calls | Snapshots |
|------|-------------|-----------|-----------|
| **live** | Run real pipeline | Yes | Not saved |
| **record** | Run real pipeline, save outputs | Yes | Saved |
| **replay** | Load saved outputs | No | Loaded |

### Live Mode (Default)

Run the real pipeline against test cases:

```bash
# Set API key
export OPENAI_API_KEY=sk-...

# Run all test cases (Dart-only, no Flutter)
cd tool/scribe_eval_harness
dart run bin/run_eval.dart --mode=live --verbose

# Run single test case
dart run bin/run_eval.dart --mode=live --case=otalgia_simple --verbose
```

### Record Mode

Run the real pipeline and save outputs as snapshots for later replay:

```bash
# Set API key
export OPENAI_API_KEY=sk-...

# Record all test cases (Dart-only)
cd tool/scribe_eval_harness
dart run bin/run_eval.dart --mode=record --verbose

# Record single test case
dart run bin/run_eval.dart --mode=record --case=otalgia_simple --verbose

# Record to custom directory
dart run bin/run_eval.dart --mode=record --snapshots=custom_snapshots/
```

Snapshots are saved to `output/snapshots/<case>.actual.json` and include:
- Clinical facts extracted
- SOAP text generated
- Pipeline duration
- Model info (if available)
- SHA-256 hash of input transcript
- Timestamp

### Replay Mode (CI-Friendly)

Run evaluation against saved snapshots without LLM calls:

```bash
cd tool/scribe_eval_harness
dart pub get

# Replay all available snapshots
dart run bin/run_eval.dart --mode=replay --verbose

# Replay specific case
dart run bin/run_eval.dart --mode=replay --case=otalgia_simple

# Replay with strict threshold gating (for CI)
dart run bin/run_eval.dart --mode=replay --strict

# Replay with custom snapshots directory
dart run bin/run_eval.dart --mode=replay --snapshots=path/to/snapshots
```

### Snapshot Management

Snapshots are gitignored by default but can be "promoted" to version control:

```bash
# Promote specific snapshot
git add -f tool/scribe_eval_harness/output/snapshots/otalgia_simple.actual.json

# Promote all snapshots
git add -f tool/scribe_eval_harness/output/snapshots/*.actual.json
```

**Snapshot Integrity**: Replay mode verifies that the transcript hasn't changed
since recording by comparing SHA-256 hashes. If the transcript changes, you must
re-record the snapshot.

### Snapshot JSON Format

```json
{
  "caseId": "otalgia_simple",
  "facts": {
    "chiefComplaint": { "text": "Otalgia derecha" },
    "ros": { "positives": ["otalgia"], "negatives": ["fiebre"] }
  },
  "soapText": "S: Dolor de oído...\nO: ...\nA: ...\nP: ...",
  "durationMs": 1523,
  "transcriptHash": "a1b2c3d4e5f6...",
  "timestamp": "2024-01-15T10:30:00Z",
  "modelInfo": {
    "provider": "openai",
    "mode": "record"
  }
}
```

## Metrics Computed

| Metric | Description |
|--------|-------------|
| **Precision** | % of extracted items that are correct |
| **Recall** | % of expected items that were extracted |
| **F1 Score** | Harmonic mean of precision and recall |
| **Evidence Coverage** | % of claims with supporting transcript quotes |
| **Coherence Score** | % of internally consistent sections |
| **Hallucination Count** | Number of claims without transcript basis |

## Error Severity Levels

| Severity | Description | Examples |
|----------|-------------|----------|
| **CRITICAL** | Never-wrong field errors | Missing allergy, wrong medication |
| **MAJOR** | Clinically significant errors | Wrong symptom, missing negation |
| **MINOR** | Less important discrepancies | Missing HPI detail, format issues |
| **INFO** | Informational observations | Style differences, ordering |

## Report Output

The harness generates two files:

1. **`report.json`** - Complete structured data for CI/CD integration
2. **`report_summary.txt`** - Human-readable summary

Example summary:

```
═══════════════════════════════════════════════════════════
  SCRIBE V2 CLINICAL EVALUATION REPORT
═══════════════════════════════════════════════════════════

SUMMARY
  Total test cases:  4
  Passed:            3 (75.0%)
  Failed:            1
  Avg duration:      1250ms

QUALITY METRICS
  Evidence coverage: 92.0%
  Hallucinations:    0 total
  Coherence score:   97.5%

FIELD-LEVEL PRECISION/RECALL
  chiefComplaint.text       P=100%  R=100%  F1=100%
  ros.positives             P=100%  R=85%   F1=92%
  ros.negatives             P=100%  R=90%   F1=95%
  ...
```

## Integration with CI/CD

### Basic Usage

Add to your GitHub Actions workflow:

```yaml
  - name: Run Scribe V2 Evaluation
    run: |
      flutter test integration_test/scribe_eval_integration_test.dart
    env:
      OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
```

### Strict Mode with Threshold Gating

For production CI/CD, use `--strict` mode to fail the build when quality
thresholds are not met:

```bash
cd tool/scribe_eval_harness
dart pub get
dart run bin/run_eval.dart --strict --verbose
```

**Exit Codes:**
- `0` - All thresholds passed, pipeline approved
- `1` - One or more thresholds violated, pipeline blocked

### GitHub Actions with Gating

```yaml
jobs:
  scribe-quality-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Dart
        uses: dart-lang/setup-dart@v1
        
      - name: Install dependencies
        run: |
          cd tool/scribe_eval_harness
          dart pub get
          
      - name: Run Clinical Evaluation (Strict)
        run: |
          cd tool/scribe_eval_harness
          dart run bin/run_eval.dart --strict --verbose
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
```

### Threshold Configuration

Thresholds are configured in `data/thresholds.json`:

```json
{
  "minEvidenceCoverage": 0.80,
  "maxCriticalHallucinations": 0,
  "maxCriticalContradictions": 0,
  "maxTotalCriticalErrors": 0,
  "minF1ByField": {
    "chiefComplaint.text": 0.90,
    "ros.positives": 0.75,
    "ros.negatives": 0.75,
    "assessment.primary": 0.80,
    "plan.treatments": 0.70,
    "plan.diagnostics": 0.70
  }
}
```

| Threshold | Description | Range |
|-----------|-------------|-------|
| `minEvidenceCoverage` | Minimum % of claims with transcript evidence | 0.0-1.0 |
| `maxCriticalHallucinations` | Maximum hallucinations (claims without basis) | int >= 0 |
| `maxCriticalContradictions` | Maximum contradictions between facts | int >= 0 |
| `maxTotalCriticalErrors` | Maximum critical severity errors | int >= 0 |
| `minF1ByField.*` | Minimum F1 per clinical field | 0.0-1.0 |

### Custom Thresholds

Use a custom thresholds file for different environments:

```bash
# Development (relaxed)
dart run bin/run_eval.dart --strict --thresholds=thresholds_dev.json

# Production (strict)
dart run bin/run_eval.dart --strict --thresholds=thresholds_prod.json
```

### PASS/FAIL Output Example

**PASS:**
```
╔═══════════════════════════════════════════════════════════╗
║                    ✓ GATING: PASS                         ║
╚═══════════════════════════════════════════════════════════╝

All quality thresholds met. Pipeline approved for CI.
```

**FAIL:**
```
╔═══════════════════════════════════════════════════════════╗
║                    ✗ GATING: FAIL                         ║
╚═══════════════════════════════════════════════════════════╝

THRESHOLD VIOLATIONS (2):
───────────────────────────────────────────────────────────
  ✗ minEvidenceCoverage: expected >= 80.0%, got 65.0%
  ✗ maxCriticalHallucinations: expected <= 0, got 3

TOP FAILING CASES (1):
───────────────────────────────────────────────────────────

  • mareo_case_001
    Critical: 1, Major: 2
    - [CRITICAL] ros.positives: Missing expected symptom "vértigo"
```

## Adding New Test Cases

1. Create transcript file: `data/input_transcripts/case_name.txt`
2. Create expected facts: `data/expected_facts/case_name.json`
3. (Optional) Create expected SOAP: `data/expected_soap/case_name.txt`
4. Run harness to verify

## Architecture Notes

- **No production code modification** - Uses existing `ProcessEncounterUseCase`
- **Dependency injection** - `PipelineRunner` interface allows mock/real switching
- **Flutter test framework** - Enables use of Flutter-dependent code paths
- **Factory pattern** - `ScribePipelineFactory.forEval()` builds pipeline without Riverpod

## Path Resolution

The harness uses `EvalDataResolver` to automatically resolve data/output paths across
different execution contexts:

| Context | CWD | Resolution |
|---------|-----|------------|
| `dart run bin/run_eval.dart` | `tool/scribe_eval_harness/` | Detects harness root, uses relative paths |
| `flutter test integration_test/...` | Project root | Detects project root, prepends harness path |
| Android integration test | `/data/data/<app>/` | Requires `--dart-define` override |
| CI (Linux/Windows) | Project root | Auto-detection works |

### Override via `--dart-define`

For Android device tests or custom setups, override paths explicitly:

```bash
# On Android integration tests (flutter drive)
flutter drive \
  --dart-define=OPENAI_API_KEY=sk-... \
  --dart-define=EVAL_DATA_PATH=/absolute/path/to/data \
  --dart-define=EVAL_OUTPUT_PATH=/absolute/path/to/output \
  integration_test/scribe_eval_integration_test.dart
```

### Debug Path Resolution

To debug path issues, call `EvalDataResolver.debugPrint()` at the start of your test:

```dart
import 'package:scribe_eval_harness/lib/runner/eval_data_resolver.dart';

setUpAll(() {
  EvalDataResolver.debugPrint();
  // ... rest of setup
});
```

---

## "Never-Wrong" Critical Test Cases

The harness includes a suite of 12+ test cases specifically designed to catch high-risk
clinical errors that MUST NEVER occur. These cases are tagged as "never-wrong" and trigger
**CRITICAL** severity errors when violated.

### Categories

#### A) Temporal Negation (Last State Rules)

Cases where symptoms change over time and the **current state** must prevail:

| Case | Transcript Pattern | Expected Behavior |
|------|-------------------|-------------------|
| `negation_temporal_mareo_nocturno` | "Al inicio no tenía mareo, pero anoche sí me mareé" | `mareo` in ROS.positives |
| `negation_temporal_odinofagia_resuelta` | "Antes me dolía la garganta, pero ya no" | `odinofagia` in ROS.negatives |
| `mareo_temporal` | "Al inicio no tenía mareo, pero anoche sí" | `mareo` in ROS.positives |

#### B) Laterality (OD/OI/Bilateral)

Cases verifying that left/right/bilateral is preserved consistently:

| Case | Laterality | Validated Fields |
|------|-----------|-----------------|
| `laterality_otalgia_derecha` | Derecha (right) | CC, HPI, Assessment |
| `laterality_otalgia_izquierda` | Izquierda (left) | CC, HPI, Assessment |
| `laterality_bilateral` | Ambos oídos | CC, Assessment |
| `otalgia_simple` | Derecha | CC, Assessment |

#### C) Dosage and Frequency Preservation

Cases verifying exact preservation of doses, frequencies, and quantities:

| Case | Critical Elements | Must Preserve Exactly |
|------|------------------|----------------------|
| `dosage_ibuprofeno_400mg` | 400 mg cada 8 horas por 5 días | Full dosing regimen |
| `dosage_amoxicilina_500mg` | 500 mg cada 12 horas por 7 días | Full dosing regimen |
| `dosage_media_tableta` | "media tableta" | Text as-is, NOT converted to mg |
| `dosage_gotas_otico` | 3 gotas cada 8 horas | Gota count and frequency |

#### D) Allergies (Explicit vs Not Interrogated)

Cases ensuring allergies are correctly captured or flagged as missing:

| Case | Scenario | Expected |
|------|----------|----------|
| `allergy_penicilina_explicita` | Patient states allergy | `allergies: [{item: "Penicilina", details: "..."}]` |
| `allergy_no_preguntada` | No allergy mention | `missingInfo: ["Alergias no interrogadas"]` |
| `odinofagia_complex` | Allergy with reaction | Allergy with reaction details |

#### E) Medications: Daily vs PRN

Cases distinguishing regular medications from occasional use:

| Case | Scenario | Expected |
|------|----------|----------|
| `meds_diario_vs_prn` | "Losartán diario" + "paracetamol a veces" | Losartán → medications, paracetamol → HPI.keyPoints only |

---

## Clinical Validators

### LateralityValidator

Validates consistency of laterality (derecha/izquierda/bilateral/OD/OI) across:
- `chiefComplaint.text`
- `hpi.narrative`
- `assessment.primary`

**Error Severities:**
- **CRITICAL**: Laterality flip (e.g., transcript says "derecha", output says "izquierda")
- **MAJOR**: Laterality missing when transcript specifies it

### DosagePreservationValidator

Ensures dosages and frequencies mentioned in transcript are preserved exactly:
- Numbers with units (mg, ml, gotas)
- Frequency patterns (cada X horas)
- Duration (por X días)
- Fractional doses (media tableta) NOT converted to mg

**Error Severities:**
- **CRITICAL**: Invented dosage not in transcript
- **CRITICAL**: Fractional dose converted to specific mg
- **MAJOR**: Dosage from transcript not preserved in output

### NegationTemporalValidator

Detects temporal transitions and validates ROS placement:
- "Al inicio no X, pero ahora sí" → X in positives
- "Antes sí X, pero ya no" → X in negatives
- Current state ALWAYS takes precedence over historical

**Error Severities:**
- **CRITICAL**: Polarity inversion (current symptom in wrong ROS list)
- **MAJOR**: Missing symptom that should be present based on temporal pattern

---

## Running Validator Tests

```bash
cd tool/scribe_eval_harness
dart pub get
dart test test/clinical_validators_test.dart
```

---

## Expected Facts Schema Rules

When creating expected_facts JSON:

1. **evidence** is mandatory for `chiefComplaint` and `plan.treatments`
2. **plan** is empty if doctor gave no instructions
3. **assessment.primary** uses "a estudio" when no specific diagnosis stated
4. **ROS.negatives** contain symptom only (no "niega/sin/no" prefix)
5. **allergies** must include reaction details when mentioned
6. **medications** only includes regular/daily meds, not PRN/occasional
7. **missingInfo** documents what was NOT asked (allergies, medications, etc.)
