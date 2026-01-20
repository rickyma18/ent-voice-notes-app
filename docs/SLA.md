# SLA & Operación — MedGemma Extraction Pipeline

> **ÉPICA 11**: End-to-End SLA & Observabilidad para MedGemma
>
> Última actualización: 2026-01-19

---

## 1. Resumen Ejecutivo

Este documento define los SLAs (Service Level Agreements) para el pipeline de extracción MedGemma, incluyendo:

- **Thresholds** de latencia y error rate
- **Alertas** automáticas (OK / WARNING / CRITICAL)
- **Playbook** operativo para respuesta a incidentes
- **Setup** para nuevos entornos

### Arquitectura de Métricas

```
┌─────────────────────────────────────────────────────────────┐
│                    ExtractorPipelineSelector                │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐   │
│  │  Advanced   │────▶│  Fallback   │────▶│  Baseline   │   │
│  │  (MedGemma) │     │  (timeout)  │     │  (OpenAI)   │   │
│  └──────┬──────┘     └─────────────┘     └──────┬──────┘   │
│         │                                        │          │
│         ▼                                        ▼          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              InMemoryMetricsSink                     │   │
│  │  - Latency buffers (p50, p95)                       │   │
│  │  - Request/error counters                            │   │
│  │  - Fallback tracking                                 │   │
│  └──────────────────────┬──────────────────────────────┘   │
└─────────────────────────┼───────────────────────────────────┘
                          ▼
                  ┌───────────────┐
                  │  SlaEvaluator │
                  │  OK/WARN/CRIT │
                  └───────────────┘
```

---

## 2. Thresholds Recomendados

### 2.1 Latencia (p95)

| Extractor | WARNING | CRITICAL | Notas |
|-----------|---------|----------|-------|
| Advanced (MedGemma) | ≥ 4000ms | ≥ 5000ms | Timeout automático a 5000ms |
| Baseline (OpenAI) | ≥ 6000ms | ≥ 8000ms | Timeout automático a 8000ms |

### 2.2 Tasas de Error

| Métrica | WARNING | CRITICAL | Descripción |
|---------|---------|----------|-------------|
| Fallback Rate | ≥ 10% | ≥ 25% | % de intentos advanced que cayeron a baseline |
| Error Rate | ≥ 5% | ≥ 15% | % de extracciones totales que fallaron |

### 2.3 Configuración en Código

```dart
// Default thresholds (producción)
const SlaThresholds.defaults = SlaThresholds(
  advancedP95WarningMs: 4000,
  advancedP95CriticalMs: 5000,
  baselineP95WarningMs: 6000,
  baselineP95CriticalMs: 8000,
  fallbackRateWarning: 0.10,
  fallbackRateCritical: 0.25,
  errorRateWarning: 0.05,
  errorRateCritical: 0.15,
  minSamplesForEvaluation: 5,
);

// Thresholds más estrictos para staging
const SlaThresholds.staging = SlaThresholds(
  advancedP95WarningMs: 3000,
  advancedP95CriticalMs: 4000,
  fallbackRateWarning: 0.05,
  fallbackRateCritical: 0.15,
);
```

---

## 3. Setup MedGemma

### 3.1 Requisitos

1. **Backend MedGemma Service** desplegado y accesible
2. **Firebase Auth** configurado para tokens de usuario
3. **Feature flag** `useMedGemmaExtractor` habilitado
4. **Usuario Pro** (subscription check)

