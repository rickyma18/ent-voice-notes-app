// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/vitals_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A compact card for entering vital signs in a clinical history wizard.
///
/// Displays vital sign inputs in a space-efficient 2-column layout with
/// proper numeric validation and unit suffixes.
class VitalsCard extends StatelessWidget {
  const VitalsCard({
    super.key,
    required this.weightController,
    required this.heightController,
    required this.bpSystolicController,
    required this.bpDiastolicController,
    required this.heartRateController,
    required this.respiratoryRateController,
    required this.temperatureController,
    required this.spo2Controller,
  });

  final TextEditingController weightController;
  final TextEditingController heightController;
  final TextEditingController bpSystolicController;
  final TextEditingController bpDiastolicController;
  final TextEditingController heartRateController;
  final TextEditingController respiratoryRateController;
  final TextEditingController temperatureController;
  final TextEditingController spo2Controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.monitor_heart_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Signos Vitales',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '(Opcional)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 1: Peso + Talla
            Row(
              children: [
                Expanded(
                  child: _VitalField(
                    controller: weightController,
                    label: 'Peso',
                    suffix: 'kg',
                    hint: '70',
                    minValue: 1,
                    maxValue: 300,
                    allowDecimal: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _VitalField(
                    controller: heightController,
                    label: 'Talla',
                    suffix: 'cm',
                    hint: '170',
                    minValue: 30,
                    maxValue: 250,
                    allowDecimal: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Presión arterial (Sistólica / Diastólica)
            _BloodPressureField(
              systolicController: bpSystolicController,
              diastolicController: bpDiastolicController,
            ),
            const SizedBox(height: 12),

            // Row 3: FC + FR
            Row(
              children: [
                Expanded(
                  child: _VitalField(
                    controller: heartRateController,
                    label: 'FC',
                    suffix: 'lpm',
                    hint: '72',
                    minValue: 20,
                    maxValue: 250,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _VitalField(
                    controller: respiratoryRateController,
                    label: 'FR',
                    suffix: 'rpm',
                    hint: '16',
                    minValue: 5,
                    maxValue: 80,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 4: Temperatura + SpO2
            Row(
              children: [
                Expanded(
                  child: _VitalField(
                    controller: temperatureController,
                    label: 'Temp',
                    suffix: '°C',
                    hint: '36.5',
                    minValue: 30,
                    maxValue: 45,
                    allowDecimal: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _VitalField(
                    controller: spo2Controller,
                    label: 'SpO2',
                    suffix: '%',
                    hint: '98',
                    minValue: 50,
                    maxValue: 100,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact numeric input field for a single vital sign.
class _VitalField extends StatelessWidget {
  const _VitalField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.hint,
    required this.minValue,
    required this.maxValue,
    this.allowDecimal = false,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final String hint;
  final num minValue;
  final num maxValue;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
            decimal: allowDecimal,
          ),
          inputFormatters: [
            if (allowDecimal)
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          style: theme.textTheme.bodyMedium,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return null; // Optional field
            }
            final number = allowDecimal
                ? double.tryParse(value)
                : int.tryParse(value);
            if (number == null) {
              return 'Inválido';
            }
            if (number < minValue || number > maxValue) {
              return '$minValue-$maxValue';
            }
            return null;
          },
        ),
      ],
    );
  }
}

/// A specialized field for blood pressure input with systolic/diastolic.
class _BloodPressureField extends StatelessWidget {
  const _BloodPressureField({
    required this.systolicController,
    required this.diastolicController,
  });

  final TextEditingController systolicController;
  final TextEditingController diastolicController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Presión Arterial',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            // Systolic
            Expanded(
              child: TextFormField(
                controller: systolicController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  hintText: '120',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: theme.textTheme.bodyMedium,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final num = int.tryParse(value);
                  if (num == null) return 'Inválido';
                  if (num < 50 || num > 250) return '50-250';
                  return null;
                },
              ),
            ),
            // Separator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '/',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // Diastolic
            Expanded(
              child: TextFormField(
                controller: diastolicController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  hintText: '80',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: theme.textTheme.bodyMedium,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final num = int.tryParse(value);
                  if (num == null) return 'Inválido';
                  if (num < 30 || num > 150) return '30-150';
                  return null;
                },
              ),
            ),
            // Unit label
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'mmHg',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
