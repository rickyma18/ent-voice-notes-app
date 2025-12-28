// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/patient_header.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../patients/domain/entities/patient_entity.dart';

/// Read-only header displaying patient information at the top of the wizard.
///
/// Shows:
/// - Patient name
/// - Age (derived from patient entity)
/// - Date (current date or existing note date, editable)
class PatientHeader extends StatelessWidget {
  const PatientHeader({
    super.key,
    required this.patient,
    required this.date,
    this.onDateChanged,
    this.isEditing = false,
  });

  final PatientEntity patient;
  final DateTime date;
  final ValueChanged<DateTime>? onDateChanged;
  final bool isEditing;

  /// Breakpoint for switching between wide (Row) and narrow (Column) layout.
  static const double _narrowBreakpoint = 420.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < _narrowBreakpoint;

            final avatar = CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                _getInitials(patient.fullName),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );

            final patientInfo = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _InfoChip(
                      icon: Icons.cake_outlined,
                      label: '${patient.age} años',
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: patient.sex.toUpperCase() == 'M'
                          ? Icons.male
                          : Icons.female,
                      label: patient.sexDisplay,
                    ),
                  ],
                ),
              ],
            );

            final dateContainer = InkWell(
              onTap: onDateChanged != null
                  ? () => _showDatePicker(context)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(date),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (onDateChanged != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit,
                        size: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ],
                  ],
                ),
              ),
            );

            if (isNarrow) {
              // Narrow layout: Column with two rows
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // First row: avatar + patient info
                  Row(
                    children: [
                      avatar,
                      const SizedBox(width: 16),
                      Expanded(child: patientInfo),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Second row: date container aligned right
                  Align(
                    alignment: Alignment.centerRight,
                    child: dateContainer,
                  ),
                ],
              );
            }

            // Wide layout: single Row
            return Row(
              children: [
                avatar,
                const SizedBox(width: 16),
                Expanded(child: patientInfo),
                dateContainer,
              ],
            );
          },
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Seleccionar fecha de consulta',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null && picked != date) {
      onDateChanged?.call(picked);
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
