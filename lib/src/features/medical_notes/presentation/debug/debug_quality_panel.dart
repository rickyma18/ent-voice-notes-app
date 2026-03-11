// Debug-only panel that displays Quality Score + Consistency results.
//
// Visible only in debug builds (kDebugMode). Accepts pre-computed maps
// from quality_score_engine and clinical_consistency_engine.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Debug panel showing clinical output quality and consistency results.
///
/// All functionality is gated behind [kDebugMode].
class DebugQualityPanel extends StatelessWidget {
  const DebugQualityPanel({
    super.key,
    required this.quality,
    required this.consistency,
  });

  /// Output from [evaluateClinicalOutputQuality].
  final Map<String, dynamic>? quality;

  /// Output from [evaluateClinicalConsistency].
  final Map<String, dynamic>? consistency;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    if (quality == null && consistency == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        border: Border.all(color: Colors.deepPurple.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 16,
                color: Colors.deepPurple.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                'QA Quality & Consistency',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.deepPurple.shade800,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Quality scores
          if (quality != null) _buildQualitySection(context),

          // Consistency
          if (consistency != null) ...[
            if (quality != null) const SizedBox(height: 8),
            _buildConsistencySection(context),
          ],
        ],
      ),
    );
  }

  Widget _buildQualitySection(BuildContext context) {
    final q = quality!;
    final global = (q['score_global'] as double?) ?? 0.0;
    final comp = (q['score_completitud'] as double?) ?? 0.0;
    final cons = (q['score_consistencia'] as double?) ?? 0.0;
    final cal = (q['score_calidad_texto'] as double?) ?? 0.0;
    final warnings = (q['warnings'] as List?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Global score bar
        _ScoreRow(label: 'Global', value: global),
        const SizedBox(height: 4),
        _ScoreRow(label: 'Completitud', value: comp, compact: true),
        _ScoreRow(label: 'Consistencia', value: cons, compact: true),
        _ScoreRow(label: 'Calidad texto', value: cal, compact: true),

        // Warnings
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 12,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      w,
                      style: const TextStyle(fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConsistencySection(BuildContext context) {
    final c = consistency!;
    final isConsistent = (c['is_consistent'] as bool?) ?? true;
    final severity = (c['severity'] as String?) ?? 'low';
    final issues = (c['issues'] as List?)?.cast<String>() ?? [];

    final severityColor = switch (severity) {
      'high' => Colors.red.shade700,
      'medium' => Colors.orange.shade700,
      _ => Colors.green.shade700,
    };

    final severityIcon = switch (severity) {
      'high' => Icons.error,
      'medium' => Icons.warning,
      _ => Icons.check_circle,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status row
        Row(
          children: [
            Icon(severityIcon, size: 14, color: severityColor),
            const SizedBox(width: 4),
            Text(
              isConsistent ? 'Consistente' : 'Inconsistente',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: severityColor,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: severityColor.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                severity,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: severityColor,
                ),
              ),
            ),
          ],
        ),

        // Issues
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...issues.map(
            (issue) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.report_outlined,
                    size: 12,
                    color: severityColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      issue,
                      style: const TextStyle(fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A compact score row with label, numeric value, and colored bar.
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final double value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = value >= 0.8
        ? Colors.green.shade600
        : value >= 0.5
            ? Colors.orange.shade600
            : Colors.red.shade600;

    final fontSize = compact ? 11.0 : 12.0;
    final barHeight = compact ? 6.0 : 8.0;

    return Padding(
      padding: EdgeInsets.only(left: compact ? 8 : 0),
      child: Row(
        children: [
          SizedBox(
            width: compact ? 90 : 50,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: compact ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: barHeight,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
