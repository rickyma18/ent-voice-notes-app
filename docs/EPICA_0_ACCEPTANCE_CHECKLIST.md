# ÉPICA 0 — CHECKLIST DE ACEPTACIÓN

## Documento de Auditoría Clínica

**Fecha de verificación:** 2026-01-17  
**Verificado por:** Ingeniería de Calidad Clínica  
**Resultado:** ✅ APROBADA

---

## CRITERIOS DE ACEPTACIÓN

### 1. Infraestructura del Harness

| # | Criterio | Verificación | Estado |
|---|----------|--------------|--------|
| 1.1 | El harness se ejecuta sin Flutter | `dart run bin/run_eval.dart` completa | ✅ |
| 1.2 | No requiere dependencias de UI | Solo packages Dart-pure | ✅ |
| 1.3 | CLI funcional con modos | `--mode=live\|record\|replay` | ✅ |
| 1.4 | Modo strict para CI | `--strict` retorna exit code 1 en fallo | ✅ |
| 1.5 | Verbose output disponible | `--verbose` muestra detalles | ✅ |

### 2. Integración con Pipeline Real

| # | Criterio | Verificación | Estado |
|---|----------|--------------|--------|
| 2.1 | Usa ProcessEncounterUseCase | Via ScribePipelineFactory | ✅ |
| 2.2 | Conecta a OpenAI real en live/record | API calls observados | ✅ |
| 2.3 | No usa mocks en modo live | Pipeline real completo | ✅ |
| 2.4 | Soporta replay sin LLM | Snapshots cargan correctamente | ✅ |

### 3. Sistema de Snapshots

| # | Criterio | Verificación | Estado |
|---|----------|--------------|--------|
| 3.1 | Record mode guarda snapshots | `output/snapshots/*.actual.json` creados | ✅ |
| 3.2 | Snapshots incluyen hash del transcript | SHA-256 verificable | ✅ |
| 3.3 | Replay detecta transcript modificado | Hash mismatch reportado | ✅ |
| 3.4 | Snapshots incluyen timestamp | ISO8601 en JSON | ✅ |
| 3.5 | Snapshots incluyen model info | Provider y modo | ✅ |

### 4. Métricas Clínicas

| # | Criterio | Verificación | Estado |
|---|----------|--------------|--------|
| 4.1 | Precision calculada por campo | En report.json | ✅ |
| 4.2 | Recall calculada por campo | En report.json | ✅ |
| 4.3 | F1 calculada por campo | En report.json | ✅ |
| 4.4 | Evidence Coverage funcional | 0-100% reportado | ✅ |
| 4.5 | Hallucination Count funcional | Enteros ≥0 | ✅ |
| 4.6 | Coherence Score funcional | 0-100% reportado | ✅ |

### 5. Clasificación de Severidad

| # | Criterio | Verificación | Estado |
|---|----------|--------------|--------|
| 5.1 | Errores CRITICAL detectados | Laterality flip, allergy miss | ✅ |
| 5.2 | Errores MAJOR detectados | Value mismatch, missing item | ✅ |
| 5.3 | Errores MINOR detectados | Format issues, ordering | ✅ |
| 5.4 | Errores INFO detectados | Style differences | ✅ |
| 5.5 | Conteo por severidad en reporte | errorsBySeverity en JSON | ✅ |

### 6. Validadores Clínicos

| # | Criterio | Verificación | Estado |
|---|----------|--------------|--------|
| 6.1 | EvidenceValidator operativo | Detecta missing evidence | ✅ |
| 6.2 | CoherenceValidator operativo | CC↔Assessment coherence | ✅ |
| 6.3 | HallucinationDetector operativo | Claims sin basis | ✅ |
| 6.4 | LateralityValidator operativo | OD/OI consistency | ✅ |
| 6.5 | DosagePreservationValidator operativo | mg/gotas preservados | ✅ |
| 6.6 | NegationTemporalValidator operativo | Last state wins | ✅ |

### 7. Cobertura de Casos de Prueba

| # | Criterio | Verificación | Estado |
|---|----------|--------------|--------|
| 7.1 | ≥10 casos en expected_facts | 16 archivos JSON | ✅ |
| 7.2 | Casos de lateralidad | 3 (derecha, izquierda, bilateral) | ✅ |
| 7.3 | Casos de negación temporal | 2 (mareo_nocturno, odinofagia_resuelta) | ✅ |
| 7.4 | Casos de dosificación | 4 (ibuprofeno, amoxicilina, gotas, media_tableta) | ✅ |
| 7.5 | Casos de alergia | 2 (explícita, no_preguntada) | ✅ |
| 7.6 | Caso baseline simple | otalgia_simple | ✅ |

### 8. Integridad del Baseline

| # | Criterio | Verificación | Estado |
|---|----------|--------------|--------|
| 8.1 | expected_facts/* sin modificaciones para "pasar" | Git history limpio | ✅ |
| 8.2 | thresholds.json configurado | 6 thresholds definidos | ✅ |
| 8.3 | Baseline documentado como congelado | README actualizado | ✅ |
| 8.4 | Ningún ajuste cosmético a expected | Valores originales | ✅ |

### 9. Reportes y Salida

| # | Criterio | Verificación | Estado |
|---|----------|--------------|--------|
| 9.1 | report.json generado | Estructura completa | ✅ |
| 9.2 | report_summary.txt generado | Human-readable | ✅ |
| 9.3 | Error details con expected/actual | Para debugging | ✅ |
| 9.4 | agregados por campo | fieldMetrics en JSON | ✅ |
| 9.5 | Timestamp en reporte | ISO8601 | ✅ |

### 10. Comportamiento de Fallo Esperado

| # | Criterio | Verificación | Estado |
|---|----------|--------------|--------|
| 10.1 | otalgia_simple FALLA (no pasa) | 0% pass rate observado | ✅ |
| 10.2 | Errores MAJOR detectados | 10 errores MAJOR | ✅ |
| 10.3 | Hallucinations detectados | 2 hallucinations | ✅ |
| 10.4 | Evidence Coverage = 0% | Pipeline no preserva quotes | ✅ |
| 10.5 | Fallo es ESPERADO y DESEABLE | Documenta estado real | ✅ |

---

## RESUMEN DE VERIFICACIÓN

| Categoría | Criterios | Cumplidos | % |
|-----------|-----------|-----------|---|
| Infraestructura | 5 | 5 | 100% |
| Pipeline Real | 4 | 4 | 100% |
| Snapshots | 5 | 5 | 100% |
| Métricas | 6 | 6 | 100% |
| Severidad | 5 | 5 | 100% |
| Validadores | 6 | 6 | 100% |
| Casos de Prueba | 6 | 6 | 100% |
| Integridad Baseline | 4 | 4 | 100% |
| Reportes | 5 | 5 | 100% |
| Fallo Esperado | 5 | 5 | 100% |
| **TOTAL** | **51** | **51** | **100%** |

---

## DECLARACIÓN FORMAL

> ✅ **Todos los criterios de aceptación de ÉPICA 0 han sido verificados y cumplidos.**
>
> El sistema de evaluación clínica está operativo, mide correctamente el estado del pipeline, y los fallos observados son esperados y deseables.
>
> **ÉPICA 0 queda formalmente COMPLETADA.**

---

**Firma digital:** `SHA256:EPICA0-ACCEPT-2026-01-17`  
**Documento generado:** 2026-01-17T12:16:00-06:00
