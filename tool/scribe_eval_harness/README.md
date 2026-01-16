# Scribe V2 Clinical Evaluation Harness

Standalone evaluation harness for the Scribe V2 pipeline that measures accuracy,
evidence coverage, coherence, and hallucinations.

## Overview

This harness runs transcripts through the Scribe V2 pipeline and compares the
extracted clinical facts against expected ground truth. It does NOT modify
production code and can be run in isolation.

## Directory Structure

```
tool/scribe_eval_harness/
├── bin/
│   └── run_eval.dart              # CLI (mock data only)
├── lib/
│   ├── runner/
│   │   └── eval_runner.dart       # Main evaluation runner
│   ├── models/
│   │   ├── test_case.dart         # Test case definition
│   │   ├── evaluation_result.dart # Result models
│   │   └── metrics.dart           # Aggregate metrics
│   ├── comparators/
│   │   └── fact_comparator.dart   # Field-level comparison
│   ├── validators/
│   │   ├── evidence_validator.dart    # Evidence coverage
│   │   ├── coherence_validator.dart   # Internal coherence
│   │   └── hallucination_detector.dart # LLM hallucinations
│   └── report/
│       └── report_generator.dart  # Report generation
├── data/
│   ├── input_transcripts/         # Raw transcript .txt files
│   ├── expected_facts/            # Expected clinical facts JSON
│   └── expected_soap/             # Expected SOAP notes (optional)
└── output/                        # Generated reports (gitignored)
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

### With Real Pipeline (Recommended)

Run the integration test which connects to the actual Scribe V2 pipeline:

```bash
# Set API key
export OPENAI_API_KEY=sk-...

# Run all test cases
flutter test integration_test/scribe_eval_integration_test.dart

# Run with verbose output
flutter test --reporter expanded integration_test/scribe_eval_integration_test.dart
```

### With Mock Data (CLI, no LLM)

For local testing without API calls:

```bash
cd tool/scribe_eval_harness
dart pub get
dart run bin/run_eval.dart --verbose
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

Add to your GitHub Actions workflow:

```yaml
  - name: Run Scribe V2 Evaluation
    run: |
      flutter test integration_test/scribe_eval_integration_test.dart
    env:
      OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
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
