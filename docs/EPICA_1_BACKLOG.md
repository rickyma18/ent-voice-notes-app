# ÉPICA 1 — BACKLOG DE ENTRADA

## CanonicalFacts: Normalización Léxica Clínica

**Origen:** Cierre de ÉPICA 0  
**Fecha de creación:** 2026-01-17  
**Estado:** 🟡 PENDIENTE (Desbloqueada)

---

## 1. OBJETIVO DE ÉPICA 1

> **Implementar un sistema de términos canónicos que permita la comparación semántica entre outputs del pipeline y expected facts, sin modificar los prompts del extractor/composer.**

### 1.1 Resultado Esperado

```
ANTES (ÉPICA 0):
  Transcript: "le duele el oído derecho"
  Pipeline output: "dolor en el oído derecho"
  Expected: "Otalgia derecha"
  Match: ❌ (strings distintos)
  F1: 0%

DESPUÉS (ÉPICA 1):
  Transcript: "le duele el oído derecho"
  Pipeline output: "dolor en el oído derecho"
  Expected: "Otalgia derecha"  
  Canonical: "otalgia" ↔ "dolor de oído" ↔ "dolor en el oído"
  Match: ✅ (mismo concepto canónico)
  F1: ≥50%
```

---

## 2. PROBLEMAS HEREDADOS DE ÉPICA 0

### 2.1 Errores Léxicos (Solucionables con CanonicalFacts)

| ID | Campo | Expected | Actual | Término Canónico Propuesto |
|----|-------|----------|--------|---------------------------|
| LEX-001 | `chiefComplaint.text` | "Otalgia derecha" | "dolor en el oído derecho" | `OTALGIA` |
| LEX-002 | `ros.positives` | "otalgia" | "dolor punzante en el oído derecho" | `OTALGIA` |
| LEX-003 | `ros.negatives` | "otorrea" | "escurrimiento" | `OTORREA` |
| LEX-004 | `ros.negatives` | "fiebre" | "fiebre" | `FIEBRE` ✅ (ya coincide) |

### 2.2 Errores Estructurales (NO solucionables con CanonicalFacts — ÉPICA 2+)

| ID | Campo | Problema | Épica Objetivo |
|----|-------|----------|----------------|
| STR-001 | `ros.positives` | "empeora por las noches" no es síntoma atómico | ÉPICA 2 |
| STR-002 | `assessment.primary` | Placeholder "X a estudio" | ÉPICA 2 |
| STR-003 | `plan.followUp` | Hallucination "a determinar" | ÉPICA 2 |

### 2.3 Errores de Evidence (Requieren cambios en pipeline — ÉPICA 2+)

| ID | Campo | Problema | Épica Objetivo |
|----|-------|----------|----------------|
| EVD-001 | `chiefComplaint.evidence` | Evidence no preservado | ÉPICA 2 |
| EVD-002 | `hpi.evidence` | Evidence no preservado | ÉPICA 2 |

---

## 3. ESPECIFICACIÓN DE CANONICALFACTS

### 3.1 Estructura de Datos Propuesta

```dart
/// Representa un concepto clínico canónico
class CanonicalTerm {
  /// ID único del término canónico (ej: "OTALGIA", "OTORREA")
  final String canonicalId;
  
  /// Nombre preferido en español médico
  final String preferredTerm;
  
  /// Sinónimos y variantes léxicas aceptadas
  final List<String> synonyms;
  
  /// Categoría clínica (symptom, sign, finding, diagnosis)
  final TermCategory category;
  
  /// Sistema corporal (ENT, cardio, neuro, etc.)
  final String bodySystem;
}

enum TermCategory {
  symptom,    // Lo que el paciente refiere
  sign,       // Lo que el médico observa
  finding,    // Resultado de examen
  diagnosis,  // Impresión diagnóstica
}
```

### 3.2 Diccionario Canónico Inicial (ENT-focused)

```json
{
  "OTALGIA": {
    "preferredTerm": "Otalgia",
    "synonyms": [
      "dolor de oído",
      "dolor en el oído",
      "dolor oído",
      "duele el oído",
      "le duele el oído",
      "dolor punzante en el oído"
    ],
    "category": "symptom",
    "bodySystem": "ENT"
  },
  "OTORREA": {
    "preferredTerm": "Otorrea",
    "synonyms": [
      "escurrimiento del oído",
      "secreción del oído",
      "supuración",
      "escurrimiento",
      "sale líquido del oído"
    ],
    "category": "symptom",
    "bodySystem": "ENT"
  },
  "FIEBRE": {
    "preferredTerm": "Fiebre",
    "synonyms": [
      "calentura",
      "temperatura alta",
      "febril"
    ],
    "category": "symptom",
    "bodySystem": "systemic"
  },
  "ODINOFAGIA": {
    "preferredTerm": "Odinofagia",
    "synonyms": [
      "dolor de garganta",
      "dolor al tragar",
      "dolor al pasar",
      "duele al tragar"
    ],
    "category": "symptom",
    "bodySystem": "ENT"
  },
  "MAREO": {
    "preferredTerm": "Mareo",
    "synonyms": [
      "mareado",
      "me mareo",
      "sensación de mareo",
      "aturdido"
    ],
    "category": "symptom",
    "bodySystem": "neuro"
  },
  "VERTIGO": {
    "preferredTerm": "Vértigo",
    "synonyms": [
      "sensación rotatoria",
      "todo da vueltas",
      "gira todo"
    ],
    "category": "symptom",
    "bodySystem": "neuro"
  }
}
```

