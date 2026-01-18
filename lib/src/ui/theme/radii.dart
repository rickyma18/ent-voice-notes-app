import 'package:flutter/material.dart';

/// Docsoft Design System Radii
/// Consistent border radius values.
abstract class DocsoftRadii {
  // ────────────────────────────────────────────────────────────────────────────
  // Raw Values (use with BorderRadius.circular())
  // ────────────────────────────────────────────────────────────────────────────

  /// Extra small: 4.0
  static const double xs = 4.0;

  /// Small: 8.0
  static const double sm = 8.0;

  /// Medium: 12.0
  static const double md = 12.0;

  /// Large: 16.0
  static const double lg = 16.0;

  /// Extra large: 20.0
  static const double xl = 20.0;

  /// 2x Extra large: 24.0
  static const double xxl = 24.0;

  /// Full (pill shape): 9999.0
  static const double full = 9999.0;

  // ────────────────────────────────────────────────────────────────────────────
  // Semantic Values
  // ────────────────────────────────────────────────────────────────────────────
  static const double cardRadiusValue = 20.0;
  static const double inputRadiusValue = 14.0;
  static const double buttonRadiusValue = 16.0;
  static const double bottomSheetRadiusValue = 24.0;

  // ────────────────────────────────────────────────────────────────────────────
  // BorderRadius Objects
  // ────────────────────────────────────────────────────────────────────────────

  /// Card Radius: 20.0
  static const BorderRadius card = BorderRadius.all(
    Radius.circular(cardRadiusValue),
  );

  /// Input Radius: 14.0
  static const BorderRadius input = BorderRadius.all(
    Radius.circular(inputRadiusValue),
  );

  /// Button Radius: 16.0
  static const BorderRadius button = BorderRadius.all(
    Radius.circular(buttonRadiusValue),
  );

  /// BottomSheet Radius: 24.0 (Top only)
  static const BorderRadius bottomSheet = BorderRadius.vertical(
    top: Radius.circular(bottomSheetRadiusValue),
  );
}
