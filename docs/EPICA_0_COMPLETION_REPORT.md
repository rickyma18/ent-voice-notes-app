# ÉPICA 0 — COMPLETION REPORT

## Clinical Evaluation Baseline Established

**Fecha de cierre:** 2026-01-17  
**Estado:** ✅ **COMPLETADA**  
**Responsable:** Ingeniería de Calidad Clínica - DocSoft

---

## 1. DECLARACIÓN FORMAL DE ALCANCE

### 1.1 Lo que ÉPICA 0 **NO** busca

| ❌ Fuera de Alcance | Justificación |
|---------------------|---------------|
| Mejorar precisión clínica | Eso corresponde a ÉPICA 1+ |
| Normalizar términos médicos | Requiere CanonicalFacts (ÉPICA 1) |
| Reducir hallucinations | Primero debemos medirlas consistentemente |
| Corregir prompts del extractor/composer | Los prompts son el objeto de estudio, no el sujeto |
| Ajustar expected para "hacer pasar" tests | Destruiría la integridad del baseline |
| Introducir TranslationService | Fuera de scope |
| Cambiar modelos LLM | Congelado para reproducibilidad |

### 1.2 Lo que ÉPICA 0 **SÍ** logra

> **Propósito único:** Medir y evidenciar el estado clínico real del pipeline actual, estableciendo un baseline confiable y reproducible.

**Logros concretos:**

1. **Harness determinístico** — Corre sin Flutter, usa solo Dart
2. **Pipeline real integrado** — Usa `ProcessEncounterUseCase` real
3. **Snapshots de producción** — Outputs grabados de LLM real
4. **Clasificación por severidad** — CRITICAL / MAJOR / MINOR / INFO
5. **Métricas cuantitativas** — Precision, Recall, F1, Evidence Coverage, Hallucinations
6. **Modos de ejecución** — `live` / `record` / `replay` + `--strict`
7. **16 casos clínicos** — Cobertura de lateralidad, negaciones temporales, alergias, dosificación

---

## 2. CRITERIOS DE ÉXITO — CHECKLIST DE ACEPTACIÓN

### ✅ Checklist Cumplida

| # | Criterio | Estado | Evidencia |
|---|----------|--------|-----------|
| 1 | El harness corre sin Flutter | ✅ | `dart run bin/run_eval.dart` funcional |
| 2 | Usa el pipeline real de producción | ✅ | `ProcessEncounterUseCase` via `ScribePipelineFactory` |
| 3 | Los snapshots representan producción real | ✅ | `output/snapshots/*.actual.json` con `transcriptHash` |
| 4 | Los errores se clasifican por severidad | ✅ | `errorCounts: {critical, major, minor, info}` |
| 5 | El sistema falla cuando debe fallar | ✅ | `otalgia_simple` → 10 errores MAJOR, 0% pass rate |
| 6 | Ningún expected fue ajustado para "hacer pasar" tests | ✅ | Baseline original preservado |
| 7 | Métricas de Evidence Coverage funcionan | ✅ | 0.0% detectado correctamente |
| 8 | Detector de Hallucinations operativo | ✅ | 2 hallucinations detectados |
| 9 | Coherence scoring implementado | ✅ | 75.0% reportado |
| 10 | CI-ready con `--strict` mode | ✅ | Exit codes 0/1 según thresholds |

---

## 3. CLASIFICACIÓN DE ERRORES DETECTADOS

### 3.1 Caso de Referencia: `otalgia_simple`

**Transcripción de entrada:**
```
Paciente viene porque le duele el oído derecho desde hace tres días. El dolor es punzante, 
empeora por las noches. Niega fiebre, niega escurrimiento. No tiene antecedentes de 
importancia. No toma medicamentos. No tiene alergias conocidas.
```

**Resultado del pipeline:**
- Pass Rate: 0%
- Errores: 0 CRITICAL, 10 MAJOR, 2 MINOR, 1 INFO
- Evidence Coverage: 0.0%
- Hallucinations: 2

### 3.2 Taxonomía de Errores Observados

