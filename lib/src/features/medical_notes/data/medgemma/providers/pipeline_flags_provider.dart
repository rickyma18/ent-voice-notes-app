import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/logger/log.dart';

import '../../../domain/entities/pipeline_flags.dart';

/// App-wide configuration for the extraction pipeline (ÉPICA 19).
final pipelineFlagsProvider = Provider<PipelineFlags>((ref) {
  // TODO: Future enhancement - load from remote config or debug menu
  const flags = PipelineFlags(
    pipelineEnabled: true,
    localMedicalization: false,
    abCompareEnabled: false,
  );

  // Enforce rule: localMedicalization MUST be OFF if pipelineEnabled is true.
  if (flags.pipelineEnabled && flags.localMedicalization) {
    Log.error(
      '[PIPELINE] Invalid config: localMedicalization ON while pipelineEnabled ON. Forcing localMedicalization=OFF.',
    );
    return flags.copyWith(localMedicalization: false);
  }

  return flags;
});
