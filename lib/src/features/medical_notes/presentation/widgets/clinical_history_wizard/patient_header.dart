// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/patient_header.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../ui/docsoft_ui.dart';
import '../../../../patients/domain/entities/patient_entity.dart';

/// Read-only header displaying patient information at the top of the wizard.
///
/// Stitch-style design with:
/// - Large circular avatar with initials
/// - Name + age/sex row with icons
/// - Editable date chip on the right
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yy');

    return DocsoftCard(
      showBorder: true,
      borderColor: DocsoftColors.border,
      borderWidth: 1,
      padding: const EdgeInsets.all(DocsoftSpacing.md),
      child: Row(
        children: [
          // Avatar with initials
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: DocsoftColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(patient.fullName),
                style: DocsoftTextStyles.title.copyWith(
                  color: DocsoftColors.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: DocsoftSpacing.md),

          // Patient info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name
                Text(
                  patient.fullName,
                  style: DocsoftTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Age and sex row
                Row(
                  children: [
                    // Age
                    Icon(
                      Icons.cake_outlined,
                      size: 14,
                      color: DocsoftColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${patient.age} a\u00f1os',
                      style: DocsoftTextStyles.caption.copyWith(
                        color: DocsoftColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Separator dot
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: DocsoftColors.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sex
                    Text(
                      patient.sexDisplay,
                      style: DocsoftTextStyles.caption.copyWith(
                        color: DocsoftColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Date chip
          _DateChip(
            date: date,
            dateFormat: dateFormat,
            onTap: onDateChanged != null ? () => _showDatePicker(context) : null,
          ),
        ],
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

/// Compact date chip with calendar icon and edit icon.
class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.dateFormat,
    this.onTap,
  });

  final DateTime date;
  final DateFormat dateFormat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DocsoftRadii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DocsoftSpacing.sm,
          vertical: DocsoftSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: DocsoftColors.background,
          borderRadius: BorderRadius.circular(DocsoftRadii.sm),
          border: Border.all(color: DocsoftColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 14,
              color: DocsoftColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              dateFormat.format(date),
              style: DocsoftTextStyles.caption.copyWith(
                fontSize: 12,
                color: DocsoftColors.textSecondary,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.edit,
                size: 12,
                color: DocsoftColors.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