### 3.3 Integración con Comparators

```dart
/// Nuevo comparator con soporte canónico
class CanonicalFactComparator {
  final CanonicalDictionary dictionary;
  
  /// Compara usando términos canónicos
  ComparisonResult compare(dynamic expected, dynamic actual) {
    final expectedCanonical = dictionary.canonicalize(expected);
    final actualCanonical = dictionary.canonicalize(actual);
    
    if (expectedCanonical == actualCanonical) {
      return ComparisonResult.match(
        matchType: MatchType.canonical,
        expectedRaw: expected,
        actualRaw: actual,
        canonicalTerm: expectedCanonical,
      );
    }
    
    return ComparisonResult.mismatch(...);
  }
}
```

---

## 4. TAREAS ESPECÍFICAS

### 4.1 Fase A: Implementar Diccionario Canónico

| Tarea | Descripción | Criterio de Aceptación |
|-------|-------------|------------------------|
| A1 | Crear `canonical_term.dart` model | Compila sin errores |
| A2 | Crear `canonical_dictionary.dart` | Load/lookup funciona |
| A3 | Crear `data/canonical_terms.json` inicial | 20+ términos ENT |
| A4 | Unit tests para dictionary | 100% coverage |

### 4.2 Fase B: Integrar con Harness

| Tarea | Descripción | Criterio de Aceptación |
|-------|-------------|------------------------|
| B1 | Modificar `fact_comparator.dart` | Usa canonical lookup |
| B2 | Agregar flag `--canonical` al CLI | Modo togglable |
| B3 | Reportar match type en output | `"matchType": "canonical"` |
| B4 | Actualizar métricas para canonical matches | F1 mejora |

### 4.3 Fase C: Validar Mejora de Métricas

| Tarea | Descripción | Criterio de Aceptación |
|-------|-------------|------------------------|
| C1 | Correr harness con `--canonical` | Sin errores |
| C2 | Comparar F1 antes/después | F1 aumenta |
| C3 | Documentar mejoras por caso | Changelog |
| C4 | CI workflow con canonical mode | Green builds |

---

## 5. CRITERIOS DE ÉXITO DE ÉPICA 1

### 5.1 Métricas Objetivo

| Métrica | Baseline (ÉPICA 0) | Objetivo (ÉPICA 1) | Stretch |
|---------|--------------------|--------------------|---------|
| F1 chiefComplaint.text | 0% | ≥50% | ≥70% |
| F1 ros.positives | 0% | ≥30% | ≥50% |
| F1 ros.negatives | 50% | ≥60% | ≥75% |
| Canonical terms coverage | 0 | 30+ términos | 50+ |

### 5.2 Restricciones

| ❌ NO permitido en ÉPICA 1 |
|---------------------------|
| Modificar `expected_facts/*.json` |
| Cambiar prompts del extractor |
| Cambiar prompts del composer |
| Modificar `ProcessEncounterUseCase` |
| Agregar LLMs o embeddings |

---

## 6. RIESGOS Y MITIGACIONES

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Diccionario incompleto | Alta | Medio | Iterar con casos que fallan |
| Ambigüedad en sinónimos | Media | Alto | Priorizar términos específicos |
| Over-matching (false positives) | Baja | Alto | Tests de no-match explícitos |
| Complejidad de lateralidad | Media | Medio | Tratar lateralidad aparte |

---

## 7. DEPENDENCIAS

### 7.1 Dependencias Técnicas

- ✅ `scribe_eval_harness` funcional (ÉPICA 0)
- ✅ Baseline de 16 casos congelado
- ✅ Métricas F1 calculándose

### 7.2 No Dependencias

- ❌ NO requiere cambios en `docsoft_scribe_core`
- ❌ NO requiere cambios en `docsoft_scribe_runtime`
- ❌ NO requiere nuevos LLMs

---

## 8. ESTIMACIÓN

| Fase | Esfuerzo Estimado | Responsable |
|------|-------------------|-------------|
| Fase A: Diccionario | 2-3 días | Eng |
| Fase B: Integración | 2 días | Eng |
| Fase C: Validación | 1 día | QA |
| **Total** | **5-6 días** | — |

---

**Documento creado:** 2026-01-17  
**Origen:** ÉPICA 0 Completion Report  
**Próxima revisión:** Al inicio de ÉPICA 1
