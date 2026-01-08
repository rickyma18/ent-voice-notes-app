import 'package:flutter/material.dart';

import '../../../../../ui/theme/colors.dart';
import '../../../../../ui/theme/radii.dart';
import '../../../../../ui/theme/text_styles.dart';

/// Header widget displaying greeting and brand name with DocSoft symbol
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.greeting,
    required this.brand,
    required this.onProfileTap,
  });

  final String greeting;
  final String brand;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: DocsoftTextStyles.headlineLarge,
              ),
              const SizedBox(height: 2),
              Text(
                brand,
                style: DocsoftTextStyles.subtitle.copyWith(
                  color: DocsoftColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Interactive DocSoft symbol button with accessibility
        Semantics(
          button: true,
          label: 'Menú de perfil',
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(DocsoftRadii.md),
            child: InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(DocsoftRadii.md),
              splashColor: DocsoftColors.primarySoft,
              highlightColor: DocsoftColors.primaryMuted,
              child: Ink(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DocsoftColors.primaryMuted,
                  borderRadius: BorderRadius.circular(DocsoftRadii.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/branding/symbol/docsoft_symbol.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    color: DocsoftColors.primary,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
