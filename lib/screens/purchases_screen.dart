import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_exception.dart';
import '../api/models/purchase.dart';
import '../router.dart';
import '../state/providers.dart';
import '../utils/formatters.dart';
import '../widgets/async_view.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Carga la siguiente página al acercarse al final. loadMore() ya ignora
  /// llamadas concurrentes y el caso "no hay más".
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(purchasesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchases = ref.watch(purchasesProvider);

    // Un fallo al paginar no vacía la lista: se avisa y ya.
    ref.listen(purchasesErrorProvider, (_, error) {
      if (error == null) return;
      final message =
          error is ApiException ? error.message : 'No se pudo cargar más.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      ref.read(purchasesErrorProvider.notifier).clear();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Mis compras')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(purchasesProvider.notifier).refresh(),
        child: purchases.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              SizedBox(
                height: 400,
                child: ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(purchasesProvider),
                ),
              ),
            ],
          ),
          data: (list) {
            if (list.items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 400,
                    child: EmptyView(
                      icon: Icons.receipt_long_outlined,
                      title: 'Aún no tienes compras',
                      subtitle:
                          'Tus tickets aparecerán aquí después de comprar en cualquier sucursal.',
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              // +1 header con el total, +1 footer del spinner de paginación.
              itemCount: list.items.length + (list.hasMore ? 2 : 1),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${list.pagination.total} '
                      '${list.pagination.total == 1 ? "compra" : "compras"}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }
                if (index > list.items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _PurchaseCard(purchase: list.items[index - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final Purchase purchase;

  const _PurchaseCard({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () => context.push(Routes.purchaseDetail(purchase.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ticket #${purchase.invoiceNo}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    Fmt.money(purchase.total),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${Fmt.rawDate(purchase.date)} · ${purchase.time} · ${purchase.location}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Chip(
                    label:
                        '${purchase.itemsCount} ${purchase.itemsCount == 1 ? "artículo" : "artículos"}',
                    color: theme.colorScheme.surfaceContainerHighest,
                    onColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  // Las reparaciones también salen en el historial: las
                  // marcamos en lugar de filtrarlas.
                  if (purchase.isRepair)
                    _Chip(
                      label: 'Reparación',
                      color: theme.colorScheme.secondaryContainer,
                      onColor: theme.colorScheme.onSecondaryContainer,
                    ),
                  if (purchase.hasDebt)
                    _Chip(
                      label: 'Saldo ${Fmt.money(purchase.balance)}',
                      color: theme.colorScheme.errorContainer,
                      onColor: theme.colorScheme.onErrorContainer,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color onColor;

  const _Chip({
    required this.label,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: onColor),
      ),
    );
  }
}
