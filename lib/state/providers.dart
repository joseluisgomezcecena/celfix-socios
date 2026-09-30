import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../api/customer_api.dart';
import '../api/models/app_designs.dart';
import '../api/models/benefit.dart';
import '../api/models/course.dart';
import '../api/models/customer.dart';
import '../api/models/location.dart';
import '../api/models/promo.dart';
import '../api/models/purchase.dart';
import '../api/models/purchase_detail.dart';
import '../api/models/repair_order.dart';
import '../api/public_api.dart';
import '../utils/secure_storage.dart';
import 'auth_provider.dart';

// --- Infraestructura -------------------------------------------------------

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(secureStorageProvider)),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider), ref.watch(secureStorageProvider)),
);

final publicApiProvider =
    Provider<PublicApi>((ref) => PublicApi(ref.watch(apiClientProvider)));

final customerApiProvider =
    Provider<CustomerApi>((ref) => CustomerApi(ref.watch(apiClientProvider)));

// --- Contenido público -----------------------------------------------------

/// Sucursal elegida para filtrar promos y beneficios. `null` = todas.
/// Vive solo en memoria: no persistimos preferencia (sin shared_preferences).
///
/// Riverpod 3 movió StateProvider a `legacy.dart`; usamos Notifier en su lugar.
class SelectedLocationNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? locationId) => state = locationId;
}

final selectedLocationProvider =
    NotifierProvider<SelectedLocationNotifier, int?>(
        SelectedLocationNotifier.new);

/// Imágenes que el admin sube desde el POS. Si el endpoint falla o la key no
/// existe, la app usa su diseño local: nunca bloquea la pantalla.
final appDesignsProvider = FutureProvider<AppDesigns>((ref) async {
  try {
    return await ref.watch(publicApiProvider).designs();
  } on Object {
    return const AppDesigns.empty();
  }
});

final locationsProvider = FutureProvider<List<StoreLocation>>(
  (ref) => ref.watch(publicApiProvider).locations(),
);

final promosProvider = FutureProvider<List<Promo>>((ref) {
  final locationId = ref.watch(selectedLocationProvider);
  return ref.watch(publicApiProvider).promos(locationId: locationId);
});

final benefitsProvider = FutureProvider<List<Benefit>>((ref) {
  final locationId = ref.watch(selectedLocationProvider);
  return ref.watch(publicApiProvider).benefits(locationId: locationId);
});

// --- Cursos ----------------------------------------------------------------

final coursesProvider = FutureProvider<List<Course>>((ref) {
  final locationId = ref.watch(selectedLocationProvider);
  return ref.watch(publicApiProvider).courses(locationId: locationId);
});

/// Inscripciones del socio. Vacío si no hay sesión: sin token el endpoint
/// devolvería 401 y tumbaría la pantalla de cursos.
final myCoursesProvider = FutureProvider<List<Course>>((ref) {
  final isAuthenticated = ref.watch(authProvider).isAuthenticated;
  if (!isAuthenticated) return Future.value(const <Course>[]);
  return ref.watch(customerApiProvider).myCourses();
});

/// Ids en los que el socio está inscrito, listos para cruzar contra la lista
/// pública. Es un AsyncValue a propósito: mientras no resuelva, la UI no debe
/// decidir el botón o mostraría "Inscribirme" a alguien que ya está inscrito.
final enrolledCourseIdsProvider = Provider<AsyncValue<Set<int>>>((ref) {
  return ref
      .watch(myCoursesProvider)
      .whenData((courses) => courses.map((course) => course.id).toSet());
});

/// Invalida las dos listas tras inscribir o cancelar, para que el cupo y el
/// botón se actualicen juntos. Sirve igual desde un provider (Ref) que desde
/// un widget (WidgetRef): ambos exponen invalidate.
void refreshCourses(WidgetRef ref) {
  ref.invalidate(coursesProvider);
  ref.invalidate(myCoursesProvider);
}

// --- Datos del cliente -----------------------------------------------------

final profileProvider = FutureProvider<Customer>(
  (ref) => ref.watch(customerApiProvider).me(),
);

final purchaseDetailProvider = FutureProvider.family<PurchaseDetail, int>(
  (ref, id) => ref.watch(customerApiProvider).purchase(id),
);

final repairOrdersProvider =
    FutureProvider.family<List<RepairOrder>, RepairFilter>(
  (ref, filter) => ref.watch(customerApiProvider).repairOrders(filter: filter),
);

/// Historial acumulado. Guardamos las páginas ya cargadas para que el scroll
/// infinito no re-pida lo anterior.
@immutable
class PurchaseList {
  final List<Purchase> items;
  final Pagination pagination;
  final bool isLoadingMore;

  const PurchaseList({
    required this.items,
    required this.pagination,
    this.isLoadingMore = false,
  });

  bool get hasMore => pagination.hasMore;

  PurchaseList copyWith({
    List<Purchase>? items,
    Pagination? pagination,
    bool? isLoadingMore,
  }) =>
      PurchaseList(
        items: items ?? this.items,
        pagination: pagination ?? this.pagination,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

class PurchasesNotifier extends AsyncNotifier<PurchaseList> {
  @override
  Future<PurchaseList> build() async {
    final page = await ref.watch(customerApiProvider).purchases(page: 1);
    return PurchaseList(items: page.items, pagination: page.pagination);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await ref
          .read(customerApiProvider)
          .purchases(page: current.pagination.current + 1);
      state = AsyncData(PurchaseList(
        items: [...current.items, ...next.items],
        pagination: next.pagination,
      ));
    } on Object catch (error, stack) {
      // Conservamos lo ya cargado: un fallo de la página N no debe vaciar la lista.
      state = AsyncData(current.copyWith(isLoadingMore: false));
      ref.read(purchasesErrorProvider.notifier).report(error);
      if (kDebugMode) debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Error puntual al paginar (la lista sigue viva) — se muestra como SnackBar.
class PurchasesErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void report(Object? error) => state = error;
  void clear() => state = null;
}

final purchasesErrorProvider =
    NotifierProvider<PurchasesErrorNotifier, Object?>(
        PurchasesErrorNotifier.new);

final purchasesProvider =
    AsyncNotifierProvider<PurchasesNotifier, PurchaseList>(
        PurchasesNotifier.new);
