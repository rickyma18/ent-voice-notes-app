// lib/src/features/medical_notes/presentation/pages/create_medical_note_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/note_status.dart';
import '../controllers/medical_notes_controller.dart';
import '../../medical_notes_providers.dart';

class CreateMedicalNotePage extends ConsumerStatefulWidget {
  const CreateMedicalNotePage({
    super.key,
    required this.patientId,
    required this.doctorId,
    this.existingNote,
  });

  /// Paciente al que pertenece la nota.
  final String patientId;

  /// Doctora que genera la nota.
  final String doctorId;

  /// Nota existente para editar. Si es null, se crea una nueva nota.
  final MedicalNoteEntity? existingNote;

  /// Helper para saber si estamos en modo edición
  bool get isEditMode => existingNote != null;

  @override
  ConsumerState<CreateMedicalNotePage> createState() =>
      _CreateMedicalNotePageState();
}

class _CreateMedicalNotePageState
    extends ConsumerState<CreateMedicalNotePage> {
  final _formKey = GlobalKey<FormState>();

  final _motivoController = TextEditingController();
  final _antecedentesController = TextEditingController();
  final _exploracionController = TextEditingController();
  final _diagnosticoController = TextEditingController();
  final _planController = TextEditingController();
  final _resumenController = TextEditingController();
  final _notaAdicionalController = TextEditingController();
  final _rawTranscriptController = TextEditingController();

  bool _isSaving = false;
  bool _isGeneratingIA = false;
  bool _isRecording = false;
  bool _isTranscribing = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill form fields if editing an existing note
    if (widget.existingNote != null) {
      final note = widget.existingNote!;
      _motivoController.text = note.motivoConsulta;
      _antecedentesController.text = note.antecedentes;
      _exploracionController.text = note.exploracionFisicaOrl;
      _diagnosticoController.text = note.diagnostico;
      _planController.text = note.planTratamiento;
      _rawTranscriptController.text = note.rawTranscript;
      _resumenController.text = note.resumen ?? '';
      _notaAdicionalController.text = note.notaAdicional ?? '';
    }
  }

  @override
  void dispose() {
    _motivoController.dispose();
    _antecedentesController.dispose();
    _exploracionController.dispose();
    _diagnosticoController.dispose();
    _planController.dispose();
    _resumenController.dispose();
    _notaAdicionalController.dispose();
    _rawTranscriptController.dispose();
    super.dispose();
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();
      final isEditing = widget.isEditMode;
      final existingNote = widget.existingNote;

      final MedicalNoteEntity note;

      if (isEditing && existingNote != null) {
        // 🔹 Modo EDICIÓN: actualizamos la nota existente preservando metadata
        note = existingNote.copyWith(
          updatedAt: now,
          motivoConsulta: _motivoController.text.trim(),
          antecedentes: _antecedentesController.text.trim(),
          exploracionFisicaOrl: _exploracionController.text.trim(),
          diagnostico: _diagnosticoController.text.trim(),
          planTratamiento: _planController.text.trim(),
          rawTranscript: _rawTranscriptController.text.trim(),
          resumen: _resumenController.text.trim().isEmpty
              ? null
              : _resumenController.text.trim(),
          notaAdicional: _notaAdicionalController.text.trim().isEmpty
              ? null
              : _notaAdicionalController.text.trim(),
        );

        await ref
            .read(medicalNotesControllerProvider.notifier)
            .updateMedicalNote(note);
      } else {
        // 🔹 Modo CREACIÓN: construimos una entidad nueva
        note = MedicalNoteEntity(
          id: '',
          patientId: widget.patientId,
          doctorId: widget.doctorId,
          createdAt: now,
          updatedAt: now,
          motivoConsulta: _motivoController.text.trim(),
          antecedentes: _antecedentesController.text.trim(),
          exploracionFisicaOrl: _exploracionController.text.trim(),
          diagnostico: _diagnosticoController.text.trim(),
          planTratamiento: _planController.text.trim(),
          rawTranscript: _rawTranscriptController.text.trim(),
          resumen: _resumenController.text.trim().isEmpty
              ? null
              : _resumenController.text.trim(),
          notaAdicional: _notaAdicionalController.text.trim().isEmpty
              ? null
              : _notaAdicionalController.text.trim(),
          status: NoteStatus.draft,
          medicamentosRecetados: const [],
          estudiosIndicados: const [],
          proximaCita: null,
          attachments: const [],
          tags: const [],
          isFavorite: false,
        );

        await ref
            .read(medicalNotesControllerProvider.notifier)
            .createMedicalNote(note);
      }

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Nota médica actualizada exitosamente'
                  : 'Nota médica creada exitosamente',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back to the list
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la nota: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _onGenerateWithIA() async {
    final raw = _rawTranscriptController.text.trim();

    if (raw.isEmpty) {
      // Si no hay transcripción, no tiene caso llamar a la IA
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero ingresa o genera una transcripción.'),
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingIA = true;
    });

    try {
      final aiService = ref.read(noteAIServiceProvider);

      // Pide a la IA sugerencias de campos estructurados
      final suggestions = await aiService.suggestStructuredFields(raw);

      // Mapeamos campos sugeridos a los TextEditingControllers
      if (suggestions['motivoConsulta'] != null &&
          suggestions['motivoConsulta']!.trim().isNotEmpty) {
        _motivoController.text = suggestions['motivoConsulta']!;
      }

      if (suggestions['antecedentes'] != null &&
          suggestions['antecedentes']!.trim().isNotEmpty) {
        _antecedentesController.text = suggestions['antecedentes']!;
      }

      if (suggestions['exploracionFisicaOrl'] != null &&
          suggestions['exploracionFisicaOrl']!.trim().isNotEmpty) {
        _exploracionController.text = suggestions['exploracionFisicaOrl']!;
      }

      if (suggestions['diagnostico'] != null &&
          suggestions['diagnostico']!.trim().isNotEmpty) {
        _diagnosticoController.text = suggestions['diagnostico']!;
      }

      if (suggestions['planTratamiento'] != null &&
          suggestions['planTratamiento']!.trim().isNotEmpty) {
        _planController.text = suggestions['planTratamiento']!;
      }

      if (suggestions['resumen'] != null &&
          suggestions['resumen']!.trim().isNotEmpty) {
        _resumenController.text = suggestions['resumen']!;
      }

      if (suggestions['notaAdicional'] != null &&
          suggestions['notaAdicional']!.trim().isNotEmpty) {
        _notaAdicionalController.text = suggestions['notaAdicional']!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campos sugeridos por IA aplicados.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar con IA: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingIA = false;
        });
      }
    }
  }

  /// Maneja el ciclo completo de grabación → transcripción → IA → pre-llenado.
  Future<void> _onRecordAudioAndProcess() async {
    final audioService = ref.read(audioRecordingServiceProvider);
    final aiService = ref.read(noteAIServiceProvider);

    // Si ya está grabando, detenemos
    if (_isRecording) {
      setState(() {
        _isTranscribing = true;
      });

      try {
        // 1. Detener grabación
        final audioFilePath = await audioService.stopRecording();

        if (audioFilePath == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: No se pudo obtener el archivo de audio'),
              ),
            );
          }
          return;
        }

        // 2. Transcribir audio a texto
        final transcript = await aiService.transcribeAudio(audioFilePath);

        // 3. Actualizar el campo de transcripción cruda
        _rawTranscriptController.text = transcript;

        // 4. Generar campos estructurados con IA
        setState(() {
          _isGeneratingIA = true;
          _isTranscribing = false;
        });

        final suggestions = await aiService.suggestStructuredFields(transcript);

        // 5. Pre-llenar los campos del formulario
        if (suggestions['motivoConsulta'] != null &&
            suggestions['motivoConsulta']!.trim().isNotEmpty) {
          _motivoController.text = suggestions['motivoConsulta']!;
        }

        if (suggestions['antecedentes'] != null &&
            suggestions['antecedentes']!.trim().isNotEmpty) {
          _antecedentesController.text = suggestions['antecedentes']!;
        }

        if (suggestions['exploracionFisicaOrl'] != null &&
            suggestions['exploracionFisicaOrl']!.trim().isNotEmpty) {
          _exploracionController.text = suggestions['exploracionFisicaOrl']!;
        }

        if (suggestions['diagnostico'] != null &&
            suggestions['diagnostico']!.trim().isNotEmpty) {
          _diagnosticoController.text = suggestions['diagnostico']!;
        }

        if (suggestions['planTratamiento'] != null &&
            suggestions['planTratamiento']!.trim().isNotEmpty) {
          _planController.text = suggestions['planTratamiento']!;
        }

        if (suggestions['resumen'] != null &&
            suggestions['resumen']!.trim().isNotEmpty) {
          _resumenController.text = suggestions['resumen']!;
        }

        if (suggestions['notaAdicional'] != null &&
            suggestions['notaAdicional']!.trim().isNotEmpty) {
          _notaAdicionalController.text = suggestions['notaAdicional']!;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Nota médica generada desde audio'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al procesar audio: $e'),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isRecording = false;
            _isTranscribing = false;
            _isGeneratingIA = false;
          });
        }
      }
    } else {
      // Iniciar grabación
      setState(() {
        _isRecording = true;
      });

      try {
        final started = await audioService.startRecording();

        if (!started) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: No se pudo iniciar la grabación'),
              ),
            );
            setState(() {
              _isRecording = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al iniciar grabación: $e'),
            ),
          );
          setState(() {
            _isRecording = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Editar nota médica' : 'Nueva nota médica'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ========================================
              // SECCIÓN 1: MOTIVO DE CONSULTA
              // ========================================
              _SectionCard(
                title: '1. Motivo de consulta',
                icon: Icons.help_outline,
                child: TextFormField(
                  controller: _motivoController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de consulta',
                    hintText: 'Ej: Dolor de oído derecho persistente',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el motivo de consulta';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ========================================
              // SECCIÓN 2: ANTECEDENTES
              // ========================================
              _SectionCard(
                title: '2. Antecedentes',
                icon: Icons.history,
                child: TextFormField(
                  controller: _antecedentesController,
                  decoration: const InputDecoration(
                    labelText: 'Antecedentes médicos relevantes',
                    hintText: 'Ej: Paciente con historial de otitis media crónica',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 16),

              // ========================================
              // SECCIÓN 3: EXPLORACIÓN FÍSICA ORL
              // ========================================
              _SectionCard(
                title: '3. Exploración física ORL',
                icon: Icons.medical_services,
                child: TextFormField(
                  controller: _exploracionController,
                  decoration: const InputDecoration(
                    labelText: 'Hallazgos de la exploración física',
                    hintText: 'Ej: Otoscopia: membrana timpánica hiperémia...',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  maxLines: 4,
                ),
              ),
              const SizedBox(height: 16),

              // ========================================
              // SECCIÓN 4: DIAGNÓSTICO
              // ========================================
              _SectionCard(
                title: '4. Diagnóstico',
                icon: Icons.local_hospital,
                highlighted: true,
                child: TextFormField(
                  controller: _diagnosticoController,
                  decoration: const InputDecoration(
                    labelText: 'Diagnóstico clínico',
                    hintText: 'Ej: Otitis media aguda derecha',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 16),

              // ========================================
              // SECCIÓN 5: PLAN / INDICACIONES
              // ========================================
              _SectionCard(
                title: '5. Plan de tratamiento',
                icon: Icons.medication,
                highlighted: true,
                child: TextFormField(
                  controller: _planController,
                  decoration: const InputDecoration(
                    labelText: 'Plan terapéutico e indicaciones',
                    hintText: 'Ej: Amoxicilina 500mg c/8h por 7 días...',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  maxLines: 4,
                ),
              ),
              const SizedBox(height: 24),

              // ========================================
              // SECCIÓN 6: IA Y TRANSCRIPCIÓN
              // ========================================
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'IA y transcripción',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (_isSaving || _isGeneratingIA || _isTranscribing)
                                  ? null
                                  : _onRecordAudioAndProcess,
                              style: _isRecording
                                  ? OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                    )
                                  : null,
                              icon: _isTranscribing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(_isRecording ? Icons.stop : Icons.mic),
                              label: Text(
                                _isTranscribing
                                    ? 'Procesando…'
                                    : (_isRecording ? 'Detener grabación' : 'Grabar audio'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isGeneratingIA ? null : _onGenerateWithIA,
                              icon: _isGeneratingIA
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.auto_awesome),
                              label: Text(
                                _isGeneratingIA ? 'Generando…' : 'Generar con IA',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _rawTranscriptController,
                        decoration: const InputDecoration(
                          labelText: 'Transcripción cruda (raw_transcript)',
                          hintText: 'Audio transcrito por IA o texto dictado',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ========================================
              // SECCIÓN 7: INFORMACIÓN ADICIONAL (OPCIONAL)
              // ========================================
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note_add, color: theme.colorScheme.secondary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Información adicional (opcional)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _resumenController,
                        decoration: const InputDecoration(
                          labelText: 'Resumen',
                          hintText: 'Resumen generado por IA de la consulta',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notaAdicionalController,
                        decoration: const InputDecoration(
                          labelText: 'Nota adicional',
                          hintText: 'Comentarios o notas adicionales del doctor',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _onSavePressed,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving
                        ? 'Guardando…'
                        : (widget.isEditMode ? 'Actualizar nota' : 'Guardar nota'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable section card for ENT clinical fields
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.highlighted = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: highlighted
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      elevation: highlighted ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: highlighted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: highlighted ? theme.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
