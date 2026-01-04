import 'package:flutter/material.dart';

/// Docsoft Design System Colors
/// Source of truth for all application colors.
abstract class DocsoftColors {
  // Brand
  static const Color primary = Color(0xFF2EC4B6);
  static const Color primaryDark = Color(0xFF1FA39A);
  
  // Backgrounds
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  
  // UI Elements
  static const Color divider = Color(0xFFE5E7EB);
  
  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  
  // Feedback
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Gradient (Restricted use)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
