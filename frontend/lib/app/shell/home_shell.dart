import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flowers/core/widgets/gradient_background.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
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
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: 'Каталог',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.local_shipping_outlined),
                    selectedIcon: Icon(Icons.local_shipping),
                    label: 'Закупки',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2),
                    label: 'Склад',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.shopping_bag_outlined),
                    selectedIcon: Icon(Icons.shopping_bag),
                    label: 'Продажи',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz),
                    selectedIcon: Icon(Icons.more_horiz),
                    label: 'Ещё',
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
