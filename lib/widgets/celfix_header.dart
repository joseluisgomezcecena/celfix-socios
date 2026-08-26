import 'package:flutter/material.dart';

import '../theme.dart';

/// Iconos de la marca (accesorios y telefonía) que forman la marca de agua
/// del header.
const _patternIcons = <IconData>[
  Icons.phone_android,
  Icons.headphones,
  Icons.watch,
  Icons.camera_alt,
  Icons.wifi,
  Icons.bluetooth,
  Icons.music_note,
  Icons.laptop_mac,
  Icons.battery_charging_full,
  Icons.memory,
  Icons.sim_card,
  Icons.speaker,
  Icons.usb,
  Icons.tablet_mac,
  Icons.cable,
  Icons.location_on,
  Icons.chat_bubble,
  Icons.videogame_asset,
];

/// Dibuja el patrón de iconos del header.
///
/// Se pinta en vez de usar una imagen: escala a cualquier tamaño de pantalla
/// sin pixelarse y no suma peso al bundle.
class _IconPatternPainter extends CustomPainter {
  final Color color;

  const _IconPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 58.0;
    final columns = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        // Índice determinista: el patrón se ve aleatorio pero no cambia entre
        // repintados (nada de Random() en el paint).
        final seed = row * 31 + column * 17;
        final icon = _patternIcons[seed % _patternIcons.length];
        final iconSize = 20.0 + (seed % 3) * 4;
        final angle = ((seed % 7) - 3) * 0.12;

        // Filas impares desfasadas para que no se vean columnas rectas.
        final dx = column * cell + (row.isOdd ? cell / 2 : 0) + (seed % 5) * 2.0;
        final dy = row * cell + (seed % 4) * 3.0;

        final painter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: iconSize,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        canvas.save();
        canvas.translate(dx, dy);
        canvas.rotate(angle);
        painter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_IconPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Header cyan con esquinas inferiores redondeadas, saludo y menú.
class CelfixHeader extends StatelessWidget {
  /// Texto grande del header. Normalmente el saludo con el nombre del socio.
  final String greeting;

  /// Contenido que se encima al header (p. ej. la tarjeta de membresía).
  final Widget? overlay;

  /// Cuánto del overlay sobresale por debajo del header.
  final double overlayOverflow;

  final VoidCallback? onMenuTap;
  final List<Widget> actions;

  const CelfixHeader({
    super.key,
    required this.greeting,
    this.overlay,
    this.overlayOverflow = 0,
    this.onMenuTap,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final barHeight = topInset + 96;

    final bar = ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(CelfixShape.headerRadius),
      ),
      child: Container(
        height: barHeight,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [CelfixColors.cyan, CelfixColors.cyanDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _IconPatternPainter(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: topInset, left: 8, right: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onMenuTap ?? () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                    tooltip: 'Menú',
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (overlay == null) return bar;

    // El overlay se encima al header y sobresale hacia abajo; damos altura
    // extra al Stack para que no se recorte.
    return SizedBox(
      height: barHeight + overlayOverflow,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          bar,
          Positioned(
            left: CelfixShape.pageInset,
            right: CelfixShape.pageInset,
            top: topInset + 74,
            child: overlay!,
          ),
        ],
      ),
    );
  }
}
