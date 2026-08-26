import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../api/models/purchase_detail.dart';
import '../state/providers.dart';
import '../utils/formatters.dart';
import '../widgets/async_view.dart';

class PurchaseDetailScreen extends ConsumerWidget {
  final int purchaseId;

  const PurchaseDetailScreen({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(purchaseDetailProvider(purchaseId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de compra')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          // Un 404 puede ser "no existe" o "es de otro cliente": el backend no
          // distingue a propósito, así que mostramos el mismo mensaje.
          if (error is ApiException && error.isNotFound) {
            return const EmptyView(
              icon: Icons.search_off,
              title: 'Compra no disponible',
              subtitle: 'No pudimos encontrar este ticket en tu cuenta.',
            );
          }
          return ErrorView(
            error: error,
            onRetry: () => ref.invalidate(purchaseDetailProvider(purchaseId)),
          );
        },
        data: (purchase) => RefreshIndicator(
          onRefresh: () async =>
              ref.refresh(purchaseDetailProvider(purchaseId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Header(purchase: purchase),
              const SizedBox(height: 20),
              _Section(
                title: 'Artículos',
                child: Column(
                  children: [
                    for (final item in purchase.items) _ItemRow(item: item),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Totales',
                child: Column(
                  children: [
                    if (purchase.discountAmount > 0)
                      _TotalRow(
                        label: 'Descuento',
                        value: '-${Fmt.money(purchase.discountAmount)}',
                      ),
                    if (purchase.taxAmount > 0)
                      _TotalRow(
                        label: 'Impuestos',
                        value: Fmt.money(purchase.taxAmount),
                      ),
                    _TotalRow(
                      label: 'Total',
                      value: Fmt.money(purchase.total),
                      emphasized: true,
                    ),
                    _TotalRow(
                      label: 'Pagado',
                      value: Fmt.money(purchase.paid),
                    ),
                    if (purchase.balance != 0)
                      _TotalRow(
                        label: purchase.hasDebt ? 'Saldo pendiente' : 'A favor',
                        value: Fmt.money(purchase.balance.abs()),
                        highlight: purchase.hasDebt,
                      ),
                  ],
                ),
              ),
              if (purchase.payments.isNotEmpty) ...[
                const SizedBox(height: 16),
                _Section(
                  title: 'Pagos',
                  child: Column(
                    children: [
                      for (final payment in purchase.payments)
                        _PaymentRow(payment: payment),
                    ],
                  ),
                ),
              ],
              if (purchase.notes != null) ...[
                const SizedBox(height: 16),
                _Section(
                  title: 'Notas',
                  child: Text(purchase.notes!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final PurchaseDetail purchase;

  const _Header({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ticket #${purchase.invoiceNo}',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            _MetaRow(
              icon: Icons.schedule,
              text: Fmt.rawDateTime(purchase.date),
            ),
            _MetaRow(icon: Icons.store_outlined, text: purchase.location),
            if (purchase.isRepair) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  purchase.repairStatus == 'delivered'
                      ? 'Reparación entregada'
                      : 'Reparación en curso',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: theme.textTheme.titleSmall),
        ),
        Card(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final PurchaseItem item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  '${Fmt.quantity(item.quantity)} × ${Fmt.money(item.unitPrice)}'
                  '${item.sku != null ? " · ${item.sku}" : ""}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (item.hasReturn)
                  Text(
                    'Devuelto: ${Fmt.quantity(item.quantityReturned)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(Fmt.money(item.subtotal), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final PurchasePayment payment;

  const _PaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            payment.isReturn
                ? Icons.undo
                : Icons.check_circle_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // is_return = vuelto entregado al cliente, no un pago.
                  payment.isReturn
                      ? 'Cambio (${payment.methodLabel})'
                      : payment.methodLabel,
                  style: theme.textTheme.bodyMedium,
                ),
                if (payment.paidOn != null)
                  Text(
                    Fmt.rawDateTime(payment.paidOn),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Text(
            '${payment.isReturn ? "-" : ""}${Fmt.money(payment.amount)}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  final bool highlight;

  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasized
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    final color = highlight ? theme.colorScheme.error : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style?.copyWith(color: color)),
          Text(value, style: style?.copyWith(color: color)),
        ],
      ),
    );
  }
}
