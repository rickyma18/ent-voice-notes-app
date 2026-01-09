import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Input
/// Standardized text input with label above and helper text below.
///
/// Supports validation via [validator] and input formatting via [inputFormatters].
/// Use with core/utility/validation for centralized validation rules.
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
    this.maxLength,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.inputFormatters,
    this.autovalidateMode,
    this.suffixIcon,
    this.prefixIcon,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
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
  final int? maxLength;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;

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
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          maxLengthEnforcement: maxLength != null
              ? MaxLengthEnforcement.enforced
              : null,
          obscureText: obscureText,
          enabled: enabled,
          autofocus: autofocus,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          inputFormatters: inputFormatters,
          autovalidateMode: autovalidateMode,
          style: DocsoftTextStyles.body,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: helperText,
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
            counterText: '', // Hide character counter (optional)
          ),
        ),
      ],
    );
  }
}
