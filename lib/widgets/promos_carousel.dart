import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/promo.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'celfix_logo.dart';
import 'premium.dart';

/// Alto de la tira. Fijo a propósito: si cada tarjeta midiera distinto, el
/// carrusel daría saltos al deslizar.
const _carouselHeight = 172.0;

/// Carrusel horizontal de promos, estilo tira deslizable.
///
/// Se esconde solo si no hay promos: una sección vacía con un título no le
/// dice nada al socio.
class PromosCarousel extends ConsumerStatefulWidget {
  /// Se llama al tocar "ver todas".
  final VoidCallback? onSeeAll;

  const PromosCarousel({super.key, this.onSeeAll});

  @override
  ConsumerState<PromosCarousel> createState() => _PromosCarouselState();
}

class _PromosCarouselState extends ConsumerState<PromosCarousel> {
  // viewportFraction < 1 deja asomar la siguiente tarjeta, que es lo que
  // invita a deslizar.
  final _controller = PageController(viewportFraction: 0.86);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promos = ref.watch(promosProvider);

    return promos.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: CelfixShape.pageInset),
              child: SectionTitle(
                text: 'Promociones',
                trailing: widget.onSeeAll == null
                    ? null
                    : TextButton(
                        onPressed: widget.onSeeAll,
                        child: const Text('ver todas'),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: _carouselHeight,
              child: PageView.builder(
                controller: _controller,
                padEnds: false,
                onPageChanged: (page) => setState(() => _page = page),
                itemCount: items.length,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? CelfixShape.pageInset : 0,
                    right: 12,
                  ),
                  child: PremiumGate(
                    isPremiumItem: items[index].isPremium,
                    child: _CarouselCard(promo: items[index]),
                  ),
                ),
              ),
            ),
            if (items.length > 1) ...[
              const SizedBox(height: 12),
              Center(child: _Dots(count: items.length, active: _page)),
            ],
          ],
        );
      },
      // Mientras carga o si falla, la sección no aparece: es contenido
      // secundario y no debe estorbar al QR, que es lo que trae al socio.
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _CarouselCard extends StatelessWidget {
  final Promo promo;

  const _CarouselCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    final image = promo.imageUrl;

    return Container(
      decoration: CelfixShape.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              placeholder: (context, url) => const ColoredBox(
                color: CelfixColors.cardSoft,
              ),
              errorWidget: (context, url, error) => const _BrandBackdrop(),
            )
          else
            const _BrandBackdrop(),
          // Velo inferior para que el texto blanco se lea sobre cualquier
          // imagen que suba el admin.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Color(0x00000000)],
                stops: [0, 0.75],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (promo.category != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      promo.category!.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  promo.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                if (promo.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    promo.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo de marca para promos sin imagen.
class _BrandBackdrop extends StatelessWidget {
  const _BrandBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CelfixColors.blue, CelfixColors.blueDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: CelfixMark(size: 34, background: Colors.white),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int active;

  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == active ? CelfixColors.cyan : CelfixColors.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
