import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/text_styles.dart';

/// Docsoft SnackBar Utility
///
/// Design goals:
/// - High contrast against the light teal Docsoft UI
/// - Dark solid backgrounds for success/info (stands out from cards & chips)
/// - Semantic solid colors for warning/error (urgency)
/// - Floating, elevated, impossible to miss
///
/// Advanced usage:
/// - [showCloseIcon]: Adds a close button to the SnackBar (default: null/false)
/// - [messengerOverride]: Use a custom ScaffoldMessengerState instead of
///   ScaffoldMessenger.of(context). Useful for showing SnackBars above
///   BottomSheets or other overlays.
class DocsoftSnackBar {
  // ──────────────────────────────────────────────────────────────────────────
  // Dark-neutral palette (contrasts with the light/teal Docsoft surface)
  // ──────────────────────────────────────────────────────────────────────────
  static const Color _darkSlate = Color(0xFF1E293B); // slate-800
  static const Color _white = Color(0xFFFFFFFF);

  // Semantic solids (slightly rounded to feel softer)
  static const Color _successGreen = Color(0xFF16A34A); // green-600
  static const Color _warningAmber = Color(0xFFF59E0B); // amber-500
  static const Color _errorRed = Color(0xFFDC2626); // red-600
  static const Color _infoPrimary = Color(0xFF1FA39A); // primaryDark

  static void show(
    BuildContext context, {
    required String message,
    required SnackBarType type,

    /// Optional overrides
    Duration? duration,
    SnackBarBehavior? behavior,
    SnackBarAction? action,

    /// If provided, replaces the default message Text.
    /// The widget will still be wrapped with the Docsoft icon + spacing.
    Widget? content,

    /// Defaults to true to avoid stacking / spam.
    bool clearExisting = true,

    /// Show a close icon button on the SnackBar.
    bool? showCloseIcon,

    /// Use a custom ScaffoldMessengerState instead of
    /// ScaffoldMessenger.of(context). Useful for BottomSheet overlays.
    ScaffoldMessengerState? messengerOverride,
  }) {
    final messenger = messengerOverride ?? ScaffoldMessenger.of(context);

    if (clearExisting) {
      messenger.clearSnackBars();
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final style = _styleFor(type);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            // Icon with a subtle circular background for emphasis
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: style.iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, color: style.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:
                  content ??
                  Text(
                    message,
                    style: DocsoftTextStyles.body.copyWith(
                      color: style.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
          ],
        ),
        backgroundColor: style.background,
        behavior: behavior ?? SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: DocsoftRadii.button),
        margin: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        duration: duration ?? _durationFor(type),
        action: action != null
            ? SnackBarAction(
                label: action.label,
                textColor: style.actionColor,
                onPressed: action.onPressed,
              )
            : null,
        showCloseIcon: showCloseIcon ?? false,
        closeIconColor: style.foreground.withOpacity(0.7),
      ),
    );
  }

  static Duration _durationFor(SnackBarType type) {
    switch (type) {
      case SnackBarType.error:
      case SnackBarType.warning:
        return const Duration(seconds: 4);
      case SnackBarType.success:
        return const Duration(seconds: 2);
      case SnackBarType.info:
        return const Duration(seconds: 3);
    }
  }

  static _SnackStyle _styleFor(SnackBarType type) {
    switch (type) {
      // ── Success: dark slate with green accent icon ──────────────────────
      case SnackBarType.success:
        return _SnackStyle(
          background: _darkSlate,
          foreground: _white,
          icon: Icons.check_circle_rounded,
          iconColor: _successGreen,
          iconBackground: _successGreen.withOpacity(0.15),
          actionColor: DocsoftColors.primary,
        );

      // ── Warning: solid amber with dark text ────────────────────────────
      case SnackBarType.warning:
        return _SnackStyle(
          background: _warningAmber,
          foreground: const Color(0xFF1E293B),
          icon: Icons.warning_rounded,
          iconColor: const Color(0xFF92400E), // amber-800
          iconBackground: const Color(0x33FFFFFF), // 20% white
          actionColor: const Color(0xFF78350F),
        );

      // ── Error: solid red with white text ───────────────────────────────
      case SnackBarType.error:
        return _SnackStyle(
          background: _errorRed,
          foreground: _white,
          icon: Icons.error_rounded,
          iconColor: _white,
          iconBackground: const Color(0x33FFFFFF), // 20% white
          actionColor: const Color(0xFFFFE4E6), // rose-100
        );

      // ── Info: dark slate with teal accent icon ─────────────────────────
      case SnackBarType.info:
        return _SnackStyle(
          background: _darkSlate,
          foreground: _white,
          icon: Icons.info_rounded,
          iconColor: _infoPrimary,
          iconBackground: _infoPrimary.withOpacity(0.15),
          actionColor: DocsoftColors.primary,
        );
    }
  }
}

class _SnackStyle {
  final Color background;
  final Color foreground;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color actionColor;

  const _SnackStyle({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.actionColor,
  });
}

enum SnackBarType { success, warning, error, info }
