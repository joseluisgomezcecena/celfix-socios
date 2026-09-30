import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/models/customer.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'celfix_logo.dart';
import 'premium.dart';

/// Tarjeta de membresía, pensada para encimarse al header.
///
/// Es **una sola tarjeta** para socios registrados y premium: el fondo es el
/// mismo para ambos. La única diferencia visual del premium es la pill dorada.
class MembershipCard extends StatelessWidget {
  final Customer customer;

  /// Fondo que el admin sube desde el POS (`membership_card_background`).
  /// Si es null se usa el degradado azul de marca.
  final String? backgroundUrl;

  const MembershipCard({
    super.key,
    required this.customer,
    this.backgroundUrl,
  });

  @override
  Widget build(BuildContext context) {
    final background = backgroundUrl;

    return Container(
      height: 168,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CelfixColors.blue, CelfixColors.blueDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: CelfixColors.blueDeep.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (background != null)
            CachedNetworkImage(
              imageUrl: background,
              fit: BoxFit.cover,
              // Mientras carga (o si falla) se ve el degradado de abajo: la
              // tarjeta nunca queda en blanco.
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          // Velo oscuro: el fondo lo sube el admin y no sabemos qué tan claro
          // será, así que garantizamos contraste para el texto blanco.
          if (background != null)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x73000000), Color(0x33000000)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // El SVG viene en cyan de marca; sobre la tarjeta se
                    // pierde, así que lo pintamos de blanco.
                    const Expanded(
                      // Align: dentro de Expanded el logo se centraría, y el
                      // wordmark va pegado a la izquierda.
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CelfixLogo(height: 30, color: Colors.white),
                      ),
                    ),
                    if (customer.isPremium) const PremiumBadge(),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Text(
                    customer.membershipNo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Membresía',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// QR generado en el cliente a partir del número de membresía.
class QrPanel extends StatelessWidget {
  final Customer customer;

  const QrPanel({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          // Fondo blanco fijo: un QR sobre superficie oscura no lo lee
          // ningún escáner.
          decoration: CelfixShape.cardDecoration(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              QrImageView(
                data: customer.membershipNo,
                version: QrVersions.auto,
                size: 232,
                // Nivel alto de corrección de errores: permite encimar el
                // logo al centro sin que el código deje de leerse.
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
              // Recuadro blanco detrás del isotipo: tapa los módulos del QR
              // de forma limpia. El nivel H de corrección de errores permite
              // esta oclusión sin que el código deje de leerse.
              Container(
                padding: const EdgeInsets.all(6),
                color: Colors.white,
                child: const CelfixMark(size: 36),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'muestra el código al vendedor',
          style: TextStyle(color: CelfixColors.inkSoft, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(
          Fmt.membership(customer.membershipNo),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: CelfixColors.blue,
            letterSpacing: 1.4,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Bloque de identidad debajo de la credencial: nombre, teléfono y vigencia.
class MembershipIdentity extends StatelessWidget {
  final Customer customer;
  final VoidCallback? onSeePurchases;
  final VoidCallback? onSeeRepairs;

  const MembershipIdentity({
    super.key,
    required this.customer,
    this.onSeePurchases,
    this.onSeeRepairs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.name,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: CelfixColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Fmt.phone(customer.mobile),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: CelfixColors.blue,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                customer.hasExpiry
                    ? 'Expira el ${Fmt.longDate(customer.membershipExpiresAt)}'
                    : 'Membresía sin vencimiento',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: CelfixColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (onSeePurchases != null)
              _IdentityLink(label: 'ver compras', onTap: onSeePurchases!),
            if (onSeeRepairs != null)
              _IdentityLink(label: 'reparaciones', onTap: onSeeRepairs!),
          ],
        ),
      ],
    );
  }
}

/// Enlace compacto de la ficha del socio.
class _IdentityLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _IdentityLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      // Icono en vez del carácter "→": Poppins no lo incluye y se renderiza
      // como cuadro vacío.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward, size: 16),
        ],
      ),
    );
  }
}