| Categoría | Campo | Error | Clasificación |
|-----------|-------|-------|---------------|
| **Léxico/Normalizable** | `chiefComplaint.text` | `"dolor en el oído derecho"` vs expected `"Otalgia derecha"` | 🟡 Requiere CanonicalFacts |
| **Léxico/Normalizable** | `ros.negatives` | `"escurrimiento"` vs expected `"otorrea"` | 🟡 Requiere CanonicalFacts |
| **Estructural** | `ros.positives` | `"dolor punzante en el oído derecho"` (compuesto) vs `"otalgia"` (atómico) | 🟠 Requiere refactor ROS |
| **Estructural** | `ros.positives` | `"empeora por las noches"` (temporal) en ROS | 🟠 Confusión HPI vs ROS |
| **Evidence** | `chiefComplaint.evidence` | Evidence missing en output | 🔴 Pipeline no preserva quotes |
| **Evidence** | `hpi.evidence` | Narrative sin evidence trail | 🔴 Pipeline no preserva quotes |
| **Coherencia** | `chiefComplaint vs assessment` | `"dolor en el oído derecho"` → `"X a estudio"` | 🟠 Assessment genérico |
| **Hallucination** | `plan.followUp` | `"a determinar"` no mencionado | 🔴 Inventado por LLM |
| **Assessment** | `assessment.primary` | Placeholder `"X a estudio"` | 🟠 Falla de extracción diagnóstica |

### 3.3 Leyenda de Clasificación

| Símbolo | Categoría | Acción Requerida |
|---------|-----------|------------------|
| 🟡 | Léxico/Normalizable | ÉPICA 1: CanonicalFacts |
| 🟠 | Estructural/Coherencia | ÉPICA 2+: Prompt Engineering |
| 🔴 | Evidence/Hallucination | ÉPICA 1-2: Pipeline + Prompts |

---

## 4. BASELINE CLÍNICO CONGELADO

### 4.1 Archivos Baseline (Inmutables hasta cierre de épica)

Los siguientes archivos quedan **congelados** como el baseline de referencia contra el cual se medirán todas las mejoras futuras:

```
tool/scribe_eval_harness/data/
├── expected_facts/
│   ├── allergy_no_preguntada.json           ← CONGELADO
│   ├── allergy_penicilina_explicita.json    ← CONGELADO
│   ├── dosage_amoxicilina_500mg.json        ← CONGELADO
│   ├── dosage_gotas_otico.json              ← CONGELADO
│   ├── dosage_ibuprofeno_400mg.json         ← CONGELADO
│   ├── dosage_media_tableta.json            ← CONGELADO
│   ├── laterality_bilateral.json            ← CONGELADO
│   ├── laterality_otalgia_derecha.json      ← CONGELADO
│   ├── laterality_otalgia_izquierda.json    ← CONGELADO
│   ├── mareo_temporal.json                  ← CONGELADO
│   ├── meds_diario_vs_prn.json              ← CONGELADO
│   ├── negation_temporal_mareo_nocturno.json      ← CONGELADO
│   ├── negation_temporal_odinofagia_resuelta.json ← CONGELADO
│   ├── negations_only.json                  ← CONGELADO
│   ├── odinofagia_complex.json              ← CONGELADO
│   └── otalgia_simple.json                  ← CONGELADO
├── expected_soap/
│   └── README.md                            ← CONGELADO
└── thresholds.json                          ← CONGELADO
```

### 4.2 Regla de Oro para Mejoras Futuras

> ⚠️ **REGLA INVIOLABLE:** Cualquier mejora clínica futura deberá demostrar:
> 
> 1. **Reducción de errores** sin cambiar `expected_facts/*.json`
> 2. **Aumento de métricas** con el mismo baseline
> 3. **Sin ajustes a thresholds** para "hacer pasar" artificialmente

**Excepción única:** Agregar NUEVOS casos de prueba es permitido y fomentado.

### 4.3 Thresholds de Referencia (Congelados)

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

---

## 5. ESTADO ACTUAL DEL PIPELINE (SNAPSHOT 2026-01-17)

### 5.1 Métricas Agregadas

