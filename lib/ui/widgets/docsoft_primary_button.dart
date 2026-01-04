import 'package:flutter/material.dart';

/// Docsoft Primary Button
/// Standard primary action button.
/// Styles are derived from DocsoftTheme (ElevatedButtonTheme).
class DocsoftPrimaryButton extends StatelessWidget {
  const DocsoftPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final Widget buttonContent = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final widget = icon != null && !isLoading
        ? ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: buttonContent,
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: buttonContent,
          );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: widget);
    }
    return widget;
  }
}
