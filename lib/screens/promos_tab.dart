import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/promo.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/celfix_header.dart';
import '../widgets/premium.dart';
import '../widgets/celfix_logo.dart';
import '../widgets/promo_card.dart';
import '../widgets/location_filter.dart';

class PromosTab extends ConsumerWidget {
  const PromosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promos = ref.watch(promosProvider);

    return Column(
      children: [
        const CelfixHeader(greeting: 'Promos'),
        Expanded(
          child: AsyncListView<Promo>(
            value: promos,
            padding: const EdgeInsets.fromLTRB(
                CelfixShape.pageInset, 20, CelfixShape.pageInset, 32),
            header: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(text: 'Socios CELFIX'),
                SizedBox(height: 12),
                LocationFilter(),
              ],
            ),
            onRefresh: () async => ref.refresh(promosProvider.future),
            empty: const EmptyView(
              icon: Icons.local_fire_department_outlined,
              title: 'No hay promociones activas',
              subtitle: 'Prueba seleccionando otra sucursal o vuelve pronto.',
            ),
            itemBuilder: (context, promo) => PremiumGate(
                isPremiumItem: promo.isPremium,
                child: PromoCard(promo: promo),
              ),
          ),
        ),
      ],
    );
  }
}
