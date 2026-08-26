import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';

/// Estado de error reutilizable, con el mensaje ya traducido por ApiException.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Ocurrió un error inesperado.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Envuelve un AsyncValue de lista con pull-to-refresh, estados vacío y error.
///
/// Usamos RefreshIndicator nativo en vez del paquete pull_to_refresh: mismo
/// comportamiento, cero dependencias, y funciona igual en web y móvil.
class AsyncListView<T> extends ConsumerWidget {
  final AsyncValue<List<T>> value;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget empty;
  final EdgeInsets padding;
  final Widget? header;

  const AsyncListView({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.itemBuilder,
    required this.empty,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 32),
    this.header,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _scrollable(ErrorView(error: error, onRetry: onRefresh)),
        data: (items) {
          if (items.isEmpty) return _scrollable(empty);
          return ListView.separated(
            padding: padding,
            // El +1 del header lo compensamos en los índices de abajo.
            itemCount: items.length + (header != null ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (header != null) {
                if (index == 0) return header!;
                return itemBuilder(context, items[index - 1]);
              }
              return itemBuilder(context, items[index]);
            },
          );
        },
      ),
    );
  }

  /// Un hijo no scrollable rompe el pull-to-refresh; lo metemos en un
  /// ListView de altura completa para que el gesto siga funcionando.
  Widget _scrollable(Widget child) => LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: constraints.maxHeight, child: child),
          ],
        ),
      );
}
