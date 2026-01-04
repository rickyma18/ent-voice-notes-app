import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Docsoft Design System Typography
/// Font family: Inter
abstract class DocsoftTextStyles {
  // Base style with Inter
  static TextStyle get _base => GoogleFonts.inter();

  /// Headline: 24px, w600 (SemiBold)
  static TextStyle get headline => _base.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: DocsoftColors.textPrimary,
    letterSpacing: -0.5,
  );

  /// Title: 20px, w600 (SemiBold)
  static TextStyle get title => _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: DocsoftColors.textPrimary,
    letterSpacing: -0.25,
  );

  /// Subtitle: 16px, w500 (Medium)
  static TextStyle get subtitle => _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: DocsoftColors.textPrimary,
  );

  /// Body: 15px, w400 (Regular)
  static TextStyle get body => _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: DocsoftColors.textPrimary,
    height: 1.5,
  );

  /// Caption: 13px, w400 (Regular)
  static TextStyle get caption => _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: DocsoftColors.textSecondary,
  );
  
  /// Button: 15px, w600 (SemiBold)
  static TextStyle get button => _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}
