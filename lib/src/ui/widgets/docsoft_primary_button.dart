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
    final themedStyle = Theme.of(context).elevatedButtonTheme.style;
    final buttonBase = fullWidth ? double.infinity : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 72;

        final Widget content;
        ButtonStyle? styleOverride;

        if (isLoading) {
          content = const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          );
          if (narrow) {
            styleOverride = themedStyle?.copyWith(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            );
          }
        } else if (narrow && icon != null) {
          content = Icon(icon, size: 20);
          styleOverride = themedStyle?.copyWith(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          );
        } else {
          content = Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );
        }

        final button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: styleOverride ?? themedStyle,
          child: content,
        );

        if (buttonBase != null) {
          return SizedBox(width: buttonBase, child: button);
        }
        return button;
      },
    );
  }
}
