import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Wordmark completo de Celfix (`assets/images/logo.svg`).
///
/// El archivo original viene en un solo color (el cyan de marca `#019ADA`), así
/// que sobre fondos azules hay que recolorearlo o se pierde. Por eso `color` es
/// obligatorio en la práctica: cada pantalla decide según su fondo.
class CelfixLogo extends StatelessWidget {
  /// Alto del wordmark. El ancho sale de la proporción original (500 × 135).
  final double height;

  /// Color sólido con el que se pinta. `null` respeta el color del archivo.
  final Color? color;

  const CelfixLogo({super.key, this.height = 32, this.color});

  /// Proporción del viewBox del SVG.
  static const _aspectRatio = 500 / 135;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/logo.svg',
      height: height,
      width: height * _aspectRatio,
      fit: BoxFit.contain,
      colorFilter:
          color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      semanticsLabel: 'Celfix',
    );
  }
}

/// Isotipo: la "X" de Celfix (`assets/images/x.svg`).
///
/// Aparece al centro del QR y en las tarjetas de promos. El archivo se extrajo
/// de `logo.svg` (las tres rutas de la "X"), así que es vectorial: se ve nítido
/// a cualquier tamaño y densidad de pantalla, sin variantes 2x/3x.
class CelfixMark extends StatelessWidget {
  final double size;

  /// Fondo circular detrás del isotipo. `null` lo deja sin fondo.
  final Color? background;

  /// Recolorea el isotipo. `null` respeta el cyan de marca del archivo.
  final Color? color;

  const CelfixMark({
    super.key,
    this.size = 36,
    this.background,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final mark = SvgPicture.asset(
      'assets/images/x.svg',
      width: size,
      height: size,
      // El isotipo es casi cuadrado pero no exacto (97.6 × 95.8); contain
      // evita deformarlo dentro de la caja.
      fit: BoxFit.contain,
      colorFilter:
          color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      semanticsLabel: 'Celfix',
    );

    if (background == null) return mark;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      // El isotipo respira dentro del círculo en vez de tocar los bordes.
      child: Padding(
        padding: EdgeInsets.all(size * 0.18),
        child: mark,
      ),
    );
  }
}

/// Título de sección en azul, como "Beneficios Socios CELFIX" del diseño.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle({super.key, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: CelfixColors.blue,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
