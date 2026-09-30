import 'package:flutter/material.dart';

import '../api/models/customer.dart';
import '../theme.dart';
import 'membership_card.dart';

/// El QR arranca oculto y se muestra a petición.
///
/// Es el dato que identifica al socio en caja: mantenerlo tapado evita que se
/// lea de una mirada de reojo o quede expuesto en una captura de pantalla.
class QrReveal extends StatefulWidget {
  final Customer customer;

  const QrReveal({super.key, required this.customer});

  @override
  State<QrReveal> createState() => _QrRevealState();
}

class _QrRevealState extends State<QrReveal> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: _visible
          ? Column(
              children: [
                QrPanel(customer: widget.customer),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => setState(() => _visible = false),
                  icon: const Icon(Icons.visibility_off_outlined, size: 18),
                  label: const Text('Ocultar código'),
                ),
              ],
            )
          : _HiddenQr(onShow: () => setState(() => _visible = true)),
    );
  }
}

/// Estado oculto en una sola fila.
///
/// Va compacto a propósito: si ocupara media pantalla, el carrusel de promos
/// quedaría abajo del doblez y nadie lo vería al entrar.
class _HiddenQr extends StatelessWidget {
  final VoidCallback onShow;

  const _HiddenQr({required this.onShow});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CelfixShape.pageInset),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onShow,
          borderRadius: BorderRadius.circular(CelfixShape.cardRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: CelfixShape.cardDecoration(),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: CelfixColors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_2,
                      size: 24, color: CelfixColors.blue),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'MOSTRAR QR',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CelfixColors.blue,
                          letterSpacing: 0.4,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Tu código está oculto',
                        style: TextStyle(
                            fontSize: 11.5, color: CelfixColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: CelfixColors.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
