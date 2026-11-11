import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
import 'package:flowers/app/shell/home_shell.dart';

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
      appBar: AppBar(title: const Text('Ещё')),
      body: ListView(
        children: [
          for (final item in items)
            ListTile(
              leading: Icon(item.$3),
              title: Text(item.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(item.$1),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Выйти'),
            onTap: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
    );
  }
}
