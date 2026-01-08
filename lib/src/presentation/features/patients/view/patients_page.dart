import 'package:flutter/material.dart';

import '../../../../../ui/theme/colors.dart';
import '../widgets/patient_card.dart';
import '../widgets/patient_filter_chips.dart';
import '../widgets/patient_search_bar.dart';
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

  /// Optional callback when search text changes
  final ValueChanged<String>? onSearchChanged;

  /// Optional callback when filter changes
  final ValueChanged<int>? onFilterChanged;

  /// Whether the page is loading
  final bool isLoading;

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  int _selectedFilterIndex = 0;
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
            PatientSearchBar(
              controller: _searchController,
              onChanged: widget.onSearchChanged,
            ),
            PatientFilterChips(
              selectedIndex: _selectedFilterIndex,
              onFilterSelected: (index) {
                setState(() {
                  _selectedFilterIndex = index;
                });
                widget.onFilterChanged?.call(index);
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
            Icon(
              Icons.people_outline,
              size: 64,
              color: DocsoftColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay pacientes registrados',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      itemCount: widget.patients.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final patient = widget.patients[index];
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
