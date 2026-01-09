import 'package:flutter/material.dart';
import '../../../../ui/docsoft_ui.dart';

/// New Patient Page - Dumb UI
///
/// A stateless presentation component for creating a new patient.
/// All logic is handled externally via callbacks.
/// Uses DocSoft UI kit exclusively - no hardcoded styles.
class NewPatientPage extends StatelessWidget {
  const NewPatientPage({
    super.key,
    required this.nameController,
    required this.ageController,
    required this.phoneController,
    required this.selectedGender,
    required this.onBack,
    required this.onSave,
    required this.onSelectGender,
    this.isSaving = false,
    this.decorationAssetPath =
        'assets/branding/states/docsoft_patient_profile.png',
  });

  /// Controller for full name input
  final TextEditingController nameController;

  /// Controller for age input
  final TextEditingController ageController;

  /// Controller for phone input (optional)
  final TextEditingController phoneController;

  /// Currently selected gender value
  final String selectedGender;

  /// Callback when back button is pressed
  final VoidCallback onBack;

  /// Callback when save button is pressed
  final VoidCallback onSave;

  /// Callback when gender selector is tapped
  final VoidCallback onSelectGender;

  /// Whether save action is in progress
  final bool isSaving;

  /// Path to decoration image asset
  final String decorationAssetPath;

  // Layout constants
  static const double _headerHeight = 200.0;

  static const double _cardOverlap = 24.0;

  static const double _spaceBetweenCardAndBanner =
      DocsoftSpacing.xl + DocsoftSpacing.lg; // 56px

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header + Overlapping Card (wrapped in SizedBox for hit-testing)
            SizedBox(
              height: _headerHeight + _getCardContentHeight() - _cardOverlap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Illustrated Header
                  DocsoftIllustratedHeader(
                    title: 'Nuevo\npaciente',
                    height: _headerHeight,
                    onBack: onBack,
                    decorationAssetPath: decorationAssetPath,
                    decorationOpacity: 0.5,
                  ),

                  // 2. Form Card (floating with overlap)
                  Positioned(
                    top: _headerHeight - _cardOverlap,
                    left: DocsoftSpacing.screenPadding,
                    right: DocsoftSpacing.screenPadding,
                    child: DocsoftCard(
                      padding: const EdgeInsets.all(DocsoftSpacing.lg),
                      child: Column(
                        children: [
                          // Full Name
                          DocsoftInput(
                            controller: nameController,
                            label: 'Nombre completo',
                            hint: 'Ingresa el nombre del paciente',
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              color: DocsoftColors.primary,
                            ),
                            textInputAction: TextInputAction.next,
                          ),

                          const SizedBox(height: DocsoftSpacing.lg),

                          // Age
                          DocsoftInput(
                            controller: ageController,
                            label: 'Edad',
                            hint: 'Ej: 35',
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(
                              Icons.cake_outlined,
                              color: DocsoftColors.primary,
                            ),
                            textInputAction: TextInputAction.next,
                          ),

                          const SizedBox(height: DocsoftSpacing.lg),

                          // Gender (selector)
                          DocsoftSelectInput(
                            label: 'Sexo',
                            value: selectedGender,
                            hint: 'Selecciona el sexo',
                            leadingIcon: Icons.wc_outlined,
                            onTap: onSelectGender,
                          ),

                          const SizedBox(height: DocsoftSpacing.lg),

                          // Phone (optional)
                          DocsoftInput(
                            controller: phoneController,
                            label: 'Teléfono (opcional)',
                            hint: 'Ej: +52 555 123 4567',
                            keyboardType: TextInputType.phone,
                            prefixIcon: const Icon(
                              Icons.phone_outlined,
                              color: DocsoftColors.primary,
                            ),
                            textInputAction: TextInputAction.done,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Spacing before banner
            const SizedBox(height: _spaceBetweenCardAndBanner),

            // 3. Info Banner
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.screenPadding,
              ),
              child: const DocsoftInfoBanner(
                text:
                    'El paciente será asignado automáticamente al doctor actual.',
                icon: Icons.info_outline,
              ),
            ),

            const SizedBox(height: DocsoftSpacing.xl),

            // 4. Save Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.screenPadding,
              ),
              child: DocsoftPrimaryButton(
                label: 'Guardar paciente',
                onPressed: isSaving ? null : onSave,
                isLoading: isSaving,
                fullWidth: true,
              ),
            ),

            // Bottom safe area padding
            SizedBox(
              height: DocsoftSpacing.xl + MediaQuery.of(context).padding.bottom,
            ),
          ],
        ),
      ),
    );
  }

  /// Calculate the card content height for hit-testing bounds.
  static double _getCardContentHeight() {
    // Approximate card height: 4 inputs + spacing + padding
    const inputHeight = 70.0;
    const numberOfInputs = 4;
    const totalSpacing = DocsoftSpacing.lg * 3; // 3 gaps
    const cardPadding = DocsoftSpacing.lg * 2; // top + bottom

    return (inputHeight * numberOfInputs) + totalSpacing + cardPadding;
  }
}
