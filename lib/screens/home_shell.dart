import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../state/auth_provider.dart';
import '../theme.dart';
import '../widgets/celfix_logo.dart';

/// Shell de 4 pestañas. Cada rama conserva su estado de scroll gracias al
/// IndexedStack de StatefulShellRoute.
class HomeShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShell({super.key, required this.navigationShell});

  void _onTap(int index) => navigationShell.goBranch(
        index,
        // Tocar la pestaña activa regresa a su raíz.
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      drawer: const _CelfixDrawer(),
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: CelfixColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.account_circle_outlined),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.location_on_outlined),
                label: 'Tiendas',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_fire_department_outlined),
                label: 'Promos',
              ),
              NavigationDestination(
                icon: Icon(Icons.workspace_premium_outlined),
                label: 'Beneficios',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CelfixDrawer extends ConsumerWidget {
  const _CelfixDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final customer = auth.customer;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [CelfixColors.cyan, CelfixColors.cyanDark],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CelfixLogo(height: 28, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(
                    customer?.name ?? 'Socios',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (auth.isAuthenticated) ...[
                    _DrawerItem(
                      icon: Icons.receipt_long_outlined,
                      label: 'Mis compras',
                      onTap: () => _go(context, Routes.purchases),
                    ),
                    _DrawerItem(
                      icon: Icons.build_outlined,
                      label: 'Mis reparaciones',
                      onTap: () => _go(context, Routes.repairOrders),
                    ),
                    _DrawerItem(
                      icon: Icons.lock_outline,
                      label: 'Cambiar contraseña',
                      onTap: () => _go(context, Routes.changePassword),
                    ),
                    const Divider(height: 24),
                    _DrawerItem(
                      icon: Icons.logout,
                      label: 'Cerrar sesión',
                      onTap: () async {
                        Navigator.pop(context);
                        await ref.read(authProvider.notifier).logout();
                      },
                    ),
                  ] else
                    _DrawerItem(
                      icon: Icons.login,
                      label: 'Iniciar sesión',
                      onTap: () {
                        Navigator.pop(context);
                        context.go(Routes.login);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    context.push(route);
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: CelfixColors.blue),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: CelfixColors.ink,
        ),
      ),
      onTap: onTap,
    );
  }
}
