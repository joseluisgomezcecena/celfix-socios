import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/auth_provider.dart';
import '../theme.dart';

/// Dorado de la marca para todo lo premium (mismo que usa el admin del POS).
const kPremiumGold = Color(0xFFF0AD4E);

/// Matriz de luminancia: convierte a escala de grises conservando el brillo
/// percibido de cada color.
const _grayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// Envuelve contenido exclusivo de suscriptores.
///
/// A los no premium **no** se les oculta: se les muestra en gris con el aviso
/// de suscripción. Es a propósito — es el embudo de conversión, no un filtro.
class PremiumGate extends ConsumerWidget {
  /// Si el item en sí es premium. Un item normal nunca se bloquea.
  final bool isPremiumItem;

  final Widget child;

  const PremiumGate({
    super.key,
    required this.isPremiumItem,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // is_premium del customer lo calcula el servidor; aquí solo lo leemos.
    final userIsPremium = ref.watch(authProvider).customer?.isPremium ?? false;

    if (!isPremiumItem || userIsPremium) return child;

    return Stack(
      children: [
        ColorFiltered(
          colorFilter: _grayscale,
          child: Opacity(opacity: 0.55, child: child),
        ),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CelfixShape.cardRadius),
            child: Container(
              alignment: Alignment.center,
              color: Colors.black.withValues(alpha: 0.10),
              padding: const EdgeInsets.all(12),
              child: const _SubscribeCallout(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubscribeCallout extends StatelessWidget {
  const _SubscribeCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kPremiumGold,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 16, color: Colors.white),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Paga tu suscripción para acceder',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Distintivo dorado de socio Premium.
///
/// Es la ÚNICA diferencia visual de la tarjeta de membresía entre un socio
/// premium y uno registrado: la tarjeta es la misma para ambos.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kPremiumGold,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Premium',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
