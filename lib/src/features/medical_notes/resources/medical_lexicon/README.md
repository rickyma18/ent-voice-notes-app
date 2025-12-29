# Spanish Medical Lexicon for Speech-to-Text

Phase 1 implementation for improving Spanish medical speech-to-text accuracy in Docsoft.

## Files

| File | Description | Count |
|------|-------------|-------|
| `meds_cima_principios_activos.json` | Active pharmaceutical substances (Spain) | 412 |
| `clinical_terms_es.json` | Diagnoses, symptoms, procedures | 687 |
| `abbreviations_es.json` | Medical abbreviations with spoken forms | 156 |
| `common_fixes_es.json` | STT error corrections | 148 |
| `medical_prompt.txt` | Whisper initial_prompt (1,147 chars) | - |

## Usage

### 1. Whisper Prompt Injection

```python
# Load prompt
with open('medical_lexicon/medical_prompt.txt', 'r', encoding='utf-8') as f:
    MEDICAL_PROMPT = f.read()

# Use with Whisper
result = whisper.transcribe(
    audio_file,
    language="es",
    initial_prompt=MEDICAL_PROMPT
)
```

### 2. Post-Processing Corrections

```python
import json

# Load corrections
with open('medical_lexicon/common_fixes_es.json', 'r', encoding='utf-8') as f:
    fixes_data = json.load(f)

# Flatten all fix categories
all_fixes = {}
for category in fixes_data['fixes'].values():
    all_fixes.update(category)

def apply_fixes(transcript: str) -> str:
    result = transcript.lower()
    for wrong, correct in all_fixes.items():
        result = result.replace(wrong.lower(), correct)
    return result
```

### 3. Dart/Flutter Integration

```dart
// Load lexicon as asset
final String lexiconJson = await rootBundle.loadString(
  'lib/src/features/medical_notes/resources/medical_lexicon/common_fixes_es.json'
);
final Map<String, dynamic> lexicon = jsonDecode(lexiconJson);
```

## Updating the Lexicon

### Refresh Medications from CIMA API

```bash
cd scripts/
python fetch_cima_medications.py
```

This fetches current data from AEMPS CIMA REST API (Spain's official medicines database).

### Add User Corrections

When users correct transcription errors:

1. Log the correction: `{ "original": "...", "corrected": "..." }`
2. Review high-frequency corrections weekly
3. Add confirmed patterns to `common_fixes_es.json`

Example:
```json
{
  "fixes": {
    "medications": {
      "nuevo_error": "término_correcto"
    }
  }
}
```

### Upgrade to SNOMED CT (Future)

When SNOMED CT Spanish Edition license is obtained:

1. Register at https://mlds.ihtsdotools.org/
2. Download Spanish Edition release
3. Run parser:

```bash
python scripts/parse_snomed_es.py /path/to/SnomedCT_SpanishRelease-es_YYYYMMDD
```

This will replace `clinical_terms_es.json` with SNOMED-sourced terms.

## Data Sources

| Data | Source | License |
|------|--------|---------|
| Medications | AEMPS CIMA REST API | Public (Spain Gov) |
| Clinical terms | CIE-10-ES / Curated | Public / Internal |
| Abbreviations | Clinical practice | Curated |
| Corrections | STT error patterns | Internal |

## File Format

All JSON files follow this structure:

```json
{
  "source": "Description of data source",
  "generated": "YYYY-MM-DD",
  "total_count": 123,
  "items": [...]
}
```

## Limitations

- Medications list focuses on Spain market (AEMPS)
- Clinical terms are fallback until SNOMED license obtained
- Corrections are based on common patterns, not exhaustive
- Regional Spanish variations may need additions

## Maintenance

- **Monthly**: Review user correction logs, add to `common_fixes_es.json`
- **Quarterly**: Re-run CIMA fetch to capture new medications
- **As needed**: Add specialty-specific terms (e.g., ORL terminology)
