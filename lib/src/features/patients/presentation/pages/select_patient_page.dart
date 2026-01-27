// lib/src/features/patients/presentation/pages/select_patient_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../ui/docsoft_ui.dart';
import '../../../../presentation/core/router/route_names.dart';
import '../../../../presentation/features/patients/widgets/patient_card.dart';
import '../../../medical_notes/domain/entities/medical_note_entity.dart';
import '../../../medical_notes/presentation/controllers/medical_notes_controller.dart';
import '../../../medical_notes/presentation/widgets/note_type_selector_bottom_sheet.dart';
import '../../domain/entities/patient_entity.dart';
import '../controllers/patients_controller.dart';

/// US-D1: Page for selecting a patient to view their medical notes
/// Uses Docsoft UI components for consistency with PatientsPage.
class SelectPatientPage extends ConsumerStatefulWidget {
  const SelectPatientPage({super.key});

  @override
  ConsumerState<SelectPatientPage> createState() => _SelectPatientPageState();
}

class _SelectPatientPageState extends ConsumerState<SelectPatientPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Convert PatientEntity to PatientDisplayData for PatientCard
  PatientDisplayData _toDisplayData(PatientEntity p, int notesCount) {
    final parts = p.fullName.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (parts.isNotEmpty ? parts.first[0].toUpperCase() : '?');

    return PatientDisplayData(
      id: p.id,
      initials: initials,
      name: p.fullName,
      age: p.age,
      sex: p.sex,
      notesCount: notesCount,
    );
  }

  /// Filter patients by search query (name match)
  List<PatientEntity> _filterPatients(List<PatientEntity> patients) {
    if (_searchQuery.isEmpty) return patients;
    final query = _searchQuery.toLowerCase();
    return patients
        .where((p) => p.fullName.toLowerCase().contains(query))
        .toList();
  }

  void _handleViewNotes(PatientEntity patient) {
    context.pushNamed(RouteNames.medicalNotesList, extra: patient);
  }

  Future<void> _handleCreateNote(PatientEntity patient) async {
    final created = await showNoteTypeSelectorBottomSheet(context, patient);
    if (mounted && created == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsControllerProvider);
    final medicalNotesAsync = ref.watch(medicalNotesControllerProvider);

    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DocsoftSpacing.screenPadding,
                DocsoftSpacing.screenPadding,
                DocsoftSpacing.screenPadding,
                DocsoftSpacing.sm,
              ),
              child: Row(
                children: [
                  // Back button
                  DocsoftBackButton(
                    onTap: () => context.pop(),
                    backgroundColor: DocsoftColors.primaryMuted,
                    iconColor: DocsoftColors.primary,
                  ),
                  const SizedBox(width: DocsoftSpacing.sm),
                  Text(
                    'Seleccionar paciente',
                    style: DocsoftTextStyles.appBarTitle,
                  ),
                ],
              ),
            ),

            // Search bar
            DocsoftSearchBar(
              hintText: 'Buscar paciente por nombre',
              controller: _searchController,
              onChanged: (query) {
                setState(() {
                  _searchQuery = query;
                });
              },
            ),

            // Content
            Expanded(
              child: patientsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: DocsoftColors.primary,
                  ),
                ),
                error: (error, _) => _buildErrorState(error),
                data: (patients) {
                  final filteredPatients = _filterPatients(patients);

                  if (patients.isEmpty) {
                    return _buildEmptyState();
                  }

                  if (filteredPatients.isEmpty) {
                    return _buildNoResultsState();
                  }

                  // Sort alphabetically by name (A-Z, case-insensitive)
                  final sortedPatients = [...filteredPatients]
                    ..sort(
                      (a, b) => a.fullName.toLowerCase().compareTo(
                        b.fullName.toLowerCase(),
                      ),
                    );

                  // Get all medical notes (data or empty list)
                  final notes =
                      medicalNotesAsync.value ?? const <MedicalNoteEntity>[];

                  // Build a map: patientId -> note count
                  final notesByPatient = <String, int>{};
                  for (final note in notes) {
                    notesByPatient[note.patientId] =
                        (notesByPatient[note.patientId] ?? 0) + 1;
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DocsoftSpacing.screenPadding,
                      vertical: DocsoftSpacing.sm,
                    ),
                    itemCount: sortedPatients.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: DocsoftSpacing.itemSpacing),
                    itemBuilder: (context, index) {
                      final patient = sortedPatients[index];
                      final notesCount = notesByPatient[patient.id] ?? 0;
                      final displayData = _toDisplayData(patient, notesCount);

                      return PatientCard(
                        patient: displayData,
                        onTap: () => _handleCreateNote(patient),
                        onNewNote: () => _handleCreateNote(patient),
                        onViewNotes: () => _handleViewNotes(patient),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DocsoftSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: DocsoftColors.error,
            ),
            const SizedBox(height: DocsoftSpacing.md),
            Text(
              'Error al cargar pacientes',
              style: DocsoftTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DocsoftSpacing.sm),
            Text(
              error.toString(),
              style: DocsoftTextStyles.caption,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DocsoftSpacing.lg),
            DocsoftPrimaryButton(
              onPressed: () {
                ref.read(patientsControllerProvider.notifier).refresh();
              },
              label: 'Reintentar',
              icon: Icons.refresh_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DocsoftSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/branding/states/docsoft_patient_profile.png',
                width: 80,
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: DocsoftSpacing.md),
            Text(
              'No hay pacientes registrados',
              style: DocsoftTextStyles.subtitle.copyWith(
                color: DocsoftColors.textSecondary,
              ),
            ),
            const SizedBox(height: DocsoftSpacing.sm),
            Text(
              'Crea un paciente primero para poder crear notas médicas',
              style: DocsoftTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DocsoftSpacing.lg),
            DocsoftPrimaryButton(
              onPressed: () {
                context.pushNamed(RouteNames.patientsCreate);
              },
              label: 'Crear paciente',
              icon: Icons.person_add_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: DocsoftColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: DocsoftSpacing.md),
          Text(
            'Sin resultados',
            style: DocsoftTextStyles.subtitle.copyWith(
              color: DocsoftColors.textSecondary,
            ),
          ),
          const SizedBox(height: DocsoftSpacing.xs),
          Text(
            'No se encontraron pacientes con ese nombre',
            style: DocsoftTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
