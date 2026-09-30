import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../state/auth_provider.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/celfix_header.dart';
import '../widgets/celfix_logo.dart';
import '../widgets/membership_card.dart';
import '../widgets/courses_carousel.dart';
import '../widgets/promos_carousel.dart';
import '../widgets/qr_reveal.dart';

/// Pestaña "Inicio": la credencial del socio y su código para caja.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    // En modo invitado no hay credencial que mostrar, pero el resto de las
    // pestañas sigue navegable.
    if (!auth.isAuthenticated) return const _GuestHome();

    final profile = ref.watch(profileProvider);
    final firstName = auth.customer?.name.split(' ').first ?? '';

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(profileProvider.future),
      child: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          children: [
            CelfixHeader(greeting: '¡Hola $firstName!'),
            SizedBox(
              height: 360,
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(profileProvider),
              ),
            ),
          ],
        ),
        data: (customer) => ListView(
          padding: EdgeInsets.zero,
          children: [
            CelfixHeader(
              greeting: '¡Hola ${customer.name.split(' ').first}!',
              overlay: MembershipCard(
                customer: customer,
                backgroundUrl: ref
                    .watch(appDesignsProvider)
                    .value
                    ?.membershipCardBackground,
              ),
              overlayOverflow: 152,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: CelfixShape.pageInset),
              child: MembershipIdentity(
                customer: customer,
                onSeePurchases: () => context.push(Routes.purchases),
                onSeeRepairs: () => context.push(Routes.repairOrders),
              ),
            ),
            const SizedBox(height: 16),
            QrReveal(customer: customer),
            const SizedBox(height: 22),
            PromosCarousel(
              onSeeAll: () => context.go(Routes.promos),
            ),
            const SizedBox(height: 26),
            CoursesCarousel(
              onSeeAll: () => context.push(Routes.courses),
              onTapCourse: (_) => context.push(Routes.courses),
            ),
            if (customer.subscriptionLapsed) ...[
              const SizedBox(height: 16),
              const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: CelfixShape.pageInset),
                child: _LapsedNotice(),
              ),
            ],
            if (auth.usingDefaultPassword) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: CelfixShape.pageInset),
                child: _DefaultPasswordNotice(
                  onChange: () => context.push(Routes.changePassword),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _LapsedNotice extends StatelessWidget {
  const _LapsedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(CelfixShape.cardRadius),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: CelfixColors.danger),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tu suscripción venció. Renuévala en cualquier sucursal para recuperar tus beneficios Premium.',
              style: TextStyle(color: CelfixColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultPasswordNotice extends StatelessWidget {
  final VoidCallback onChange;

  const _DefaultPasswordNotice({required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F5FC),
        borderRadius: BorderRadius.circular(CelfixShape.cardRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: CelfixColors.blue, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Sigues usando la contraseña inicial. Cámbiala para proteger tu cuenta.',
              style: TextStyle(fontSize: 13, color: CelfixColors.ink),
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Cambiar')),
        ],
      ),
    );
  }
}

/// Inicio en modo invitado: se puede ver el contenido público, pero la
/// credencial requiere cuenta.
class _GuestHome extends StatelessWidget {
  const _GuestHome();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const CelfixHeader(greeting: '¡Hola!'),
        const SizedBox(height: 28),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: CelfixShape.pageInset),
          child: Column(
            children: [
              const CelfixLogo(height: 46),
              const SizedBox(height: 20),
              const Text(
                'Tu membresía Celfix',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: CelfixColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Inicia sesión para ver tu código de socio, tus promociones, '
                'beneficios, compras y reparaciones.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CelfixColors.inkSoft, fontSize: 14),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => context.go(Routes.login),
                child: const Text('INICIAR SESIÓN'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(Routes.register),
                child: const Text('Crear cuenta'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
