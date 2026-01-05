import 'package:flutter/material.dart';

/// Docsoft Design System Colors
/// Source of truth for all application colors.
///
/// Principles:
/// - Prefer semantic tokens (what it's used for) over raw palettes.
/// - Keep it small, predictable, and consistent.
/// - Avoid hardcoding withOpacity all over the UI; provide tokens instead.
abstract class DocsoftColors {
  // ────────────────────────────────────────────────────────────────────────────
  // Brand
  // ────────────────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2EC4B6);
  static const Color primaryDark = Color(0xFF1FA39A);

  /// Foreground that sits on primary surfaces (buttons, app bars, etc.)
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Brand tones (use for subtle highlights, charts, waveforms, selection states)
  /// 10% / 20% / 35% alpha variants of primary
  static const Color primaryMuted = Color(0x1A2EC4B6); // 10%
  static const Color primarySoft = Color(0x332EC4B6);  // 20%
  static const Color primaryTint = Color(0x592EC4B6);  // 35%

  /// Optional accent for links / emphasis (kept aligned with brand)
  static const Color link = primaryDark;

  // ────────────────────────────────────────────────────────────────────────────
  // Backgrounds & Surfaces
  // ────────────────────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);

  /// Secondary surfaces (cards-in-cards, sheets, subtle panels)
  static const Color surfaceAlt = Color(0xFFF1F5F9);

  /// Foreground on background/surface
  static const Color onBackground = Color(0xFF0F172A);
  static const Color onSurface = Color(0xFF0F172A);

  // ────────────────────────────────────────────────────────────────────────────
  // Text
  // ────────────────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  /// Placeholders, helper text, less important labels
  static const Color textTertiary = Color(0xFF94A3B8);

  /// Text displayed on dark/brand backgrounds when needed
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ────────────────────────────────────────────────────────────────────────────
  // UI Elements (borders, dividers, focus rings)
  // ────────────────────────────────────────────────────────────────────────────
  static const Color divider = Color(0xFFE5E7EB);

  /// Default border (inputs, cards)
  static const Color border = Color(0xFFE2E8F0);

  /// Subtle border (cards, containers)
  static const Color borderSubtle = Color(0xFFF1F5F9);

  /// Focus ring (inputs, accessibility focus)
  static const Color focus = primary;

  /// Disabled content (icons/text)
  static const Color disabledForeground = Color(0xFF94A3B8);

  /// Disabled surfaces (buttons, inputs background)
  static const Color disabledBackground = Color(0xFFE2E8F0);

  // ────────────────────────────────────────────────────────────────────────────
  // Overlays & Shadows
  // ────────────────────────────────────────────────────────────────────────────
  /// Typical modal barrier / scrim
  static const Color scrim = Color(0x99000000); // 60% black

  /// Subtle overlay for pressed/hover states (on light surfaces)
  static const Color overlay = Color(0x140F172A); // ~8% of textPrimary

  /// Subtle overlay for pressed states on primary
  static const Color overlayOnPrimary = Color(0x1AFFFFFF); // 10% white

  // ────────────────────────────────────────────────────────────────────────────
  // Feedback (semantic)
  // ────────────────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  /// Foregrounds for badges/snackbars if needed
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color onWarning = Color(0xFF0F172A);
  static const Color onError = Color(0xFFFFFFFF);

  /// Soft backgrounds for banners/chips
  static const Color successSoft = Color(0x1A22C55E); // 10%
  static const Color warningSoft = Color(0x1AF59E0B); // 10%
  static const Color errorSoft = Color(0x1AEF4444);   // 10%

  // ────────────────────────────────────────────────────────────────────────────
  // Inputs
  // ────────────────────────────────────────────────────────────────────────────
  static const Color inputBackground = surface;
  static const Color inputBorder = border;
  static const Color inputBorderFocused = primary;
  static const Color inputBorderError = error;

  // ────────────────────────────────────────────────────────────────────────────
  // Gradients (restricted use)
  // ────────────────────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient subtleBackgroundGradient = LinearGradient(
    colors: [
      Color(0xFFF8FAFC),
      Color(0xFFF1F5F9),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
