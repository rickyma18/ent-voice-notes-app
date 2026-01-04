import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';
import 'radii.dart';
import 'text_styles.dart';

/// Docsoft Theme
/// Centralized theme configuration for the application.
class DocsoftTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      
      // Colors
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: DocsoftColors.primary,
        onPrimary: Colors.white,
        secondary: DocsoftColors.primary, // Using primary as secondary for now to keep it consistent
        onSecondary: Colors.white,
        error: DocsoftColors.error,
        onError: Colors.white,
        surface: DocsoftColors.surface,
        onSurface: DocsoftColors.textPrimary,
      ),
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
        surfaceTintColor: Colors.transparent, // Disable M3 tint
        elevation: 1, // Sutil shadow
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: DocsoftRadii.card,
        ),
      ),
      
      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DocsoftColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: DocsoftRadii.input,
          borderSide: const BorderSide(color: DocsoftColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DocsoftRadii.input,
          borderSide: const BorderSide(color: DocsoftColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DocsoftRadii.input,
          borderSide: const BorderSide(color: DocsoftColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DocsoftRadii.input,
          borderSide: const BorderSide(color: DocsoftColors.error),
        ),
        labelStyle: DocsoftTextStyles.caption.copyWith(fontSize: 14),
        hintStyle: DocsoftTextStyles.caption,
      ),
      
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DocsoftColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: DocsoftTextStyles.button,
          shape: const RoundedRectangleBorder(borderRadius: DocsoftRadii.button),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 48),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DocsoftColors.primary,
          side: const BorderSide(color: DocsoftColors.primary),
          textStyle: DocsoftTextStyles.button,
          shape: const RoundedRectangleBorder(borderRadius: DocsoftRadii.button),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 48),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DocsoftColors.primary,
          textStyle: DocsoftTextStyles.button,
          shape: const RoundedRectangleBorder(borderRadius: DocsoftRadii.button),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: DocsoftColors.background,
        labelStyle: DocsoftTextStyles.caption,
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DocsoftColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: DocsoftRadii.bottomSheet),
      ),
    );
  }
}
