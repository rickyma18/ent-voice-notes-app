import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../medical_notes_providers.dart';
import '../../domain/entities/ai_engine.dart';

/// A simple widget to select the AI Engine.
///
/// Can be placed in a Settings page or a debug drawer.
class AiEngineSelector extends ConsumerWidget {
  const AiEngineSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEngineAsync = ref.watch(currentAiEngineProvider);

    return currentEngineAsync.when(
      data: (currentEngine) => PopupMenuButton<AiEngine>(
        initialValue: currentEngine,
        tooltip: 'Select AI Engine',
        child: Chip(
          label: Text(currentEngine.displayName),
          avatar: const Icon(Icons.psychology, size: 18),
        ),
        onSelected: (engine) {
          ref.read(currentAiEngineProvider.notifier).setEngine(engine);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched to ${engine.displayName}'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        itemBuilder: (context) {
          return AiEngine.values.map((engine) {
            return PopupMenuItem<AiEngine>(
              value: engine,
              child: Row(
                children: [
                  if (engine == currentEngine)
                    const Icon(Icons.check, size: 18, color: Colors.blue)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(engine.displayName),
                ],
              ),
            );
          }).toList();
        },
      ),
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Icon(Icons.error_outline),
    );
  }
}