### 3.2 Configuración en main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final container = ProviderContainer(
    overrides: [
      // 1. Configurar URL del backend MedGemma
      medGemmaBaseUrlProvider.overrideWithValue(
        'https://medgemma.yourservice.com',
      ),
      
      // 2. Habilitar feature flag (solo para Pro users)
      scribeFeatureFlagsProvider.overrideWithValue(
        FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
      ),
      
      // 3. (Opcional) Thresholds personalizados
      // slaThresholdsProvider.overrideWithValue(SlaThresholds(...)),
    ],
  );
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}
```

### 3.3 Verificación de Configuración

```dart
// En debug, verificar que MedGemma esté configurado
void _verifyMedGemmaSetup(WidgetRef ref) {
  final baseUrl = ref.read(medGemmaBaseUrlProvider);
  final flags = ref.read(scribeFeatureFlagsProvider);
  final isPro = ref.read(isProUserProvider);
  
  debugPrint('[MedGemma] baseUrl: ${baseUrl ?? "NOT SET"}');
  debugPrint('[MedGemma] useMedGemmaExtractor: ${flags.useMedGemmaExtractor}');
  debugPrint('[MedGemma] isPro: $isPro');
  
  if (baseUrl != null && flags.useMedGemmaExtractor && isPro) {
    debugPrint('[MedGemma] ✅ ENABLED');
  } else {
    debugPrint('[MedGemma] ❌ DISABLED (using baseline only)');
  }
}
```

---

## 4. Playbook Operativo

### 4.1 Estado: OK ✅

**Situación**: Todos los SLAs cumplidos.

**Acciones**: Ninguna requerida. Monitoreo normal.

### 4.2 Estado: WARNING ⚠️

**Situación**: Uno o más thresholds de warning excedidos.

**Síntomas comunes**:
- p95 Advanced latency entre 4000-5000ms
- Fallback rate entre 10-25%
- Error rate entre 5-15%

**Acciones inmediatas**:

1. **Verificar logs del backend MedGemma**
   ```bash
   # Cloud Run / GKE
   gcloud logging read "resource.type=cloud_run_revision AND 
     resource.labels.service_name=medgemma-service" --limit=50
   ```

2. **Revisar métricas del snapshot**
   ```dart
   final snapshot = metricsSink.snapshot();
   print('p95 Advanced: ${snapshot.p95ExtractAdvancedMs}ms');
   print('Fallback Rate: ${(snapshot.fallbackRate * 100).toStringAsFixed(1)}%');
   print('Errors: ${snapshot.errorsByType}');
   ```

3. **Verificar rate limits**
   - Revisar cuota de Vertex AI en Cloud Console
   - Verificar rate limiting del backend (`429 Too Many Requests`)

4. **Escalar si persiste > 15 min**
   - Notificar al equipo de backend
   - Considerar reducir `useMedGemmaExtractor` rollout %

### 4.3 Estado: CRITICAL 🚨

**Situación**: Uno o más thresholds críticos excedidos.

**Síntomas comunes**:
- p95 Advanced latency ≥ 5000ms (auto-timeout)
- Fallback rate ≥ 25%
- Error rate ≥ 15%

**Acciones inmediatas (< 5 min)**:

1. **¿El fallback a baseline funciona?**
   - SI → Los usuarios no están afectados, escalar con calma
   - NO → Esto es un P0, activar respuesta de incidente

2. **Deshabilitar MedGemma temporalmente**
   ```dart
   // Hotfix: Override feature flag to disable advanced
   scribeFeatureFlagsProvider.overrideWithValue(
     FeatureFlags.prod.copyWith(useMedGemmaExtractor: false),
   );
   ```

3. **Verificar salud del backend**
   ```bash
   curl -X GET https://medgemma.yourservice.com/v1/health
   ```

4. **Revisar errores específicos**
   ```dart
   final snapshot = metricsSink.snapshot();
   for (final entry in snapshot.errorsByType.entries) {
     print('${entry.key.name}: ${entry.value} errors');
   }
   ```

**Investigación (< 30 min)**:

| Error Type | Causa Probable | Acción |
|------------|----------------|--------|
| `timeout` | Backend lento, red congestionada | Verificar latencia de red, escalar backend |
| `backend` | MedGemma service down, Vertex AI error | Verificar Cloud Run, revisar quotas |
| `parse` | Respuesta malformada | Verificar modelo, revisar logs de response |
| `unauthorized` | Token expirado, Firebase issue | Verificar Firebase Auth config |

**Recuperación**:

1. Confirmar que el problema está resuelto en backend
2. Re-habilitar MedGemma gradualmente (10% → 50% → 100%)
3. Monitorear métricas por 1 hora
4. Documentar incidente en postmortem

---

## 5. Shadow Mode (Staging)

### 5.1 Propósito

Ejecutar baseline + advanced en paralelo para:
- Comparar latencias sin afectar UX
- Medir tasa de éxito de advanced antes de rollout
- Identificar edge cases donde advanced falla

### 5.2 Configuración

```dart
// En staging main.dart
scribeFeatureFlagsProvider.overrideWithValue(
  FeatureFlags.staging.copyWith(shadowMode: true),
),
```

### 5.3 Métricas Recolectadas (PHI-SAFE)

| Métrica | Descripción |
|---------|-------------|
| `baselineDurationMs` | Latencia del extractor baseline |
| `advancedDurationMs` | Latencia del extractor advanced |
| `advancedOutcome` | success / error / timeout |
| `advancedErrorType` | Tipo de error (sin mensaje) |
| `advancedWasFaster` | Boolean |

### 5.4 Análisis de Resultados

```dart
final shadowCollector = ref.read(shadowMetricsCollectorProvider);
final stats = shadowCollector.snapshot();

