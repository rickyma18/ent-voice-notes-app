import 'package:flutter/material.dart';

/// Banner to display contract status warnings from the backend.
///
/// Shows appropriate visual feedback based on [status]:
/// - 'drift': Orange warning (potential schema mismatch)
/// - 'warning': Yellow warning (minor issues)
/// - 'ok' (or null): No banner
class ContractStatusBanner extends StatelessWidget {
  const ContractStatusBanner({super.key, this.status, this.warnings});

  /// Contract status: 'ok', 'warning', 'drift'.
  final String? status;

  /// List of specific warnings if any.
  final List<String>? warnings;

  @override
  Widget build(BuildContext context) {
    if (status != 'warning' && status != 'drift') {
      return const SizedBox.shrink();
    }

    final isDrift = status == 'drift';
    final color = isDrift ? Colors.orange.shade800 : Colors.amber.shade900;
    final bg = isDrift ? Colors.orange.shade50 : Colors.amber.shade50;
    final icon = isDrift ? Icons.warning_amber_rounded : Icons.info_outline;

    // Header text
    final title = isDrift
        ? 'Posible cambio en el modelo (Drift)'
        : 'Advertencia de contrato';

    // Main message
    final message = isDrift
        ? 'El modelo o contrato cambió; los resultados pueden variar.'
        : 'Se detectaron advertencias menores en la respuesta.';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: message,
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(Icons.help_outline, color: color, size: 18),
              ),
            ],
          ),
          if (warnings != null && warnings!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...warnings!.map(
              (w) => Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 2),
                child: Text(
                  '• $w',
                  style: TextStyle(color: color, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
