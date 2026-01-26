import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger/log.dart';
import '../controllers/job_queue_controller.dart';

class JobQueueStatusModal extends ConsumerWidget {
  const JobQueueStatusModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobQueueControllerProvider);
    final controller = ref.read(jobQueueControllerProvider.notifier);

    return PopScope(
      canPop: false, // Prevent back button closing (unless we handle it)
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            state.when(
              data: (status) {
                if (status == null) {
                  return const Text('Iniciando...');
                }

                final isQueued = status.status == 'queued';

                return Column(
                  children: [
                    // Status Label
                    Text(
                      isQueued ? 'En cola de espera' : 'Procesando nota...',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Progress Indicator
                    if (isQueued)
                      const LinearProgressIndicator() // Deterministic if we had value, but queued is usually indeterminate logic
                    else
                      const CircularProgressIndicator(),

                    const SizedBox(height: 24),

                    // Position & ETA
                    if (status.position != null && status.position! > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Posición en cola: ${status.position}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),

                    if (status.etaSeconds != null)
                      Text(
                        'Tiempo estimado: ${status.etaSeconds}s',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),

                    // Fallback Warning (ÉPICA 18)
                    if (status.fallbackUsed)
                      Container(
                        margin: const EdgeInsets.only(top: 24.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange.shade800,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Se usó un modo de respaldo por carga del sistema. Revisa la nota antes de guardar.',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (status.contractWarnings != null &&
                        status.contractWarnings!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          status.contractWarnings!.join('\n'),
                          style: const TextStyle(color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                );
              },
              error: (err, _) => Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: $err', textAlign: TextAlign.center),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
            ),

            const SizedBox(height: 32),

            // Cancel Button
            OutlinedButton(
              onPressed: () {
                Log.info('User clicked Cancel in JobQueueModal');
                controller.cancel();
                // The listener in the page will close the modal when state becomes null
              },
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
