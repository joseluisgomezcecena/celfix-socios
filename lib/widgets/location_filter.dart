import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Selector de sucursal para promos y beneficios.
///
/// "Todas" = sin `location_id`, que en el backend significa "solo globales".
/// Elegir una sucursal devuelve globales + las de esa sucursal.
class LocationFilter extends ConsumerWidget {
  const LocationFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationsProvider);
    final selected = ref.watch(selectedLocationProvider);

    return locations.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: DropdownButtonFormField<int?>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sucursal',
              prefixIcon: Icon(Icons.store_outlined),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas')),
              for (final location in items)
                DropdownMenuItem(value: location.id, child: Text(location.name)),
            ],
            onChanged: (value) =>
                ref.read(selectedLocationProvider.notifier).select(value),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
