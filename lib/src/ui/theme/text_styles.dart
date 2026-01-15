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

  /// Headline Large: 28px, w700 (Primary greetings / hero text)
  static TextStyle get headlineLarge => _base.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: DocsoftColors.textPrimary,
    letterSpacing: -0.75,
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

  /// Label: 12px, w500 (Medium) - for tags, badges, overlines
  static TextStyle get label => _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: DocsoftColors.textSecondary,
    letterSpacing: 0.5,
  );

  /// Button: 15px, w600 (SemiBold)
  static TextStyle get button => _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// App Bar Title: 18px, w600 (SemiBold) - for transparent/lightweight app bars
  static TextStyle get appBarTitle => _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: DocsoftColors.textPrimary,
    letterSpacing: 0.5,
  );
}
