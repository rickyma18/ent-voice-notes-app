import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../ui/docsoft_ui.dart';
import '../../../../../core/extensions/app_localization.dart';
import '../../../../../core/gen/l10n/app_localizations.dart';
import '../../../../core/application_state/localization_provider/localization_provider.dart';

/// Premium language switcher widget styled as a pill/chip.
///
/// Features:
/// - Soft surface background with subtle border
/// - Elegant shadow for depth
/// - Globe icon with brand color
/// - Smooth chevron indicator
/// - RTL-aware layout
/// - Accessible tap targets
class LanguageSwitcherWidget extends ConsumerWidget {
  const LanguageSwitcherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localizationProvider);
    final notifier = ref.read(localizationProvider.notifier);

    return PopupMenuButton<Locale>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DocsoftRadii.md),
      ),
      color: DocsoftColors.surface,
      elevation: 8,
      shadowColor: DocsoftColors.textPrimary.withValues(alpha: 0.08),
      onSelected: notifier.changeLocale,
      itemBuilder: (context) => _buildMenuItems(context, currentLocale),
      child: _buildPillButton(context, currentLocale),
    );
  }

  Widget _buildPillButton(BuildContext context, Locale currentLocale) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.md,
        vertical: DocsoftSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: BorderRadius.circular(DocsoftRadii.full),
        border: Border.all(
          color: DocsoftColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: DocsoftColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Globe icon
          const Icon(
            Icons.language_rounded,
            size: 18,
            color: DocsoftColors.primary,
          ),
          const SizedBox(width: DocsoftSpacing.sm),

          // Current language name
          Text(
            context.locale.getLanguageName(currentLocale.languageCode),
            style: DocsoftTextStyles.caption.copyWith(
              color: DocsoftColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: DocsoftSpacing.xs),

          // Chevron indicator
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: DocsoftColors.textSecondary,
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<Locale>> _buildMenuItems(
    BuildContext context,
    Locale currentLocale,
  ) {
    return AppLocalizations.supportedLocales.map((locale) {
      final isSelected = locale == currentLocale;

      return PopupMenuItem<Locale>(
        value: locale,
        padding: const EdgeInsets.symmetric(
          horizontal: DocsoftSpacing.md,
          vertical: DocsoftSpacing.sm,
        ),
        child: Row(
          children: [
            // Language name
            Expanded(
              child: Text(
                context.locale.getLanguageName(locale.languageCode),
                style: DocsoftTextStyles.body.copyWith(
                  color: isSelected
                      ? DocsoftColors.primary
                      : DocsoftColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),

            // Check indicator for selected
            if (isSelected) ...[
              const SizedBox(width: DocsoftSpacing.sm),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: DocsoftColors.primaryMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: DocsoftColors.primary,
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }
}
