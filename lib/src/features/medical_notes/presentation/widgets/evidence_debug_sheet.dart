// lib/src/features/medical_notes/presentation/widgets/evidence_debug_sheet.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/scribe/process_encounter_usecase.dart';
import 'package:medical_notes_app/src/ui/docsoft_ui.dart';

class EvidenceDebugSheet extends StatelessWidget {
  const EvidenceDebugSheet({super.key, required this.result, this.source});

  final MedicalScribeResult result;
  final String? source;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle drag
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Scribe V2 Evidence Trace',
                  style: DocsoftTextStyles.headline.copyWith(fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _buildMetadataSection(),
                _buildTimingsSection(),
                _buildTranscriptSection(),
                _buildComposerSection(),
                _buildFactsSection(),
                const SizedBox(height: DocsoftSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: DocsoftSpacing.sm),
        Text(
          title,
          style: DocsoftTextStyles.subtitle.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataSection() {
    return ExpansionTile(
      initiallyExpanded: true,
      title: _buildSectionHeader(
        'Pipeline Metadata',
        Icons.info_outline,
        Colors.blue.shade700,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKeyValue('Source', source ?? 'Unknown'),
              _buildKeyValue(
                'Language',
                result.facts.metadata.language ?? 'N/A',
              ),
              _buildKeyValue(
                'Negated Findings',
                result.negatedFindings.join(', '),
              ),
              _buildKeyValue(
                'Negated Count',
                '${result.negatedFindings.length}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimingsSection() {
    final t = result.timings;
    return ExpansionTile(
      title: _buildSectionHeader(
        'Timings (Total: ${t.totalMs}ms)',
        Icons.timer,
        Colors.purple.shade700,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTimingRow(
                'Transcription (STT)',
                t.transcriptionMs,
                t.totalMs,
              ),
              _buildTimingRow('Medicalization', t.medicalizationMs, t.totalMs),
              _buildTimingRow('Extraction', t.extractionMs, t.totalMs),
              _buildTimingRow('Composition', t.compositionMs, t.totalMs),
              const Divider(),
              _buildKeyValue('Total Pipeline', '${t.totalMs} ms'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptSection() {
    final segments = result.transcript.segments;
    return ExpansionTile(
      title: _buildSectionHeader(
        'Transcript (${segments.length} segments)',
        Icons.record_voice_over,
        Colors.green.shade700,
      ),
      children: [
        Container(
          height: 300,
          color: Colors.grey.shade50,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: segments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = segments[index];
              final start = (s.startMs ?? 0) / 1000.0;
              final end = (s.endMs ?? 0) / 1000.0;
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s.speaker,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: DocsoftColors.primary,
                          ),
                        ),
                        Text(
                          '${start.toStringAsFixed(1)}s - ${end.toStringAsFixed(1)}s',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      s.text,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComposerSection() {
    return ExpansionTile(
      title: _buildSectionHeader(
        'Composer SOAP',
        Icons.description,
        Colors.orange.shade800,
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.orange.shade50,
          child: SelectableText(
            result.soapText,
            style: const TextStyle(fontFamily: 'Courier', fontSize: 13),
          ),
        ),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: result.soapText));
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy SOAP'),
        ),
      ],
    );
  }

  Widget _buildFactsSection() {
    final jsonStr = const JsonEncoder.withIndent(
      '  ',
    ).convert(result.facts.toJson());
    return ExpansionTile(
      title: _buildSectionHeader(
        'Clinical Facts (JSON)',
        Icons.data_object,
        Colors.teal.shade700,
      ),
      children: [
        Container(
          width: double.infinity,
          height: 300,
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade900,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonStr,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                color: Colors.greenAccent,
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: jsonStr));
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy JSON'),
        ),
      ],
    );
  }

  Widget _buildKeyValue(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$key:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildTimingRow(String label, int ms, int total) {
    final pct = total > 0 ? (ms / total * 100).toStringAsFixed(1) : '0';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            '${ms}ms',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '($pct%)',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
