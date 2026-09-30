import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/benefit.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/benefit_card.dart';
import '../widgets/celfix_header.dart';
import '../widgets/premium.dart';
import '../widgets/celfix_logo.dart';
import '../widgets/location_filter.dart';

class BenefitsTab extends ConsumerWidget {
  const BenefitsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final benefits = ref.watch(benefitsProvider);

    return Column(
      children: [
        const CelfixHeader(greeting: 'Beneficios'),
        Expanded(
          child: AsyncListView<Benefit>(
            value: benefits,
            padding: const EdgeInsets.fromLTRB(
                CelfixShape.pageInset, 20, CelfixShape.pageInset, 32),
            header: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(text: 'Beneficios Socios CELFIX'),
                SizedBox(height: 12),
                LocationFilter(),
              ],
            ),
            onRefresh: () async => ref.refresh(benefitsProvider.future),
            empty: const EmptyView(
              icon: Icons.workspace_premium_outlined,
              title: 'Sin beneficios publicados',
              subtitle: 'Prueba seleccionando otra sucursal.',
            ),
            itemBuilder: (context, benefit) => PremiumGate(
                isPremiumItem: benefit.isPremium,
                child: BenefitCard(benefit: benefit),
              ),
          ),
        ),
      ],
    );
  }
}
