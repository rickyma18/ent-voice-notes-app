import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Input
/// Standardized text input with label above and helper text below.
class DocsoftInput extends StatelessWidget {
  const DocsoftInput({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
    this.validator,
    this.suffixIcon,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final Widget? suffixIcon;
  final Widget? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Text(
          label,
          style: DocsoftTextStyles.subtitle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: DocsoftColors.textPrimary,
          ),
        ),
        const SizedBox(height: DocsoftSpacing.sm),
        
        // Input Field
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: maxLines,
          minLines: minLines,
          obscureText: obscureText,
          enabled: enabled,
          onChanged: onChanged,
          validator: validator,
          style: DocsoftTextStyles.body,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: helperText, // Helper text inside standard decoration
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
          ),
        ),
      ],
    );
  }
}
