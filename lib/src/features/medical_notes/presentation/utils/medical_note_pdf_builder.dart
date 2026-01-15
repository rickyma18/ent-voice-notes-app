// lib/src/features/medical_notes/presentation/utils/medical_note_pdf_builder.dart

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/medical_note_entity.dart';

/// Builds a PDF document from a MedicalNoteEntity.
///
/// The PDF follows a clinical format with:
/// - Premium header with DocSoft branding (logo on page 1, symbol on 2+)
/// - All clinical sections in order
/// - Vital signs (if present)
/// - Surgical data (if applicable)
/// - Medications, studies, attachments (listed)
/// - Medical signature block at the end
/// - Footer with generation timestamp and page numbers
class MedicalNotePdfBuilder {
  MedicalNotePdfBuilder({
    required this.note,
    this.patientName,
    this.doctorName,
    this.doctorLicense,
    this.signatureImageBytes,
    this.signedAt,
  });

  final MedicalNoteEntity note;
  final String? patientName;
  final String? doctorName;
  final String? doctorLicense;

  /// Digital signature image bytes (PNG) to embed in the PDF
  final Uint8List? signatureImageBytes;

  /// Timestamp when the note was signed
  final DateTime? signedAt;

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _timeFormat = DateFormat('HH:mm');
  static final _fullDateFormat = DateFormat('dd/MM/yyyy HH:mm');

  // Branding images loaded from assets
  pw.MemoryImage? _logoHorizontal;
  pw.MemoryImage? _symbol;

  /// Generates the PDF document bytes.
  Future<Uint8List> build() async {
    // Load branding assets
    await _loadBrandingAssets();

    final pdf = pw.Document(
      title: 'Historia Clínica',
      author: 'DocSoft - Sistema de Notas Médicas',
      creator: 'DocSoft Medical Notes',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        header: _buildHeader,
        footer: _buildFooter,
        build: (context) => _buildContent(),
      ),
    );

