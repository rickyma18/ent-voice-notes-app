import 'package:flutter/material.dart';
import '../../docsoft_ui.dart';

class DocsoftProfileHeader extends StatelessWidget {
  const DocsoftProfileHeader({
    super.key,
    this.title,
    this.height = 180.0,
    this.showTitle = false,
  });

  final String? title;
  final double height;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [DocsoftColors.primary, DocsoftColors.primaryDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(DocsoftRadii.xxl), // <- 30
          bottomRight: Radius.circular(DocsoftRadii.xxl), // <- 30
        ),
      ),
      child: SafeArea(
        child: showTitle && title != null
            ? Column(
                children: [
                  const SizedBox(height: DocsoftSpacing.md),
                  Text(
                    title!,
                    style: DocsoftTextStyles.appBarTitle.copyWith(
                      color: DocsoftColors.onPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
