/// Utilities for extracting JSON from raw LLM responses.
///
/// LLMs sometimes return JSON wrapped in markdown code blocks or with
/// extra text before/after. These utilities help extract the actual JSON.
class JsonExtractor {
  const JsonExtractor();

  /// Extracts the first valid JSON object from a raw string.
  ///
  /// Searches for the first '{' and the matching '}' using brace counting.
  /// Returns null if no valid JSON object structure is found.
  ///
  /// This does NOT validate that the JSON is syntactically correct,
  /// only that it has balanced braces. Use `dart:convert` jsonDecode
  /// for actual parsing.
  ///
  /// Example:
  /// ```dart
  /// final raw = 'Here is the result: {"key": "value"} Hope this helps!';
  /// final json = JsonExtractor().extractFirstJsonObject(raw);
  /// // json == '{"key": "value"}'
  /// ```
  String? extractFirstJsonObject(String raw) {
    if (raw.isEmpty) return null;

    // Find first opening brace
    final startIndex = raw.indexOf('{');
    if (startIndex == -1) return null;

    // Count braces to find matching closing brace
    var braceCount = 0;
    var inString = false;
    var escapeNext = false;

    for (var i = startIndex; i < raw.length; i++) {
      final char = raw[i];

      if (escapeNext) {
        escapeNext = false;
        continue;
      }

      if (char == r'\' && inString) {
        escapeNext = true;
        continue;
      }

      if (char == '"' && !escapeNext) {
        inString = !inString;
        continue;
      }

      if (!inString) {
        if (char == '{') {
          braceCount++;
        } else if (char == '}') {
          braceCount--;
          if (braceCount == 0) {
            // Found matching closing brace
            final extracted = raw.substring(startIndex, i + 1);
            // Sanity check: should start with { and end with }
            if (extracted.startsWith('{') && extracted.endsWith('}')) {
              return extracted;
            }
            return null;
          }
        }
      }
    }

    // No matching closing brace found
    return null;
  }

  /// Extracts the first valid JSON array from a raw string.
  ///
  /// Similar to [extractFirstJsonObject] but looks for '[' and ']'.
  String? extractFirstJsonArray(String raw) {
    if (raw.isEmpty) return null;

    final startIndex = raw.indexOf('[');
    if (startIndex == -1) return null;

    var bracketCount = 0;
    var inString = false;
    var escapeNext = false;

    for (var i = startIndex; i < raw.length; i++) {
      final char = raw[i];

      if (escapeNext) {
        escapeNext = false;
        continue;
      }

      if (char == r'\' && inString) {
        escapeNext = true;
        continue;
      }

      if (char == '"' && !escapeNext) {
        inString = !inString;
        continue;
      }

      if (!inString) {
        if (char == '[') {
          bracketCount++;
        } else if (char == ']') {
          bracketCount--;
          if (bracketCount == 0) {
            final extracted = raw.substring(startIndex, i + 1);
            if (extracted.startsWith('[') && extracted.endsWith(']')) {
              return extracted;
            }
            return null;
          }
        }
      }
    }

    return null;
  }

  /// Removes markdown code block wrapper if present.
  ///
  /// Handles both ```json and ``` blocks.
  String stripMarkdownCodeBlock(String raw) {
    var result = raw.trim();

    // Check for ```json or ``` at start
    if (result.startsWith('```json')) {
      result = result.substring(7);
    } else if (result.startsWith('```')) {
      result = result.substring(3);
    }

    // Check for ``` at end
    if (result.endsWith('```')) {
      result = result.substring(0, result.length - 3);
    }

    return result.trim();
  }

  /// Attempts to extract JSON, first stripping markdown if present.
  ///
  /// This is the recommended entry point for processing LLM responses.
  String? extractJson(String raw) {
    final stripped = stripMarkdownCodeBlock(raw);

    // Try object first (most common for clinical facts)
    final obj = extractFirstJsonObject(stripped);
    if (obj != null) return obj;

    // Try array as fallback
    return extractFirstJsonArray(stripped);
  }
}
