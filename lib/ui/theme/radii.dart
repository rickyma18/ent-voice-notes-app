import 'package:flutter/material.dart';

/// Docsoft Design System Radii
/// Consistent border radius values.
abstract class DocsoftRadii {
  // Raw values
  static const double cardRadiusValue = 20.0;
  static const double inputRadiusValue = 14.0;
  static const double buttonRadiusValue = 16.0;
  static const double bottomSheetRadiusValue = 24.0;

  // BorderRadius objects
  
  /// Card Radius: 20.0
  static const BorderRadius card = BorderRadius.all(Radius.circular(cardRadiusValue));
  
  /// Input Radius: 14.0
  static const BorderRadius input = BorderRadius.all(Radius.circular(inputRadiusValue));
  
  /// Button Radius: 16.0
  static const BorderRadius button = BorderRadius.all(Radius.circular(buttonRadiusValue));
  
  /// BottomSheet Radius: 24.0 (Top only)
  static const BorderRadius bottomSheet = BorderRadius.vertical(top: Radius.circular(bottomSheetRadiusValue));
}
