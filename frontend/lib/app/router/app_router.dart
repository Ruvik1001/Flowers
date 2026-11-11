import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flowers/app/shell/home_shell.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/features/admin/presentation/pages/admin_page.dart';
import 'package:flowers/features/analytics/presentation/pages/analytics_page.dart';
import 'package:flowers/features/assembly/presentation/pages/assembly_page.dart';
import 'package:flowers/features/audit/presentation/pages/audit_page.dart';
import 'package:flowers/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowers/features/auth/presentation/cubit/auth_state.dart';
import 'package:flowers/features/auth/presentation/pages/login_page.dart';
import 'package:flowers/features/cashier/presentation/pages/cashier_page.dart';
import 'package:flowers/features/catalog/presentation/pages/catalog_page.dart';
import 'package:flowers/features/inventory/presentation/pages/inventory_page.dart';
import 'package:flowers/features/procurement/presentation/pages/procurement_page.dart';
import 'package:flowers/features/sales/presentation/pages/sales_page.dart';

class AuthRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

GoRouter createRouter({
  required AuthCubit authCubit,
  required AuthRefresh refresh,
}) {
  return GoRouter(
    initialLocation: '/catalog',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = authCubit.state;
      final loggingIn = state.matchedLocation == '/login';
      if (auth is AuthUnknown) return null;
      if (auth is Unauthenticated || auth is AuthFailure) {
        return loggingIn ? null : '/login';
      }
      if (auth is Authenticated && loggingIn) return '/catalog';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/catalog', builder: (_, __) => const CatalogPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/procurement',
              builder: (_, __) => const ProcurementPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/inventory',
              builder: (_, __) => const InventoryPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/sales', builder: (_, __) => const SalesPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/more', builder: (_, __) => const MoreHubPage()),
          ]),
        ],
      ),
      GoRoute(path: '/cashier', builder: (_, __) => const CashierPage()),
      GoRoute(path: '/assembly', builder: (_, __) => const AssemblyPage()),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsPage()),
      GoRoute(path: '/audit', builder: (_, __) => const AuditPage()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminPage()),
    ],
  );
}

class MoreHubPage extends StatelessWidget {
  const MoreHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, IconData)>[
      ('/cashier', 'Касса', Icons.point_of_sale_outlined),
      ('/assembly', 'Сборка', Icons.local_florist_outlined),
      ('/analytics', 'Аналитика', Icons.insights_outlined),
      ('/audit', 'Аудит', Icons.history_outlined),
      ('/admin', 'Админ', Icons.admin_panel_settings_outlined),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Ещё')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          for (final item in items)
            EntityListTile(
              leading: _MoreIcon(icon: item.$3),
              title: Text(item.$2),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.muted,
              ),
              onTap: () => context.push(item.$1),
            ),
          const SizedBox(height: 8),
          EntityListTile(
            leading: _MoreIcon(
              icon: Icons.logout,
              color: const Color(0xFFB3261E),
              background: const Color(0xFFB3261E).withValues(alpha: 0.10),
            ),
            title: const Text('Выйти'),
            onTap: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
    );
  }
}

class _MoreIcon extends StatelessWidget {
  const _MoreIcon({
    required this.icon,
    this.color = AppColors.leaf,
    this.background,
  });

  final IconData icon;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background ?? AppColors.mist,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