| Métrica | Valor Actual | Threshold Objetivo | Estado |
|---------|--------------|-------------------|--------|
| Pass Rate | 0% | N/A | 🔴 Esperado |
| Evidence Coverage | 0% | ≥80% | 🔴 Esperado |
| Hallucinations | 2 | 0 | 🔴 Esperado |
| Coherence Score | 75% | N/A | 🟡 Baseline |
| chiefComplaint.text F1 | 0% | ≥90% | 🔴 Esperado |
| ros.positives F1 | 0% | ≥75% | 🔴 Esperado |
| ros.negatives F1 | 50% | ≥75% | 🔴 Esperado |
| assessment.primary F1 | 0% | ≥80% | 🔴 Esperado |

### 5.2 ¿Por qué estos fallos son DESEABLES?

| Observación | Por qué es correcta |
|-------------|---------------------|
| F1 bajo en chiefComplaint | Sin normalización léxica, "dolor en el oído" ≠ "Otalgia" |
| Hallucinations detectados | El detector funciona correctamente |
| Evidence coverage 0% | El pipeline actual no preserva quotes — correcto detectarlo |
| Assessment genérico "X a estudio" | Falla real del extractor — debe verse |
| ROS contaminado con HPI | Confusión estructural real — debe medirse |

> **El harness está funcionando correctamente al fallar estos tests.**

---

## 6. PROBLEMAS ABIERTOS (INPUT PARA ÉPICA 1)

### 6.1 Problemas Priorizados

| Prioridad | Problema | Épica Objetivo | Impacto Clínico |
|-----------|----------|----------------|-----------------|
| **P0** | Sin CanonicalFacts para normalización léxica | ÉPICA 1 | CRÍTICO — toda comparación falla |
| **P0** | Evidence quotes no preservados en output | ÉPICA 1 | CRÍTICO — no hay trazabilidad |
| **P1** | ROS contiene información de HPI | ÉPICA 2 | ALTO — confusión estructural |
| **P1** | Assessment genera placeholders "X a estudio" | ÉPICA 2 | ALTO — pérdida diagnóstica |
| **P2** | Hallucination en plan.followUp | ÉPICA 2 | MEDIO — invención de instrucciones |
| **P2** | Coherence CC↔Assessment débil | ÉPICA 2 | MEDIO — notas inconsistentes |

### 6.2 Dependencias Técnicas

```
ÉPICA 1 (CanonicalFacts)
├── Implementar sistema de términos canónicos
├── Mapeo bidireccional: vernáculo ↔ canónico
├── Integrar en comparators del harness
└── NO cambiar prompts aún

ÉPICA 2 (Prompt Engineering)
├── Requiere ÉPICA 1 completada
├── Refinar separación HPI vs ROS
├── Mejorar extracción de assessment
└── Eliminar hallucinations estructurales
```

---

## 7. QUÉ MIDE EL HARNESS (Y QUÉ NO)

### 7.1 ✅ El harness MIDE actualmente

| Capacidad | Implementación |
|-----------|---------------|
| Precision/Recall/F1 por campo | `fact_comparator.dart` |
| Evidence Coverage | `evidence_validator.dart` |
| Hallucination Detection | `hallucination_detector.dart` |
| Coherence CC↔Assessment | `coherence_validator.dart` |
| Laterality Consistency | `laterality_validator.dart` |
| Dosage Preservation | `dosage_preservation_validator.dart` |
| Temporal Negation | `negation_temporal_validator.dart` |
| Severity Classification | CRITICAL/MAJOR/MINOR/INFO |
| Threshold Gating | `--strict` mode |
| Snapshot Integrity | SHA-256 hash verification |

### 7.2 ❌ El harness NO MIDE todavía

| Capacidad Faltante | Épica Objetivo |
|-------------------|----------------|
| Normalización léxica automática | ÉPICA 1 |
| Semantic similarity (embeddings) | ÉPICA 3+ |
| SOAP text quality scoring | ÉPICA 2 |
| Multi-turn conversation coherence | ÉPICA 4+ |
| Real-time latency budgets | ÉPICA 5+ |

---

## 8. ARQUITECTURA VALIDADA

