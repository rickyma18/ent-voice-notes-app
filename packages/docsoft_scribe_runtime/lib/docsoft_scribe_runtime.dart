// packages/docsoft_scribe_runtime/lib/docsoft_scribe_runtime.dart
//
// Dart-only runtime for DocSoft Scribe pipeline.
// NO Flutter dependencies - can be used with `dart run`.

// Core re-exports (from docsoft_scribe_core)
export 'package:docsoft_scribe_core/src/core/failure.dart';
export 'package:docsoft_scribe_core/src/core/result.dart';
export 'package:docsoft_scribe_core/src/core/logger.dart';

// DTOs re-exports
export 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
export 'package:docsoft_scribe_core/src/dtos/evidence_dto.dart';

// Entities re-exports
export 'package:docsoft_scribe_core/src/entities/transcript_segment.dart';
export 'package:docsoft_scribe_core/src/entities/transcript_with_speakers.dart';

// Repository interfaces re-exports
export 'package:docsoft_scribe_core/src/repositories/encounter_extractor_repository.dart';
export 'package:docsoft_scribe_core/src/repositories/note_composer_repository.dart';
export 'package:docsoft_scribe_core/src/repositories/transcription_repository.dart';

// Glossary re-exports
export 'package:docsoft_scribe_core/src/glossary/glossary_loader.dart';
export 'package:docsoft_scribe_core/src/glossary/medicalization_mapping.dart';

// Medicalization re-exports
export 'package:docsoft_scribe_core/src/medicalization/medicalization_glossary.dart';
export 'package:docsoft_scribe_core/src/medicalization/medicalization_service.dart';

// Pipeline re-exports
export 'package:docsoft_scribe_core/src/pipeline/clinical_facts_sanitizer.dart';
export 'package:docsoft_scribe_core/src/pipeline/ros_reconciliation_service.dart';

// Prompts re-exports
export 'package:docsoft_scribe_core/src/prompts/extractor_prompts.dart';
export 'package:docsoft_scribe_core/src/prompts/composer_prompts.dart';

// Config re-exports
export 'package:docsoft_scribe_core/src/config/feature_flags.dart';

// Runtime components
export 'src/clients/openai_client.dart';
export 'src/clients/openai_extractor_client.dart';
export 'src/clients/openai_composer_client.dart';
export 'src/repositories/encounter_extractor_repository_impl.dart';
export 'src/repositories/note_composer_repository_impl.dart';
export 'src/pipeline/process_encounter_usecase.dart';
export 'src/pipeline/scribe_pipeline_runner.dart';
export 'src/pipeline/scribe_pipeline_factory.dart';
export 'src/pipeline/extractor_pipeline_selector.dart';
export 'src/glossary/file_glossary_loader.dart' show RuntimeFileGlossaryLoader;
export 'src/validation/json_extractor.dart';
export 'src/validation/clinical_facts_validator.dart';

// Heuristics
export 'src/heuristics/heuristics.dart';

// Metrics (ÉPICA 11)
export 'src/metrics/metrics_sink.dart';
export 'src/metrics/in_memory_metrics_sink.dart';
export 'src/metrics/alerting.dart';
export 'src/metrics/sla_evaluator.dart';
export 'src/metrics/shadow_metrics_collector.dart';
