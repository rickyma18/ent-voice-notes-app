import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';
import 'radii.dart';
import 'text_styles.dart';

/// Docsoft Theme
/// Centralized theme configuration for the application.
class DocsoftTheme {
  static ThemeData get lightTheme {
    final colorScheme = const ColorScheme(
      brightness: Brightness.light,

      // Brand
      primary: DocsoftColors.primary,
      onPrimary: DocsoftColors.onPrimary,

      secondary: DocsoftColors.primarySoft,
      onSecondary: DocsoftColors.textPrimary,

      // Surfaces
      background: DocsoftColors.background,
      onBackground: DocsoftColors.onBackground,
      surface: DocsoftColors.surface,
      onSurface: DocsoftColors.onSurface,

      // Feedback
      error: DocsoftColors.error,
      onError: DocsoftColors.onError,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      scaffoldBackgroundColor: DocsoftColors.background,
      dividerColor: DocsoftColors.divider,

      // Typography
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        headlineSmall: DocsoftTextStyles.headline,
        titleLarge: DocsoftTextStyles.title,
        titleMedium: DocsoftTextStyles.subtitle,
        bodyMedium: DocsoftTextStyles.body,
        bodySmall: DocsoftTextStyles.caption,
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: DocsoftColors.surface,
        foregroundColor: DocsoftColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: DocsoftTextStyles.title,
        iconTheme: const IconThemeData(color: DocsoftColors.textPrimary),
      ),

      // Cards
      cardTheme: const CardThemeData(
        color: DocsoftColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: DocsoftRadii.card,
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DocsoftColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

        border: OutlineInputBorder(
          borderRadius: DocsoftRadii.input,
          borderSide: const BorderSide(color: DocsoftColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DocsoftRadii.input,
          borderSide: const BorderSide(color: DocsoftColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DocsoftRadii.input,
          borderSide: const BorderSide(
            color: DocsoftColors.inputBorderFocused,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DocsoftRadii.input,
          borderSide: const BorderSide(color: DocsoftColors.inputBorderError),
        ),

        labelStyle: DocsoftTextStyles.caption.copyWith(fontSize: 14),
        hintStyle: DocsoftTextStyles.caption.copyWith(
          color: DocsoftColors.textTertiary,
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DocsoftColors.primary,
          foregroundColor: DocsoftColors.onPrimary,
          elevation: 0,
          textStyle: DocsoftTextStyles.button,
          shape: const RoundedRectangleBorder(
            borderRadius: DocsoftRadii.button,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 48),
          disabledBackgroundColor: DocsoftColors.disabledBackground,
          disabledForegroundColor: DocsoftColors.disabledForeground,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DocsoftColors.primary,
          side: const BorderSide(color: DocsoftColors.primary),
          textStyle: DocsoftTextStyles.button,
          shape: const RoundedRectangleBorder(
            borderRadius: DocsoftRadii.button,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 48),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DocsoftColors.primary,
          overlayColor: DocsoftColors.overlay,
          textStyle: DocsoftTextStyles.button,
          shape: const RoundedRectangleBorder(
            borderRadius: DocsoftRadii.button,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: DocsoftColors.surfaceAlt,
        labelStyle: DocsoftTextStyles.caption,
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DocsoftColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: DocsoftRadii.bottomSheet,
        ),
      ),
    );
  }
}
