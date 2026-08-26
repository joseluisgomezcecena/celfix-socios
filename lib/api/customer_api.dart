import 'api_client.dart';
import 'models/customer.dart';
import 'models/json.dart';
import 'models/purchase.dart';
import 'models/purchase_detail.dart';
import 'models/repair_order.dart';

/// Endpoints que exigen bearer token.
class CustomerApi {
  final ApiClient _api;

  CustomerApi(this._api);

  Future<Customer> me() => _api.guard(() async {
        final response = await _api.dio.get<dynamic>('/me');
        final json = _api.unwrap(response);
        return Customer.fromJson(
            (json['customer'] as Map).cast<String, dynamic>());
      });

  Future<PurchasePage> purchases({int page = 1}) => _api.guard(() async {
        final response = await _api.dio.get<dynamic>(
          '/purchases',
          queryParameters: {'page': page},
        );
        final json = _api.unwrap(response);
        final pagination = json['pagination'];
        return PurchasePage(
          items: asMapList(json['data']).map(Purchase.fromJson).toList(),
          pagination: pagination is Map
              ? Pagination.fromJson(pagination.cast<String, dynamic>())
              : const Pagination(current: 1, perPage: 20, total: 0, last: 1),
        );
      });

  /// Un 404 aquí puede significar "no existe" o "es de otro cliente"; el
  /// backend no distingue a propósito y la app lo trata igual.
  Future<PurchaseDetail> purchase(int id) => _api.guard(() async {
        final response = await _api.dio.get<dynamic>('/purchases/$id');
        final json = _api.unwrap(response);
        return PurchaseDetail.fromJson(
            (json['purchase'] as Map).cast<String, dynamic>());
      });

  Future<List<RepairOrder>> repairOrders({
    RepairFilter filter = RepairFilter.all,
  }) =>
      _api.guard(() async {
        final response = await _api.dio.get<dynamic>(
          '/repair-orders',
          queryParameters: {'status': filter.value},
        );
        final json = _api.unwrap(response);
        return asMapList(json['data']).map(RepairOrder.fromJson).toList();
      });
}
