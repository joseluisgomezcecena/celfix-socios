import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/models/customer.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'celfix_logo.dart';

/// Tarjeta azul con el número de membresía, pensada para encimarse al header.
class MembershipCard extends StatelessWidget {
  final Customer customer;

  const MembershipCard({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      padding: const EdgeInsets.all(22),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El SVG viene en cyan de marca; sobre el azul de la tarjeta se
          // pierde, así que lo pintamos de blanco.
          const CelfixLogo(height: 30, color: Colors.white),
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
