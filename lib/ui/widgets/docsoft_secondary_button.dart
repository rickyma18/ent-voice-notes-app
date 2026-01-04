import 'package:flutter/material.dart';

/// Docsoft Secondary Button
/// Secondary action button (Ghost/Text button style).
/// Styles are derived from DocsoftTheme (TextButtonTheme).
class DocsoftSecondaryButton extends StatelessWidget {
  const DocsoftSecondaryButton({
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
                child: CircularProgressIndicator(strokeWidth: 2),
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

    final widget = TextButton(
      onPressed: isLoading ? null : onPressed,
      child: buttonContent,
    );
    
    if (fullWidth) {
      return SizedBox(width: double.infinity, child: widget);
    }
    return widget;
  }
}
