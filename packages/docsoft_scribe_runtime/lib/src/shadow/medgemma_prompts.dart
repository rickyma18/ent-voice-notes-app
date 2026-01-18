// packages/docsoft_scribe_runtime/lib/src/shadow/medgemma_prompts.dart
//
// ÉPICA 3: Versioned prompts for MedGemma extraction.

/// Versioned prompts for MedGemma clinical extraction.
class MedGemmaPrompts {
  MedGemmaPrompts._();

  /// Current prompt version.
  static const version = 'V1';

  /// System prompt for clinical extraction.
  static const systemPrompt = '''
You are a clinical note extraction assistant. Your task is to extract structured clinical facts from a medical encounter transcript.

CRITICAL RULES:
1. Output ONLY valid JSON. No explanations, no markdown, no text before or after.
2. Extract only what is explicitly stated. Do NOT infer or assume.
3. Preserve exact laterality (left/right/bilateral).
4. Preserve exact negations (patient "denies" means negative finding).
5. Preserve exact dosages and frequencies.
6. If a field is not mentioned, use null or empty array.
''';

  /// Build extraction prompt from English transcript.
  static String buildExtractionPrompt(String englishTranscript) {
    return '''
Extract clinical facts from this medical encounter transcript.

TRANSCRIPT:
$englishTranscript

OUTPUT SCHEMA (respond with ONLY this JSON, no other text):
{
  "chiefComplaint": {
    "text": "<main reason for visit>",
    "evidence": {"quote": "<exact quote from transcript>", "speaker": "<Patient|Doctor>"}
  },
  "hpi": {
    "narrative": "<history of present illness summary>",
    "keyPoints": ["<list of key clinical points>"]
  },
  "ros": {
    "positives": ["<symptoms patient confirms>"],
    "negatives": ["<symptoms patient denies>"]
  },
  "assessment": {
    "primary": "<primary diagnosis or impression>"
  },
  "plan": {
    "treatments": ["<medications or therapies>"],
    "diagnostics": ["<tests or studies ordered>"]
  },
  "allergies": [{"item": "<allergy>", "details": "<reaction if mentioned>"}],
  "medications": [{"item": "<current medication>", "details": "<dosage if mentioned>"}]
}

JSON OUTPUT:''';
  }

  /// Prompt that forces JSON-only output.
  static const jsonOnlyReminder = '''
IMPORTANT: Your response must be ONLY the JSON object. 
Do not include any explanations, markdown formatting, or text outside the JSON.
Start your response with { and end with }
''';
}
