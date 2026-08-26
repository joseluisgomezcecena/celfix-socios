import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/repair_order.dart';
import '../state/providers.dart';
import '../utils/formatters.dart';
import '../widgets/async_view.dart';

class RepairOrdersScreen extends ConsumerStatefulWidget {
  const RepairOrdersScreen({super.key});

  @override
  ConsumerState<RepairOrdersScreen> createState() => _RepairOrdersScreenState();
}

class _RepairOrdersScreenState extends ConsumerState<RepairOrdersScreen> {
  RepairFilter _filter = RepairFilter.all;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(repairOrdersProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reparaciones'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<RepairFilter>(
                segments: [
                  for (final filter in RepairFilter.values)
                    ButtonSegment(value: filter, label: Text(filter.label)),
                ],
                selected: {_filter},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _filter = selection.first),
              ),
            ),
          ),
        ),
      ),
      body: AsyncListView<RepairOrder>(
        value: orders,
        onRefresh: () async =>
            ref.refresh(repairOrdersProvider(_filter).future),
        empty: EmptyView(
          icon: Icons.build_outlined,
          title: switch (_filter) {
            RepairFilter.pending => 'No tienes reparaciones en curso',
            RepairFilter.delivered => 'No tienes reparaciones entregadas',
            RepairFilter.all => 'Aún no tienes reparaciones',
          },
          subtitle:
              'Cuando dejes un equipo en cualquier sucursal, aquí verás su avance.',
        ),
        itemBuilder: (context, order) => _RepairCard(order: order),
      ),
    );
  }
}

class _RepairCard extends StatelessWidget {
  final RepairOrder order;

  const _RepairCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = order.isPending
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.primaryContainer;
    final onStatusColor = order.isPending
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onPrimaryContainer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Orden #${order.invoiceNo}',
                      style: theme.textTheme.titleSmall),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    // status_label ya viene traducido del backend.
                    order.displayStatus,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: onStatusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${Fmt.rawDate(order.date)} · ${order.location}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (order.products != null) ...[
              const SizedBox(height: 10),
              Text(order.products!, style: theme.textTheme.bodyMedium),
            ],
            if (order.notes != null) ...[
              const SizedBox(height: 6),
              Text(
                order.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (order.deliveredAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.task_alt,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Entregada el ${Fmt.rawDateTime(order.deliveredAt)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total ${Fmt.money(order.total)}',
                    style: theme.textTheme.bodyMedium),
                // balance es lo que el cliente aún debe al recoger el equipo.
                if (order.hasDebt)
                  Text(
                    'Por pagar ${Fmt.money(order.balance)}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.error),
                  )
                else
                  Text(
                    'Pagado',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
