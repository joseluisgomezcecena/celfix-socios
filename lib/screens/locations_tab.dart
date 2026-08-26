import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/location.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/celfix_header.dart';
import '../widgets/location_card.dart';

class LocationsTab extends ConsumerWidget {
  const LocationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationsProvider);

    return Column(
      children: [
        const CelfixHeader(greeting: 'Tiendas'),
        Expanded(
          child: AsyncListView<StoreLocation>(
            value: locations,
            padding: const EdgeInsets.fromLTRB(
                CelfixShape.pageInset, 20, CelfixShape.pageInset, 32),
            onRefresh: () async => ref.refresh(locationsProvider.future),
            header: const _ListHeader(),
            empty: const EmptyView(
              icon: Icons.store_outlined,
              title: 'Sin sucursales publicadas',
              subtitle: 'Vuelve a intentarlo más tarde.',
            ),
            itemBuilder: (context, location) =>
                LocationCard(location: location),
          ),
        ),
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecciona una sucursal',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CelfixColors.ink,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Consulta horarios de servicio e indicaciones para llegar',
          style: TextStyle(fontSize: 12.5, color: CelfixColors.inkSoft),
        ),
      ],
    );
  }
}
