// lib/src/features/medical_notes/presentation/pages/create_medical_note_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/medical_note_type.dart';
import '../../domain/entities/note_status.dart';
import '../../domain/entities/surgical_note_data_entity.dart';
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

  // Surgical note specific controllers
  final _tecnicaQuirurgicaController = TextEditingController();
  final _hallazgosController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _complicacionesController = TextEditingController();

  // Note type selection
  MedicalNoteType _selectedNoteType = MedicalNoteType.clinicalHistory;

  bool _isSaving = false;
  bool _isGeneratingIA = false;
  bool _isRecording = false;
  bool _isTranscribing = false;

  /// Tracks which field is currently being dictated to (for per-field dictation)
  TextEditingController? _dictatingController;

  @override
  void initState() {
    super.initState();
    // Pre-fill form fields if editing an existing note
    if (widget.existingNote != null) {
      final note = widget.existingNote!;
      _selectedNoteType = note.type;
      _motivoController.text = note.motivoConsulta;
      _antecedentesController.text = note.antecedentes;
      _exploracionController.text = note.exploracionFisicaOrl;
      _diagnosticoController.text = note.diagnostico;
      _planController.text = note.planTratamiento;
      _rawTranscriptController.text = note.rawTranscript;
      _resumenController.text = note.resumen ?? '';
      _notaAdicionalController.text = note.notaAdicional ?? '';

      // Pre-fill surgical data if present
      if (note.surgicalData != null) {
        _tecnicaQuirurgicaController.text = note.surgicalData!.tecnicaQuirurgica;
        _hallazgosController.text = note.surgicalData!.hallazgos;
        _observacionesController.text = note.surgicalData!.observaciones;
        _complicacionesController.text = note.surgicalData!.complicaciones;
      }
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
    // Surgical note controllers
    _tecnicaQuirurgicaController.dispose();
    _hallazgosController.dispose();
    _observacionesController.dispose();
    _complicacionesController.dispose();
    super.dispose();
  }

  /// Build SurgicalNoteDataEntity from form fields (only for surgical notes)
  SurgicalNoteDataEntity? _buildSurgicalData() {
    if (_selectedNoteType != MedicalNoteType.surgicalNote) {
      return null;
    }
    return SurgicalNoteDataEntity(
      tecnicaQuirurgica: _tecnicaQuirurgicaController.text.trim(),
      hallazgos: _hallazgosController.text.trim(),
      observaciones: _observacionesController.text.trim(),
      complicaciones: _complicacionesController.text.trim(),
    );
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
          type: _selectedNoteType,
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
          surgicalData: _buildSurgicalData(),
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
          type: _selectedNoteType,
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
          surgicalData: _buildSurgicalData(),
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

  /// Per-field voice dictation
  ///
  /// US 5.2: Voice dictation for rawTranscript (Speech-to-Text only, no AI)
  /// - First tap: Start recording
  /// - Second tap: Stop recording and transcribe to rawTranscript field
  Future<void> _onVoiceDictation() async {
    final audioService = ref.read(audioRecordingServiceProvider);
    final sttService = ref.read(speechToTextServiceProvider);

    // If already recording, stop and transcribe
    if (_isRecording && _dictatingController == null) {
      setState(() {
        _isTranscribing = true;
      });

      try {
        // 1. Stop recording
        final audioFilePath = await audioService.stopRecording();

        if (audioFilePath == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: No se pudo obtener el archivo de audio'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // 2. Transcribe audio using Speech-to-Text service
        final transcript = await sttService.transcribeAudio(audioFilePath);

        // 3. Update rawTranscript field
        _rawTranscriptController.text = transcript;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Audio transcrito correctamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al transcribir audio: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isRecording = false;
            _isTranscribing = false;
          });
        }
      }
    } else {
      // State guard: prevent starting if any operation is in progress
      if (_isRecording || _isTranscribing || _isSaving || _isGeneratingIA) {
        return;
      }

      // Start recording
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
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              _isRecording = false;
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎤 Grabando... Toca nuevamente para detener'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al iniciar grabación: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isRecording = false;
          });
        }
      }
    }
  }

  /// US 3.1: Allows dictating text for a specific field.
  /// - First tap: Start recording
  /// - Second tap: Stop recording, transcribe, and append/set text
  /// - Appends to existing text with a space, or sets if field is empty
  Future<void> _onDictateForField(TextEditingController targetController) async {
    final audioService = ref.read(audioRecordingServiceProvider);
    final aiService = ref.read(noteAIServiceProvider);

    // If we're dictating to this specific field, stop and process
    if (_dictatingController == targetController && _isRecording) {
      setState(() {
        _isTranscribing = true;
      });

      try {
        // 1. Stop recording
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

        // 2. Transcribe audio
        final transcript = await aiService.transcribeAudio(audioFilePath);

        // 3. Append or set text to the target field
        if (targetController.text.trim().isEmpty) {
          targetController.text = transcript;
        } else {
          targetController.text = '${targetController.text} $transcript';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Texto dictado agregado'),
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
            _dictatingController = null;
          });
        }
      }
      return;
    }

    // State guard: prevent starting if any operation is in progress
    if (_isRecording || _isTranscribing || _isSaving || _isGeneratingIA) {
      return;
    }

    // Start recording for this field
    setState(() {
      _isRecording = true;
      _dictatingController = targetController;
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
            _dictatingController = null;
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
          _dictatingController = null;
        });
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
              // NOTE TYPE SELECTOR
              // ========================================
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description,
                              color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Tipo de nota',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<MedicalNoteType>(
                          segments: const [
                            ButtonSegment<MedicalNoteType>(
                              value: MedicalNoteType.clinicalHistory,
                              label: Text('Historia Clínica'),
                              icon: Icon(Icons.assignment),
                            ),
                            ButtonSegment<MedicalNoteType>(
                              value: MedicalNoteType.surgicalNote,
                              label: Text('Nota Quirúrgica'),
                              icon: Icon(Icons.local_hospital),
                            ),
                          ],
                          selected: {_selectedNoteType},
                          onSelectionChanged: (Set<MedicalNoteType> selection) {
                            setState(() {
                              _selectedNoteType = selection.first;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ========================================
              // SECCIÓN 1: MOTIVO DE CONSULTA
              // ========================================
              _SectionCard(
                title: '1. Motivo de consulta',
                icon: Icons.help_outline,
                child: TextFormField(
                  controller: _motivoController,
                  decoration: InputDecoration(
                    labelText: 'Motivo de consulta',
                    hintText: 'Ej: Dolor de oído derecho persistente',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: _RecordingMicIcon(
                        isRecording: _isRecording && _dictatingController == _motivoController,
                      ),
                      tooltip: 'Dictar con voz',
                      onPressed: () => _onDictateForField(_motivoController),
                    ),
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
                  decoration: InputDecoration(
                    labelText: 'Hallazgos de la exploración física',
                    hintText: 'Ej: Otoscopia: membrana timpánica hiperémia...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: _RecordingMicIcon(
                        isRecording: _isRecording && _dictatingController == _exploracionController,
                      ),
                      tooltip: 'Dictar con voz',
                      onPressed: () => _onDictateForField(_exploracionController),
                    ),
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el diagnóstico clínico';
                    }
                    return null;
                  },
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
                  decoration: InputDecoration(
                    labelText: 'Plan terapéutico e indicaciones',
                    hintText: 'Ej: Amoxicilina 500mg c/8h por 7 días...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: _RecordingMicIcon(
                        isRecording: _isRecording && _dictatingController == _planController,
                      ),
                      tooltip: 'Dictar con voz',
                      onPressed: () => _onDictateForField(_planController),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el plan de tratamiento';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ========================================
              // SECCIÓN 6: DATOS QUIRÚRGICOS (solo para notas quirúrgicas)
              // ========================================
              if (_selectedNoteType == MedicalNoteType.surgicalNote) ...[
                Card(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_hospital,
                                color: theme.colorScheme.secondary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Datos Quirúrgicos',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _tecnicaQuirurgicaController,
                          decoration: const InputDecoration(
                            labelText: 'Técnica Quirúrgica *',
                            hintText: 'Descripción de la técnica utilizada',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          maxLines: 3,
                          validator: (value) {
                            if (_selectedNoteType ==
                                    MedicalNoteType.surgicalNote &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Ingresa la técnica quirúrgica';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _hallazgosController,
                          decoration: const InputDecoration(
                            labelText: 'Hallazgos',
                            hintText: 'Hallazgos intraoperatorios',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _observacionesController,
                          decoration: const InputDecoration(
                            labelText: 'Observaciones',
                            hintText: 'Observaciones adicionales',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _complicacionesController,
                          decoration: const InputDecoration(
                            labelText: 'Complicaciones',
                            hintText: 'Complicaciones durante el procedimiento',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ========================================
              // SECCIÓN 7: IA Y TRANSCRIPCIÓN
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

                      // US 5.2: Voice Dictation Button (Speech-to-Text only)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed:
                              (_isSaving || _isGeneratingIA || _isTranscribing)
                                  ? null
                                  : _onVoiceDictation,
                          style: (_isRecording && _dictatingController == null)
                              ? FilledButton.styleFrom(
                                  backgroundColor: Colors.red.shade100,
                                  foregroundColor: Colors.red.shade900,
                                )
                              : null,
                          icon: _isTranscribing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : (_isRecording && _dictatingController == null)
                                  ? const Icon(Icons.stop_circle)
                                  : const Icon(Icons.mic),
                          label: Text(
                            _isTranscribing
                                ? 'Transcribiendo audio...'
                                : ((_isRecording &&
                                        _dictatingController == null)
                                    ? 'Detener dictado'
                                    : 'Dictar nota por voz'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (_isSaving || _isGeneratingIA || _isTranscribing)
                                  ? null
                                  : _onRecordAudioAndProcess,
                              style: (_isRecording && _dictatingController == null)
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
                                  : (_isRecording && _dictatingController == null)
                                      ? const Icon(Icons.stop)
                                      : _RecordingMicIcon(
                                          isRecording: _isRecording && _dictatingController == null,
                                        ),
                              label: Text(
                                _isTranscribing
                                    ? 'Procesando…'
                                    : ((_isRecording && _dictatingController == null)
                                        ? 'Detener grabación'
                                        : 'IA y transcripción'),
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

/// Recording mic icon with pulsing animation
///
/// Shows a red pulsing mic icon when recording, normal mic icon otherwise.
/// Used for visual feedback in US 3.2.
class _RecordingMicIcon extends StatefulWidget {
  const _RecordingMicIcon({
    required this.isRecording,
  });

  final bool isRecording;

  @override
  State<_RecordingMicIcon> createState() => _RecordingMicIconState();
}

class _RecordingMicIconState extends State<_RecordingMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isRecording) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_RecordingMicIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRecording) {
      return const Icon(Icons.mic);
    }

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Icon(
          Icons.mic,
          color: Colors.red.withOpacity(_opacityAnimation.value),
        );
      },
    );
  }
}
