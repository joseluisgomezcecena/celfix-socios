import 'api_client.dart';
import 'models/app_designs.dart';
import 'models/benefit.dart';
import 'models/course.dart';
import 'models/json.dart';
import 'models/location.dart';
import 'models/promo.dart';

/// Endpoints públicos: no requieren token (el interceptor lo manda si existe,
/// el backend lo ignora).
class PublicApi {
  final ApiClient _api;

  PublicApi(this._api);

  /// Imágenes configurables del POS. Si una key no viene, la app usa su
  /// diseño local.
  Future<AppDesigns> designs() => _api.guard(() async {
        final response = await _api.dio.get<dynamic>('/app-designs');
        return AppDesigns.fromJson(_api.unwrap(response));
      });

  Future<List<StoreLocation>> locations() => _api.guard(() async {
        final response = await _api.dio.get<dynamic>('/locations');
        final json = _api.unwrap(response);
        return asMapList(json['data']).map(StoreLocation.fromJson).toList();
      });

  /// Sin `locationId` el backend devuelve solo las promos globales; con él
  /// devuelve globales + las de esa sucursal.
  Future<List<Promo>> promos({int? locationId}) => _api.guard(() async {
        final response = await _api.dio.get<dynamic>(
          '/promos',
          queryParameters: {'location_id': ?locationId},
        );
        final json = _api.unwrap(response);
        return asMapList(json['data']).map(Promo.fromJson).toList();
      });

  /// Cursos activos. Por default omite los que ya terminaron.
  Future<List<Course>> courses({int? locationId, bool includePast = false}) =>
      _api.guard(() async {
        final response = await _api.dio.get<dynamic>(
          '/courses',
          queryParameters: {
            'location_id': ?locationId,
            'include_past': includePast ? 1 : 0,
          },
        );
        return asMapList(_api.unwrap(response)['data'])
            .map(Course.fromJson)
            .toList();
      });

  Future<List<Benefit>> benefits({int? locationId}) => _api.guard(() async {
        final response = await _api.dio.get<dynamic>(
          '/benefits',
          queryParameters: {'location_id': ?locationId},
        );
        final json = _api.unwrap(response);
        return asMapList(json['data']).map(Benefit.fromJson).toList();
      });
}
