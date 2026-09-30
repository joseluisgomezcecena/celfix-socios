import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../state/auth_provider.dart';
import '../theme.dart';
import '../widgets/celfix_logo.dart';

/// Índices de las ramas del StatefulShellRoute, en el orden en que están
/// declaradas en el router.
class _Branch {
  const _Branch._();

  static const home = 0;
  static const locations = 1;
  static const promos = 2;
  static const benefits = 3;
}

/// Shell de pestañas. Cada rama conserva su estado de scroll gracias al
/// IndexedStack de StatefulShellRoute.
///
/// Sin sesión solo se ofrecen Inicio y Tiendas: Promos y Beneficios quedan
/// detrás del login.
class HomeShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;

    // Las ramas del router siempre son cuatro; aquí solo elegimos cuáles se
    // muestran, y traducimos el índice visible al índice de la rama real.
    final branches = isAuthenticated
        ? const [
            _Branch.home,
            _Branch.locations,
            _Branch.promos,
            _Branch.benefits,
          ]
        : const [_Branch.home, _Branch.locations];

    final destinations = [
      for (final branch in branches) _destinations[branch]!,
    ];

    // Si el invitado venía de una pestaña ya no visible, marcamos Inicio.
    final currentVisible = branches.indexOf(navigationShell.currentIndex);
    final selectedIndex = currentVisible == -1 ? 0 : currentVisible;

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
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              final branch = branches[index];
              navigationShell.goBranch(
                branch,
                // Tocar la pestaña activa regresa a su raíz.
                initialLocation: branch == navigationShell.currentIndex,
              );
            },
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}

const _destinations = <int, NavigationDestination>{
  _Branch.home: NavigationDestination(
    icon: Icon(Icons.account_circle_outlined),
    label: 'Inicio',
  ),
  _Branch.locations: NavigationDestination(
    icon: Icon(Icons.location_on_outlined),
    label: 'Tiendas',
  ),
  _Branch.promos: NavigationDestination(
    icon: Icon(Icons.local_fire_department_outlined),
    label: 'Promos',
  ),
  _Branch.benefits: NavigationDestination(
    icon: Icon(Icons.workspace_premium_outlined),
    label: 'Beneficios',
  ),
};

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
                      icon: Icons.person_outline,
                      label: 'Mis datos',
                      onTap: () => _go(context, Routes.editProfile),
                    ),
                    _DrawerItem(
                      icon: Icons.school_outlined,
                      label: 'Cursos y talleres',
                      onTap: () => _go(context, Routes.courses),
                    ),
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
                  ] else ...[
                    // Sin sesión el menú refleja lo mismo que la barra de
                    // abajo: nada personal, solo lo público.
                    _DrawerItem(
                      icon: Icons.account_circle_outlined,
                      label: 'Inicio',
                      onTap: () {
                        Navigator.pop(context);
                        context.go(Routes.home);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.location_on_outlined,
                      label: 'Tiendas',
                      onTap: () {
                        Navigator.pop(context);
                        context.go(Routes.locations);
                      },
                    ),
                    const Divider(height: 24),
                    _DrawerItem(
                      icon: Icons.login,
                      label: 'Iniciar sesión',
                      onTap: () {
                        Navigator.pop(context);
                        context.go(Routes.login);
                      },
                    ),
                  ],
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
