// Debug-only "Paste transcript QA harness" panel.
//
// Visible only in debug builds (kDebugMode). Allows pasting a transcript
// and running the exact same pipeline used after voice STT completes.
//
// Features:
// - Multiline text field for pasting transcripts
// - Fixture presets dropdown for quick replay
// - Process / Load last voice / Compare / Clear buttons
// - Compact diff logging for antecedentes + symptom leakage

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/logger/log.dart';
import '../../application/medgemma/interview_fields_sanitizer.dart';
import 'interview_fixtures.dart';

/// Callback to process a transcript through the real pipeline.
typedef ProcessTranscriptCallback = Future<void> Function(
  String transcript, {
  required String source,
});

/// Debug-only panel for pasting transcripts and running the interview pipeline.
///
/// All functionality is gated behind [kDebugMode].
class DebugTranscriptPanel extends StatefulWidget {
  const DebugTranscriptPanel({
    super.key,
    required this.onProcess,
    required this.lastVoiceTranscript,
    required this.isProcessing,
  });

  final ProcessTranscriptCallback onProcess;
  final String? lastVoiceTranscript;
  final bool isProcessing;

  @override
  State<DebugTranscriptPanel> createState() => _DebugTranscriptPanelState();
}

class _DebugTranscriptPanelState extends State<DebugTranscriptPanel> {
  final _controller = TextEditingController();
  InterviewFixture? _selectedFixture;
  bool _isComparing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadFixture(InterviewFixture? fixture) {
    if (fixture == null) return;
    setState(() {
      _selectedFixture = fixture;
      _controller.text = fixture.transcript;
    });
  }

  void _loadLastVoice() {
    final t = widget.lastVoiceTranscript;
    if (t == null || t.trim().isEmpty) {
      Log.info('[DEBUG-QA] No last voice transcript available');
      return;
    }
    setState(() {
      _controller.text = t;
      _selectedFixture = null;
    });
  }

  Future<void> _processText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await widget.onProcess(text, source: 'debug_paste');
  }

  Future<void> _compareVoiceVsPasted() async {
    final voiceT = widget.lastVoiceTranscript?.trim() ?? '';
    final pastedT = _controller.text.trim();
    if (voiceT.isEmpty || pastedT.isEmpty) {
      Log.info('[DEBUG-QA] Compare requires both voice and pasted transcripts');
      return;
    }

    setState(() => _isComparing = true);
    try {
      Log.info('[DEBUG-QA] ── Compare start ──');

      // Run both through sanitizeInterviewFields with a mock structure
      // to see the diff. The real pipeline is async, so we just compare
      // the sanitizer output here for instant feedback.
      final voiceResult = _runSanitizerOnly(voiceT);
      final pastedResult = _runSanitizerOnly(pastedT);

      _logDiff('voice', voiceResult, 'pasted', pastedResult);
      Log.info('[DEBUG-QA] ── Compare end ──');
    } finally {
      if (mounted) setState(() => _isComparing = false);
    }
  }

  /// Runs sanitizeInterviewFields on a mock structured map that mimics
  /// what the backend would return. This is for diff comparison only.
  Map<String, dynamic> _runSanitizerOnly(String transcript) {
    // Build a minimal map with the transcript as padecimiento_actual
    // and motivo_consulta to exercise the sanitizer.
    return sanitizeInterviewFields({
      'motivo_consulta': '',
      'padecimiento_actual': transcript,
    });
  }

  void _logDiff(
    String labelA,
    Map<String, dynamic> a,
    String labelB,
    Map<String, dynamic> b,
  ) {
    // Top-level key diff
    final keysA = a.keys.toSet();
    final keysB = b.keys.toSet();
    final added = keysB.difference(keysA);
    final removed = keysA.difference(keysB);
    if (added.isNotEmpty || removed.isNotEmpty) {
      Log.info('[DEBUG-QA] keys added=$added removed=$removed');
    }

    // Antecedentes diff
    final anteA = a['antecedentes'] as Map<String, dynamic>? ?? {};
    final anteB = b['antecedentes'] as Map<String, dynamic>? ?? {};
    for (final key in {'patologicos', 'no_patologicos'}) {
      final vA = (anteA[key] as String?)?.trim() ?? '';
      final vB = (anteB[key] as String?)?.trim() ?? '';
      if (vA != vB) {
        final linesA = vA.split('\n').where((l) => l.trim().isNotEmpty).toSet();
        final linesB = vB.split('\n').where((l) => l.trim().isNotEmpty).toSet();
        final addedLines = linesB.difference(linesA);
        final removedLines = linesA.difference(linesB);
        Log.info(
          '[DEBUG-QA] ante.$key diff: '
          '+${addedLines.length} -${removedLines.length}',
        );
        for (final l in addedLines) {
          Log.debug('[DEBUG-QA]   + $l');
        }
        for (final l in removedLines) {
          Log.debug('[DEBUG-QA]   - $l');
        }
      }
    }

    // Symptom leakage check
    _checkSymptomLeakage(labelB, anteB);
  }

  static const _kSymptomTokens = {
    'fiebre', 'tos', 'dolor', 'disnea', 'cefalea', 'odinofagia',
    'otalgia', 'rinorrea', 'nausea', 'náusea', 'vómito', 'vomito',
    'mareo', 'diarrea', 'gripe', 'secrecion', 'secreción', 'sangre',
    'zumbido',
  };

  void _checkSymptomLeakage(String label, Map<String, dynamic> ante) {
    final pat = (ante['patologicos'] as String?)?.toLowerCase() ?? '';
    if (pat.isEmpty) return;
    final leaked = <String>[];
    for (final sym in _kSymptomTokens) {
      if (pat.contains(sym)) leaked.add(sym);
    }
    if (leaked.isNotEmpty) {
      Log.warning(
        '[DEBUG-QA] SYMPTOM LEAK in $label ante.patologicos: $leaked',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final isProcessing = widget.isProcessing || _isComparing;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, size: 16, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                'QA Transcript Harness',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fixture dropdown
          DropdownButtonFormField<InterviewFixture>(
            // ignore: deprecated_member_use
            value: _selectedFixture,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Fixture',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<InterviewFixture>(
                value: null,
                child: Text('(none)', style: TextStyle(fontSize: 12)),
              ),
              ...kInterviewFixtures.map(
                (f) => DropdownMenuItem(
                  value: f,
                  child: Text(f.name, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
            onChanged: _loadFixture,
          ),
          const SizedBox(height: 8),

          // Transcript text field
          TextField(
            controller: _controller,
            maxLines: null,
            minLines: 6,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Paste transcript here...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(8),
            ),
          ),
          const SizedBox(height: 8),

          // Action buttons
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ActionButton(
                label: 'Process text',
                icon: Icons.play_arrow,
                onPressed: isProcessing ? null : _processText,
              ),
              _ActionButton(
                label: 'Load last voice',
                icon: Icons.mic,
                onPressed: isProcessing ? null : _loadLastVoice,
              ),
              _ActionButton(
                label: 'Compare',
                icon: Icons.compare_arrows,
                onPressed: isProcessing ? null : _compareVoiceVsPasted,
              ),
              _ActionButton(
                label: 'Clear',
                icon: Icons.clear,
                onPressed: isProcessing
                    ? null
                    : () => setState(() {
                          _controller.clear();
                          _selectedFixture = null;
                        }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
