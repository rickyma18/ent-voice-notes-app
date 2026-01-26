import 'package:freezed_annotation/freezed_annotation.dart';

part 'pipeline_flags.freezed.dart';
part 'pipeline_flags.g.dart';

@freezed
abstract class PipelineFlags with _$PipelineFlags {
  const factory PipelineFlags({
    /// When true, the app trusts backend structured V1 output and disables local medicalization.
    @Default(true) bool pipelineEnabled,

    /// Must be forced OFF when pipelineEnabled == true.
    /// Controls whether local normalization/negation/inference runs.
    @Default(false) bool localMedicalization,

    /// If true, runs pipeline output as primary and legacy in background for telemetry comparison.
    /// Debug/Beta only.
    @Default(false) bool abCompareEnabled,
  }) = _PipelineFlags;

  factory PipelineFlags.fromJson(Map<String, dynamic> json) =>
      _$PipelineFlagsFromJson(json);
}