### 8.1 Componentes del Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    scribe_eval_harness (Dart-only)              │
├─────────────────────────────────────────────────────────────────┤
│  CLI: bin/run_eval.dart                                         │
│  Modos: --mode=live | record | replay                           │
│  Gating: --strict                                               │
├─────────────────────────────────────────────────────────────────┤
│  Validators:                                                    │
│  ├── evidence_validator.dart                                    │
│  ├── coherence_validator.dart                                   │
│  ├── hallucination_detector.dart                                │
│  ├── laterality_validator.dart                                  │
│  ├── dosage_preservation_validator.dart                         │
│  └── negation_temporal_validator.dart                           │
├─────────────────────────────────────────────────────────────────┤
│  Data:                                                          │
│  ├── input_transcripts/*.txt (16 casos)                         │
│  ├── expected_facts/*.json (16 casos)                           │
│  └── thresholds.json                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  docsoft_scribe_runtime                          │
├─────────────────────────────────────────────────────────────────┤
│  ProcessEncounterUseCase                                        │
│  OpenAI Client (real)                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  docsoft_scribe_core                             │
├─────────────────────────────────────────────────────────────────┤
│  DTOs, Prompts, Sanitizers, ROSReconciliationService            │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 Flujo de Ejecución Validado

```
1. dart run bin/run_eval.dart --mode=record --case=otalgia_simple
2. Load: data/input_transcripts/otalgia_simple.txt
3. Run: ProcessEncounterUseCase.callFromTranscript()
4. Save: output/snapshots/otalgia_simple.actual.json
5. Compare: vs data/expected_facts/otalgia_simple.json
6. Validate: evidence, coherence, hallucinations, laterality, dosage, negation
7. Report: output/report.json + output/report_summary.txt
```

---

## 9. CONCLUSIÓN FORMAL

### 9.1 Confirmación de Cierre

> ✅ **ÉPICA 0 COMPLETADA — BASELINE CLÍNICO CONGELADO**

El sistema de evaluación clínica está operativo y cumple todos los criterios de aceptación. Los fallos observados son **esperados y deseables**, demostrando que el harness detecta correctamente las deficiencias del pipeline actual.

### 9.2 Estado del Sistema

| Dimensión | Estado |
|-----------|--------|
| Harness funcional | ✅ Operativo |
| Pipeline integrado | ✅ Real, no mock |
| Snapshots reproducibles | ✅ SHA-256 verificado |
| Métricas calculadas | ✅ Precision/Recall/F1 |
| Severidades clasificadas | ✅ CRITICAL→INFO |
| CI-ready | ✅ Exit codes + --strict |
| Baseline congelado | ✅ 16 casos + thresholds |

### 9.3 Lo que Desbloquea

```
ÉPICA 0 ────────────────────────────────────────────────────────────
    │ COMPLETADA ✅
    │
    ▼
ÉPICA 1 (CanonicalFacts) ───────────────────────────────────────────
    │ DESBLOQUEADA ✅
    │ Puede iniciar inmediatamente
    │
    │ Criterio de éxito:
    │   - F1 chiefComplaint.text ≥ 50% (actualmente 0%)
    │   - F1 ros.positives ≥ 30% (actualmente 0%)
    │   - Sin cambiar expected_facts/*.json
    │
    ▼
ÉPICA 2 (Prompt Engineering) ───────────────────────────────────────
    │ BLOQUEADA hasta ÉPICA 1
    │
    ...
```

---

## 10. FIRMA DE APROBACIÓN

| Rol | Firma | Fecha |
|-----|-------|-------|
| Ingeniero de Calidad Clínica | ✅ Aprobado | 2026-01-17 |
| Arquitecto de Pipeline | Pendiente | — |
| Lead Clínico | Pendiente | — |

---

**Documento generado:** 2026-01-17T12:16:00-06:00  
**Versión:** 1.0.0  
**Hash del reporte base:** `output/report.json @ 2026-01-17T11:44:11.876001`

---

> *"El baseline clínico no miente. Sus métricas son incómodas pero honestas. Cualquier mejora futura será real, medible y verificable."*
