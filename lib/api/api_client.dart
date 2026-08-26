import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/env.dart';
import '../utils/secure_storage.dart';
import 'api_exception.dart';

/// Dio configurado con los dos interceptores globales:
///   1. inyecta `Authorization: Bearer <token>` en cada request
///   2. ante un 401 borra el token y avisa (para redirigir a login)
///
/// La notificación de 401 es un callback y no una dependencia del router, para
/// que la capa API no sepa nada de navegación.
class ApiClient {
  final Dio dio;
  final SecureStorage _storage;

  /// Se dispara cuando el backend rechaza el token. AuthNotifier lo escucha.
  VoidCallback? onUnauthorized;

  /// Evita que una ráfaga de requests en paralelo dispare N logouts.
  bool _handlingUnauthorized = false;

  ApiClient(this._storage, {Dio? client})
      : dio = client ??
            Dio(BaseOptions(
              baseUrl: Env.apiBase,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Accept': 'application/json',
                'X-App-Version': Env.appVersion,
              },
              // No lanzamos en 4xx: el mapeo a ApiException es nuestro.
              validateStatus: (status) => status != null && status < 400,
            )) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && !_handlingUnauthorized) {
            _handlingUnauthorized = true;
            try {
              await _storage.clearToken();
              onUnauthorized?.call();
            } finally {
              _handlingUnauthorized = false;
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Envuelve una llamada y garantiza que solo salgan ApiException.
  Future<T> guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Ocurrió un error inesperado: $error');
    }
  }

  /// El backend responde 200 con `success:false` en algunos casos, así que
  /// verificar el status HTTP no basta.
  Map<String, dynamic> unwrap(Response<dynamic> response) {
    final data = response.data;
    if (data is! Map) {
      throw const ApiException('Respuesta inesperada del servidor.');
    }
    final json = data.cast<String, dynamic>();
    if (json['success'] == false) {
      throw ApiException(
        json['message']?.toString() ?? 'La solicitud no pudo completarse.',
        statusCode: response.statusCode,
        code: json['code']?.toString(),
      );
    }
    return json;
  }
}
