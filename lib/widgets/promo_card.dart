import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/models/promo.dart';
import '../theme.dart';
import 'celfix_logo.dart';

class PromoCard extends StatelessWidget {
  final Promo promo;

  const PromoCard({super.key, required this.promo});

  static final _day = DateFormat('d', 'es_MX');
  static final _month = DateFormat('MMMM', 'es_MX');
  static final _year = DateFormat('y', 'es_MX');

  /// "Del 22 de Junio al 30 de Julio del 2026", con los números en negritas
  /// como en el diseño.
  Widget? _validity(BuildContext context) {
    final start = promo.startsAt;
    final end = promo.endsAt;
    if (end == null) return null;

    const soft = TextStyle(fontSize: 12.5, color: CelfixColors.inkSoft);
    const strong = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: CelfixColors.ink,
    );

    String capitalize(String value) =>
        value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

    // Text.rich (y no RichText) para que herede la tipografía del tema:
    // RichText no se fusiona con DefaultTextStyle y perdía Poppins.
    return Text.rich(
      TextSpan(
        style: soft,
        children: [
          if (start != null) ...[
            const TextSpan(text: 'Del '),
            TextSpan(text: _day.format(start), style: strong),
            const TextSpan(text: ' de '),
            TextSpan(text: capitalize(_month.format(start)), style: strong),
            const TextSpan(text: ' al '),
          ] else
            const TextSpan(text: 'Vigente hasta el '),
          TextSpan(text: _day.format(end), style: strong),
          const TextSpan(text: ' de '),
          TextSpan(text: capitalize(_month.format(end)), style: strong),
          const TextSpan(text: ' del '),
          TextSpan(text: _year.format(end), style: strong),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validity = _validity(context);

    return Container(
      decoration: CelfixShape.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (promo.imageUrl != null)
            CachedNetworkImage(
              imageUrl: promo.imageUrl!,
              height: 180,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 180,
                color: CelfixColors.blue.withValues(alpha: 0.08),
              ),
              // Si la imagen no carga caemos al bloque azul con el texto, que
              // sigue comunicando la promo.
              errorWidget: (context, url, error) => _TitleBlock(promo: promo),
            )
          else
            _TitleBlock(promo: promo),
          if (validity != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: validity,
            ),
        ],
      ),
    );
  }
}

/// Bloque azul con el título de la promo, para cuando no hay imagen.
class _TitleBlock extends StatelessWidget {
  final Promo promo;

  const _TitleBlock({required this.promo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      constraints: const BoxConstraints(minHeight: 150),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [CelfixColors.blue, CelfixColors.blueDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (promo.category != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      promo.category!.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  promo.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                if (promo.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    promo.description!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          const CelfixMark(size: 44, background: Colors.white),
        ],
      ),
    );
  }
}
