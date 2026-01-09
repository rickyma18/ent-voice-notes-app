import 'package:flutter/material.dart';

import '../../ui/theme/colors.dart';

class DocsoftBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const DocsoftBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const double _radius = 24.0;

  @override
  Widget build(BuildContext context) {
    final selected = DocsoftColors.primary;
    final unselected = DocsoftColors.textTertiary; // gris suave de tu DS

    return Container(
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(_radius),
          topRight: Radius.circular(_radius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(_radius),
          topRight: Radius.circular(_radius),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          backgroundColor: DocsoftColors.surface,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: selected,
          unselectedItemColor: unselected,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          showUnselectedLabels: true,
          items: [
            _item(
              label: 'Inicio',
              icon: Icons.home_outlined,
              isActive: currentIndex == 0,
            ),
            _item(
              label: 'Pacientes',
              icon: Icons.person_outline,
              isActive: currentIndex == 1,
            ),
            _item(
              label: 'Notas',
              icon: Icons.note_outlined,
              isActive: currentIndex == 2,
            ),
            _item(
              label: 'Perfil',
              icon: Icons.account_circle_outlined,
              isActive: currentIndex == 3,
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _item({
    required String label,
    required IconData icon,
    required bool isActive,
  }) {
    // Mantenemos icono outlined siempre (look médico limpio)
    // y el estado activo lo marcamos con un pequeño “pill” arriba.
    return BottomNavigationBarItem(
      label: label,
      icon: _NavIcon(icon: icon, isActive: isActive),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.isActive});

  final IconData icon;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? DocsoftColors.primary : DocsoftColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 3,
            width: isActive ? 18 : 0,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: DocsoftColors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Icon(icon, size: 22, color: color),
        ],
      ),
    );
  }
}
