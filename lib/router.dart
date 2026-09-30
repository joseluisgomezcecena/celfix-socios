import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/benefits_tab.dart';
import 'screens/change_password_screen.dart';
import 'screens/home_shell.dart';
import 'screens/home_tab.dart';
import 'screens/locations_tab.dart';
import 'screens/login_screen.dart';
import 'screens/profile_form_screen.dart';
import 'screens/promos_tab.dart';
import 'screens/purchase_detail_screen.dart';
import 'screens/purchases_screen.dart';
import 'screens/register_screen.dart';
import 'screens/repair_orders_screen.dart';
import 'screens/splash_screen.dart';
import 'state/auth_provider.dart';

class Routes {
  const Routes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const home = '/inicio';
  static const locations = '/tiendas';
  static const promos = '/promos';
  static const benefits = '/beneficios';
  static const changePassword = '/cambiar-password';
  static const completeProfile = '/completa-tu-perfil';
  static const editProfile = '/mis-datos';
  static const purchases = '/compras';
  static const repairOrders = '/reparaciones';

  static String purchaseDetail(int id) => '/compras/$id';
}

/// Rutas que exigen sesión. Todo lo demás es navegable como invitado.
const _protectedRoutes = {
  Routes.promos,
  Routes.benefits,
  Routes.changePassword,
  Routes.editProfile,
  Routes.purchases,
  Routes.repairOrders,
};

/// Puente entre Riverpod y go_router: cada cambio de AuthState re-evalúa el
/// redirect, así el 401 del interceptor saca al usuario sin navigatorKey global.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (previous, next) => notifyListeners());
  }
}

final _authListenableProvider =
    Provider<_AuthListenable>((ref) => _AuthListenable(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(_authListenableProvider);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final location = state.matchedLocation;

      // Mientras el splash resuelve el token no dejamos entrar a ningún lado.
      if (!auth.isResolved) {
        return location == Routes.splash ? null : Routes.splash;
      }

      final isAuthRoute =
          location == Routes.login || location == Routes.register;

      if (location == Routes.splash) {
        return Routes.home;
      }

      // Modo invitado: solo se bloquean las rutas de datos personales.
      final needsAuth = _protectedRoutes.any((route) => location.startsWith(route)) ||
          location.startsWith('/compras/');
      if (needsAuth && !auth.isAuthenticated) return Routes.login;

      // Ya logueado: no tiene sentido ver login/registro.
      if (isAuthRoute && auth.isAuthenticated) return Routes.home;

      // Perfil incompleto: el backend pide nombre, apellidos y fecha de
      // nacimiento antes de dejar usar el resto de la app.
      final needsProfile = auth.isAuthenticated &&
          auth.customer != null &&
          !auth.customer!.profileComplete;
      if (needsProfile && location != Routes.completeProfile) {
        return Routes.completeProfile;
      }
      if (!needsProfile && location == Routes.completeProfile) {
        return Routes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.completeProfile,
        builder: (context, state) => const ProfileFormScreen(mandatory: true),
      ),
      GoRoute(
        path: Routes.editProfile,
        builder: (context, state) => const ProfileFormScreen(),
      ),
      GoRoute(
        path: Routes.changePassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: Routes.purchases,
        builder: (context, state) => const PurchasesScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => PurchaseDetailScreen(
              purchaseId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.repairOrders,
        builder: (context, state) => const RepairOrdersScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => const HomeTab(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.locations,
              builder: (context, state) => const LocationsTab(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.promos,
              builder: (context, state) => const PromosTab(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.benefits,
              builder: (context, state) => const BenefitsTab(),
            ),
          ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Página no encontrada')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Esta pantalla no existe.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go(Routes.home),
              child: const Text('Ir al inicio'),
            ),
          ],
        ),
      ),
    ),
  );

  // Las pantallas abiertas con push (Compras, Reparaciones, Detalle) no se
  // reflejan en la ubicación del router, así que `redirect` no puede verlas ni
  // desmontarlas. Ante un cambio de sesión limpiamos la pila explícitamente.
  ref.listen(authProvider, (previous, next) {
    if (previous != null && previous.isAuthenticated == next.isAuthenticated) {
      return;
    }
    // Sesión caída por 401: que aterrice en login para leer el aviso.
    final destination = !next.isAuthenticated && next.sessionMessage != null
        ? Routes.login
        : Routes.home;
    router.go(destination);
  });

  return router;
});