    return pdf.save();
  }

  /// Loads branding assets from rootBundle.
  /// If loading fails, the PDF will still generate without logos.
  Future<void> _loadBrandingAssets() async {
    // Try to load the horizontal logo
    try {
      final logoData = await rootBundle.load(
        'assets/branding/symbol/docsoft_symbol.png',
      );
      _logoHorizontal = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      // Fallback: try to load the symbol instead
      try {
        final symbolData = await rootBundle.load(
          'assets/branding/symbol/docsoft_symbol.png',
        );
        _logoHorizontal = pw.MemoryImage(symbolData.buffer.asUint8List());
      } catch (_) {
        // Logo not available, will render without branding
        _logoHorizontal = null;
      }
    }

    // Try to load the symbol
    try {
      final symbolData = await rootBundle.load(
        'assets/branding/symbol/docsoft_symbol.png',
      );
      _symbol = pw.MemoryImage(symbolData.buffer.asUint8List());
    } catch (_) {
      // Symbol not available
      _symbol = null;
    }
  }

  /// Generates the suggested filename for the PDF.
  String get suggestedFileName {
    final sanitizedPatient = (patientName ?? 'Paciente')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(' ', '_');
    final dateStr = DateFormat('yyyyMMdd').format(note.createdAt);
    return 'HistoriaClinica_${sanitizedPatient}_$dateStr.pdf';
  }

  pw.Widget _buildHeader(pw.Context context) {
    final isFirstPage = context.pageNumber == 1;

    if (isFirstPage) {
      return _buildFirstPageHeader();
    } else {
      return _buildSubsequentPageHeader();
    }
  }

  /// Premium header for the first page with full branding.
  pw.Widget _buildFirstPageHeader() {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 12),
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Left: Logo or fallback text
          pw.Expanded(
            flex: 2,
            child: _logoHorizontal != null
                ? pw.Image(_logoHorizontal!, height: 26)
                : pw.Text(
                    'DocSoft',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
          ),
          // Center: Title and note type
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              children: [
                pw.Text(
                  'HISTORIA CLÍNICA',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  note.type.displayName,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          // Right: Patient and date
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  patientName ?? 'Paciente',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  _dateFormat.format(note.createdAt),
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact header for subsequent pages (page 2+).
  pw.Widget _buildSubsequentPageHeader() {
    final formattedDate = _dateFormat.format(note.createdAt);
    final displayPatient = patientName ?? 'Paciente';

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Symbol (if available)
          if (_symbol != null) ...[
            pw.Image(_symbol!, height: 14),
            pw.SizedBox(width: 8),
          ],
          // Compact info line
          pw.Expanded(
            child: pw.Text(
              'Historia clínica · $displayPatient · $formattedDate',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      padding: const pw.EdgeInsets.only(top: 10),
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generado: ${_fullDateFormat.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'DocSoft',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey400,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildContent() {
    final widgets = <pw.Widget>[];

    // Patient info card
    widgets.add(_buildInfoCard());
    widgets.add(pw.SizedBox(height: 16));

    // Main clinical sections
    widgets.add(_buildSection('Motivo de Consulta', note.motivoConsulta));
    widgets.add(_buildSection('Antecedentes', note.antecedentes));
    widgets.add(
      _buildSection('Exploración Física ORL', note.exploracionFisicaOrl),
    );

    // Vital signs
    if (_hasVitalSigns) {
      widgets.add(_buildVitalSignsSection());
    }

    // Diagnosis and plan (highlighted)
    widgets.add(_buildHighlightedSection('Diagnóstico', note.diagnostico));
    widgets.add(
      _buildHighlightedSection('Plan de Tratamiento', note.planTratamiento),
    );

    // Prognosis
    if (note.prognosis != null && note.prognosis!.isNotEmpty) {
      widgets.add(_buildSection('Pronóstico', note.prognosis!));
    }

    // Surgical data
    if (note.isSurgicalNote && note.surgicalData != null) {
      widgets.add(_buildSurgicalDataSection());
    }

    // Summary
    if (note.resumen != null && note.resumen!.isNotEmpty) {
      widgets.add(_buildSection('Resumen', note.resumen!));
    }

    // Additional notes
    if (note.notaAdicional != null && note.notaAdicional!.isNotEmpty) {
      widgets.add(_buildSection('Nota Adicional', note.notaAdicional!));
    }

    // Medications
    if (note.medicamentosRecetados.isNotEmpty) {
      widgets.add(_buildMedicationsSection());
    }

    // Studies
    if (note.estudiosIndicados.isNotEmpty) {
      widgets.add(_buildStudiesSection());
    }

    // Attachments (just list names)
    if (note.attachments.isNotEmpty) {
      widgets.add(_buildAttachmentsSection());
    }

    // Next appointment
    if (note.proximaCita != null) {
      widgets.add(_buildNextAppointmentSection());
    }

    // Tags
    if (note.tags.isNotEmpty) {
      widgets.add(_buildTagsSection());
    }

    // Medical signature block at the end
    widgets.add(pw.SizedBox(height: 24));
    widgets.add(_buildSignatureBlock());

    return widgets;
  }

  /// Builds the medical signature block at the end of the document.
  ///
  /// If [signatureImageBytes] is provided, displays the digital signature image.
  /// Otherwise, shows a placeholder line for manual signature.
  pw.Widget _buildSignatureBlock() {
    final hasDoctor = doctorName != null && doctorName!.isNotEmpty;
    final hasLicense = doctorLicense != null && doctorLicense!.isNotEmpty;
    final hasDigitalSignature = signatureImageBytes != null;

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: hasDigitalSignature ? const pw.EdgeInsets.all(12) : null,
      decoration: hasDigitalSignature
          ? pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: PdfColors.green200, width: 1),
            )
          : null,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section title
          pw.Row(
            children: [
              pw.Text(
                hasDigitalSignature ? 'Firma Digital' : 'Firma médica',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: hasDigitalSignature
                      ? PdfColors.green800
                      : PdfColors.grey700,
                ),
              ),
              if (hasDigitalSignature) ...[
                pw.SizedBox(width: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green100,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'FIRMADO',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: hasDigitalSignature ? 12 : 24),
          // Signature content
          pw.Center(
            child: pw.Column(
              children: [
                // Digital signature image or placeholder line
                if (hasDigitalSignature)
                  pw.Container(
                    height: 60,
                    width: 180,
                    child: pw.Image(
                      pw.MemoryImage(signatureImageBytes!),
                      fit: pw.BoxFit.contain,
                    ),
                  )
                else
                  pw.Container(
                    width: 200,
                    height: 0.5,
                    color: PdfColors.grey600,
                  ),
                pw.SizedBox(height: 8),
                // Horizontal line under signature
                if (hasDigitalSignature)
                  pw.Container(
                    width: 200,
                    height: 0.5,
                    color: PdfColors.green300,
                  ),
                if (hasDigitalSignature) pw.SizedBox(height: 8),
                // Doctor name
                pw.Text(
                  hasDoctor ? doctorName! : '_________________________',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: hasDoctor ? pw.FontWeight.bold : null,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 4),
                // License or DocSoft branding
                pw.Text(
                  hasLicense ? 'Cédula: $doctorLicense' : 'DocSoft',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                    fontStyle: hasLicense ? null : pw.FontStyle.italic,
                  ),
                ),
                // Signed timestamp
                if (hasDigitalSignature && signedAt != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Firmado el ${_fullDateFormat.format(signedAt!)}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoCard() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Paciente',
                  patientName ?? 'ID: ${note.patientId}',
                ),
                _buildInfoRow(
                  'Fecha de Consulta',
                  _fullDateFormat.format(note.createdAt),
                ),
                _buildInfoRow('Estado', note.status.displayName),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Tipo', note.type.displayName),
                _buildInfoRow(
                  'Última Actualización',
                  _fullDateFormat.format(note.updatedAt),
                ),
                _buildInfoRow(
                  'ID Nota',
                  note.id.substring(0, note.id.length > 8 ? 8 : note.id.length),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSection(String title, String content) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.grey400, width: 3),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 11),
            child: pw.Text(
              content.isEmpty ? '(No especificado)' : content,
              style: pw.TextStyle(
                fontSize: 10,
                color: content.isEmpty ? PdfColors.grey500 : PdfColors.black,
                fontStyle: content.isEmpty ? pw.FontStyle.italic : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildHighlightedSection(String title, String content) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.blue200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            content.isEmpty ? '(No especificado)' : content,
            style: pw.TextStyle(
              fontSize: 10,
              color: content.isEmpty ? PdfColors.grey500 : PdfColors.black,
              fontStyle: content.isEmpty ? pw.FontStyle.italic : null,
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasVitalSigns =>
      note.weightKg != null ||
      note.heightCm != null ||
      note.bpSystolic != null ||
      note.bpDiastolic != null ||
      note.heartRate != null ||
      note.respiratoryRate != null ||
      note.temperatureC != null ||
      note.spo2 != null;

  pw.Widget _buildVitalSignsSection() {
    final vitals = <String>[];
    if (note.weightKg != null) vitals.add('Peso: ${note.weightKg} kg');
    if (note.heightCm != null) vitals.add('Talla: ${note.heightCm} cm');
    if (note.bpSystolic != null || note.bpDiastolic != null) {
      vitals.add(
        'PA: ${note.bpSystolic ?? '-'}/${note.bpDiastolic ?? '-'} mmHg',
      );
    }
    if (note.heartRate != null) vitals.add('FC: ${note.heartRate} lpm');
    if (note.respiratoryRate != null)
      vitals.add('FR: ${note.respiratoryRate} rpm');
    if (note.temperatureC != null) vitals.add('Temp: ${note.temperatureC} °C');
    if (note.spo2 != null) vitals.add('SpO2: ${note.spo2}%');

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Signos Vitales',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 16,
            runSpacing: 4,
            children: vitals
                .map((v) => pw.Text(v, style: const pw.TextStyle(fontSize: 9)))
                .toList(),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSurgicalDataSection() {
    final data = note.surgicalData!;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.purple50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.purple200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Datos Quirúrgicos',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple800,
            ),
          ),
          pw.SizedBox(height: 8),
          if (data.tecnicaQuirurgica.isNotEmpty)
            _buildSurgicalField('Técnica Quirúrgica', data.tecnicaQuirurgica),
          if (data.hallazgos.isNotEmpty)
            _buildSurgicalField('Hallazgos', data.hallazgos),
          if (data.observaciones.isNotEmpty)
            _buildSurgicalField('Observaciones', data.observaciones),
          if (data.complicaciones.isNotEmpty)
            _buildSurgicalField(
              'Complicaciones',
              data.complicaciones,
              isWarning: true,
            ),
        ],
      ),
    );
  }

  pw.Widget _buildSurgicalField(
    String label,
    String value, {
    bool isWarning = false,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: isWarning ? PdfColors.red700 : PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              color: isWarning ? PdfColors.red800 : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMedicationsSection() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.green600, width: 3),
              ),
            ),
            child: pw.Text(
              'Medicamentos Recetados',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          ...note.medicamentosRecetados.map(
            (med) => pw.Padding(
              padding: const pw.EdgeInsets.only(left: 11, bottom: 4),
              child: pw.Text(
                '• ${med.nombre} - ${med.dosis} | ${med.frecuencia} por ${med.duracion}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStudiesSection() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.orange600, width: 3),
              ),
            ),
            child: pw.Text(
              'Estudios Indicados',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.orange800,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          ...note.estudiosIndicados.map(
            (study) => pw.Padding(
              padding: const pw.EdgeInsets.only(left: 11, bottom: 4),
              child: pw.Text(
                '• ${study.tipo}: ${study.descripcion}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAttachmentsSection() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.grey500, width: 3),
              ),
            ),
            child: pw.Text(
              'Archivos Adjuntos (${note.attachments.length})',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          ...note.attachments.map(
            (att) => pw.Padding(
              padding: const pw.EdgeInsets.only(left: 11, bottom: 4),
              child: pw.Text(
                '• ${att.nombre} (${att.tipo.displayName})',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildNextAppointmentSection() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'Próxima Cita: ',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
          pw.Text(
            '${_dateFormat.format(note.proximaCita!)} a las ${_timeFormat.format(note.proximaCita!)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTagsSection() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Wrap(
        spacing: 8,
        runSpacing: 4,
        children: note.tags
            .map(
              (tag) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(10),
                  ),
                ),
                child: pw.Text(tag, style: const pw.TextStyle(fontSize: 8)),
              ),
            )
            .toList(),
      ),
    );
  }
}
