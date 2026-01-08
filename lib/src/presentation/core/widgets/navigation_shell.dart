import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/docsoft_bottom_nav.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key, required this.statefulNavigationShell});

  final StatefulNavigationShell statefulNavigationShell;

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.statefulNavigationShell,
      bottomNavigationBar: DocsoftBottomNav(
        currentIndex: widget.statefulNavigationShell.currentIndex,
        onTap: (index) {
          widget.statefulNavigationShell.goBranch(
            index,
            initialLocation:
                index == widget.statefulNavigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
