import 'package:flutter/material.dart';

import '../../../../ui/docsoft_ui.dart';
import '../models/patients_filter.dart';
import '../widgets/patient_card.dart';

import '../widgets/patients_header.dart';

/// Patients page UI component
///
/// This is a pure UI component. Data fetching and navigation should be
/// handled by a wrapper widget (e.g., using Riverpod providers).
class PatientsPage extends StatefulWidget {
  const PatientsPage({
    super.key,
    required this.patients,
    required this.onTapPatient,
    required this.onNewPatient,
    required this.onNewNote,
    this.onViewNotes,
    this.onDeletePatient,
    this.onSearchChanged,
    this.onFilterChanged,
    this.isLoading = false,
  });

  /// List of patients to display
  final List<PatientDisplayData> patients;

  /// Callback when a patient card is tapped
  final void Function(PatientDisplayData patient) onTapPatient;

  /// Callback when "Nuevo paciente" is tapped
  final VoidCallback onNewPatient;

  /// Callback when "Nueva nota" is tapped for a patient
  final void Function(String patientId) onNewNote;

  /// Optional callback when "Ver notas" is tapped for a patient
  final void Function(String patientId)? onViewNotes;

  /// Optional callback when a patient is deleted via swipe.
  /// Returns a Future<bool> where true confirms the deletion.
  final Future<bool> Function(PatientDisplayData patient)? onDeletePatient;

  /// Optional callback when search text changes
  final ValueChanged<String>? onSearchChanged;

  /// Optional callback when filter changes (legacy int for backward compat)
  final ValueChanged<int>? onFilterChanged;

  /// Whether the page is loading
  final bool isLoading;

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  PatientsFilter _selectedFilter = PatientsFilter.all;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: SafeArea(
        child: Column(
          children: [
            PatientsHeader(onNewPatient: widget.onNewPatient),
            DocsoftSearchBar(
              hintText: 'Buscar paciente por nombre o teléfono',
              controller: _searchController,
              onChanged: widget.onSearchChanged,
            ),
            DocsoftFilterChips<PatientsFilter>(
              values: PatientsFilter.values,
              selected: _selectedFilter,
              labelBuilder: (filter) => filter.label,
              onSelected: (filter) {
                setState(() {
                  _selectedFilter = filter;
                });
                // Call legacy callback with int index for backward compatibility
                widget.onFilterChanged?.call(filter.toIndex());
              },
            ),
            Expanded(
              child: widget.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: DocsoftColors.primary,
                      ),
                    )
                  : widget.patients.isEmpty
                  ? _buildEmptyState()
                  : _buildPatientsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 16),
            Text(
              'No hay pacientes registrados',
              style: DocsoftTextStyles.subtitle.copyWith(
                color: DocsoftColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientsList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.screenPadding,
        vertical: DocsoftSpacing.sm,
      ),
      itemCount: widget.patients.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: DocsoftSpacing.itemSpacing),
      itemBuilder: (context, index) {
        final patient = widget.patients[index];

        // Use DismissiblePatientCard if delete callback is provided
        if (widget.onDeletePatient != null) {
          return DismissiblePatientCard(
            patient: patient,
            onTap: () => widget.onTapPatient(patient),
            onNewNote: () => widget.onNewNote(patient.id),
            onDelete: () => widget.onDeletePatient!(patient),
            onViewNotes: widget.onViewNotes != null
                ? () => widget.onViewNotes!(patient.id)
                : null,
          );
        }

        // Fallback to regular PatientCard
        return PatientCard(
          patient: patient,
          onTap: () => widget.onTapPatient(patient),
          onNewNote: () => widget.onNewNote(patient.id),
          onViewNotes: widget.onViewNotes != null
              ? () => widget.onViewNotes!(patient.id)
              : null,
        );
      },
    );
  }
}
