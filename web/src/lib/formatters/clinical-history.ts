// web/src/lib/formatters/clinical-history.ts

/**
 * Parsing and formatting utilities for clinical history notes.
 *
 * These helpers are display-only and never modify Firestore data.
 * They detect structured headings in text fields and split them
 * for formatted rendering.
 */

// ============================================================
// CONSTANTS - Heading definitions for structured text parsing
// ============================================================

/**
 * Headings expected in the antecedentes field when structured
 * by the mobile wizard or AI.
 */
export const ANTECEDENTES_HEADINGS = [
  'HEREDOFAMILIARES:',
  'NO PATOLOGICOS:',
  'PATOLOGICOS:',
  'PADECIMIENTO ACTUAL:',
] as const;

/**
 * Headings expected in the exploracionFisicaOrl field when structured.
 */
export const EXPLORACION_ORL_HEADINGS = [
  'OTOSCOPIA:',
  'RINOSCOPIA:',
  'OROFARINGE:',
  'CUELLO:',
  'LARINGOSCOPIA:',
] as const;

/**
 * Display-friendly names for antecedentes sections.
 */
export const ANTECEDENTES_LABELS: Record<string, string> = {
  'HEREDOFAMILIARES:': 'Heredofamiliares',
  'NO PATOLOGICOS:': 'No Patológicos',
  'PATOLOGICOS:': 'Patológicos',
  'PADECIMIENTO ACTUAL:': 'Padecimiento Actual',
};

/**
 * Display-friendly names for ORL exploration sections.
 */
export const EXPLORACION_ORL_LABELS: Record<string, string> = {
  'OTOSCOPIA:': 'Otoscopía',
  'RINOSCOPIA:': 'Rinoscopía',
  'OROFARINGE:': 'Orofaringe',
  'CUELLO:': 'Cuello',
  'LARINGOSCOPIA:': 'Laringoscopía',
};

// ============================================================
// PARSING FUNCTIONS
// ============================================================

/**
 * Result of parsing sectioned text.
 * If the text contains recognized headings, returns a record of heading -> content.
 * If no headings are found, returns null (caller should render as single block).
 */
export type ParsedSections = Record<string, string> | null;

/**
 * Parses text that may contain section headings.
 *
 * This is NON-DESTRUCTIVE - it only reads and parses for display.
 * The original text is never modified.
 *
 * @param text - The raw text to parse (e.g., antecedentes field value)
 * @param headings - Array of heading strings to look for (e.g., ANTECEDENTES_HEADINGS)
 * @returns Record mapping heading -> content, or null if no structured format detected
 *
 * @example
 * ```ts
 * const text = "HEREDOFAMILIARES:\nMadre diabética\n\nNO PATOLOGICOS:\nNiega";
 * const result = parseSectionedText(text, ANTECEDENTES_HEADINGS);
 * // Returns: { "HEREDOFAMILIARES:": "Madre diabética", "NO PATOLOGICOS:": "Niega", ... }
 * ```
 */
export function parseSectionedText(
  text: string | undefined | null,
  headings: readonly string[]
): ParsedSections {
  if (!text || typeof text !== 'string' || text.trim() === '') {
    return null;
  }

  // First, check if ANY of the headings are present
  const hasStructuredFormat = headings.some((heading) =>
    text.toUpperCase().includes(heading)
  );

  if (!hasStructuredFormat) {
    // No structured format detected - return null so caller renders as single block
    return null;
  }

  // Build a regex pattern that matches any of the headings
  // Case-insensitive to handle variations
  const escapedHeadings = headings.map((h) =>
    h.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  );
  const pattern = new RegExp(`(${escapedHeadings.join('|')})`, 'gi');

  // Split by headings while keeping the delimiters
  const parts = text.split(pattern);

  const sections: Record<string, string> = {};
  let currentHeading: string | null = null;

  for (const part of parts) {
    const trimmed = part.trim();
    if (!trimmed) continue;

    // Check if this part is a heading (case-insensitive match)
    const matchedHeading = headings.find(
      (h) => h.toUpperCase() === trimmed.toUpperCase()
    );

    if (matchedHeading) {
      currentHeading = matchedHeading;
      // Initialize with empty string if not already set
      if (!sections[matchedHeading]) {
        sections[matchedHeading] = '';
      }
    } else if (currentHeading) {
      // This is content for the current heading
      const existingContent = sections[currentHeading] || '';
      sections[currentHeading] = existingContent
        ? `${existingContent}\n${trimmed}`
        : trimmed;
    }
    // If no current heading and not a heading itself, ignore (legacy text before first heading)
  }

  // Ensure all expected headings exist in result (with empty string if missing)
  for (const heading of headings) {
    if (!(heading in sections)) {
      sections[heading] = '';
    }
  }

  return sections;
}