print('Total comparisons: ${stats.totalComparisons}');
print('Advanced success rate: ${(stats.advancedSuccessRate * 100).toStringAsFixed(1)}%');
print('Advanced faster: ${(stats.advancedFasterRate * 100).toStringAsFixed(1)}%');
print('Avg speedup: ${stats.avgSpeedImprovement.toStringAsFixed(2)}x');
```

**Criterios para habilitar en producción**:
- Advanced success rate ≥ 95%
- Advanced faster rate ≥ 60%
- p95 Advanced ≤ 4500ms
- No errores type: `unauthorized` o `parse`

---

## 6. Seguridad (PHI Compliance)

### 6.1 Lo que NUNCA se registra

- ❌ Transcripción de audio
- ❌ Hechos clínicos extraídos
- ❌ Identificadores de paciente (nombre, ID)
- ❌ Headers de autenticación
- ❌ Contenido de prompts

### 6.2 Lo que SÍ se registra

- ✅ Latencias (ms)
- ✅ Contadores de requests/errors
- ✅ Tipos de error (enum, no mensajes)
- ✅ Pipeline used (baseline/advanced)
- ✅ Timestamps

### 6.3 Verificación

Todos los archivos de métricas tienen el header:

```dart
// SECURITY: NO PHI - only evaluates numeric aggregates.
```

---

## 7. Referencia Rápida

### Comandos de Diagnóstico

```dart
// Obtener snapshot actual
final snapshot = metricsSink.snapshot();

// Evaluar SLA
final evaluator = SlaEvaluator(enableDebugLogging: true);
final result = evaluator.evaluate(snapshot);

// Imprimir estado
print('SLA Status: ${result.status.name}');
for (final v in result.violations) {
  print('  - ${v.metric}: ${v.value} exceeds ${v.threshold}');
}
```

### Checklist de Troubleshooting

- [ ] ¿Backend MedGemma responde a `/v1/health`?
- [ ] ¿Hay errores 429 (rate limit) en logs?
- [ ] ¿El fallback a baseline funciona?
- [ ] ¿Los tokens de Firebase están válidos?
- [ ] ¿Vertex AI quota está disponible?
- [ ] ¿La red tiene latencia alta? (p95 network > 200ms)

---

## 8. Historial de Cambios

| Fecha | Versión | Cambios |
|-------|---------|---------|
| 2026-01-19 | 1.0 | Documento inicial (ÉPICA 11) |

---

> **Contacto**: Para escalaciones, contactar al equipo de backend.
