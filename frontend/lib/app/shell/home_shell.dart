import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flowers/core/widgets/gradient_background.dart';
import 'package:flowers/core/widgets/responsive.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations =
      <({IconData icon, IconData selected, String label})>[
    (
      icon: Icons.menu_book_outlined,
      selected: Icons.menu_book,
      label: 'Каталог',
    ),
    (
      icon: Icons.local_shipping_outlined,
      selected: Icons.local_shipping,
      label: 'Закупки',
    ),
    (
      icon: Icons.inventory_2_outlined,
      selected: Icons.inventory_2,
      label: 'Склад',
    ),
    (
      icon: Icons.point_of_sale_outlined,
      selected: Icons.point_of_sale,
      label: 'Касса',
    ),
    (
      icon: Icons.more_horiz,
      selected: Icons.more_horiz,
      label: 'Ещё',
    ),
  ];

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= Breakpoints.tablet;

    if (useRail) {
      final extended = width >= Breakpoints.desktop;
      return GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: AppColors.outline),
                    boxShadow: softShadow(opacity: 0.10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    child: NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: _goBranch,
                      extended: extended,
                      backgroundColor: Colors.white,
                      labelType: extended
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      destinations: [
                        for (final d in _destinations)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selected),
                            label: Text(d.label),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      );
    }

    final compact = width < 420;
    final sidePad = compact ? 10.0 : 16.0;
    final bottomPad = 12.0 + MediaQuery.paddingOf(context).bottom;
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: navigationShell,
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(sidePad, 0, sidePad, bottomPad),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.outline),
              boxShadow: softShadow(opacity: 0.12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: NavigationBar(
                height: compact ? 76 : 74,
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _goBranch,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selected),
                      label: d.label,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