/**
 * Parses the antecedentes field specifically.
 * Convenience wrapper around parseSectionedText.
 */
export function parseAntecedentes(text: string | undefined | null): ParsedSections {
  return parseSectionedText(text, ANTECEDENTES_HEADINGS);
}

/**
 * Parses the exploracionFisicaOrl field specifically.
 * Convenience wrapper around parseSectionedText.
 */
export function parseExploracionOrl(text: string | undefined | null): ParsedSections {
  return parseSectionedText(text, EXPLORACION_ORL_HEADINGS);
}

// ============================================================
// DATE FORMATTING
// ============================================================

/**
 * Safely formats a date value for display.
 * Handles Date objects, ISO strings, Firestore Timestamps, and null/undefined.
 *
 * @param value - Date, string, Timestamp-like object, or null/undefined
 * @param options - Intl.DateTimeFormatOptions for customization
 * @returns Formatted date string, or empty string if invalid
 */
export function formatDateTimeSafe(
  value: Date | string | { toDate?: () => Date } | null | undefined,
  options?: Intl.DateTimeFormatOptions
): string {
  if (!value) return '';

  try {
    let date: Date;

    if (value instanceof Date) {
      date = value;
    } else if (typeof value === 'string') {
      date = new Date(value);
    } else if (typeof value === 'object' && 'toDate' in value && typeof value.toDate === 'function') {
      // Firestore Timestamp
      date = value.toDate();
    } else {
      return '';
    }

    // Check for invalid date
    if (isNaN(date.getTime())) {
      return '';
    }

    const defaultOptions: Intl.DateTimeFormatOptions = {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    };

    return new Intl.DateTimeFormat('es', options || defaultOptions).format(date);
  } catch {
    return '';
  }
}

/**
 * Formats a date for display in headers (date only, no time).
 */
export function formatDateOnly(
  value: Date | string | { toDate?: () => Date } | null | undefined
): string {
  return formatDateTimeSafe(value, {
    day: '2-digit',
    month: 'long',
    year: 'numeric',
  });
}

// ============================================================
// TEMPLATE GENERATORS
// ============================================================

/**
 * Generates a blank clinical history template for the antecedentes field.
 * Used by the "Insertar plantilla" helper in edit mode.
 */
export function generateAntecedentesTemplate(): string {
  return `HEREDOFAMILIARES:

NO PATOLOGICOS:

PATOLOGICOS:

PADECIMIENTO ACTUAL:
`;
}

/**
 * Generates a blank ORL exploration template.
 */
export function generateExploracionOrlTemplate(): string {
  return `OTOSCOPIA:

RINOSCOPIA:

OROFARINGE:

CUELLO:

LARINGOSCOPIA:
`;
}

// ============================================================
// DISPLAY HELPERS
// ============================================================

/**
 * Gets the display label for a note type.
 */
export function getNoteTypeLabel(type: string): string {
  switch (type) {
    case 'clinical_history':
      return 'Historia Clínica';
    case 'surgical_note':
      return 'Nota Quirúrgica';
    default:
      return type;
  }
}

/**
 * Gets Tailwind classes for note type badge.
 */
export function getNoteTypeBadgeClasses(type: string): string {
  switch (type) {
    case 'clinical_history':
      return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200';
    case 'surgical_note':
      return 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200';
    default:
      return 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200';
  }
}

/**
 * Checks if a text field has meaningful content (not just whitespace).
 */
export function hasContent(text: string | undefined | null): boolean {
  return !!text && text.trim().length > 0;
}

/**
 * Gets display text for empty sections.
 */
export function getEmptyText(): string {
  return 'Sin datos relevantes.';
}
