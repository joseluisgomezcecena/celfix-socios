import 'package:dio/dio.dart';

/// Excepción única que sale de la capa API. Las pantallas nunca ven DioException.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Código de negocio del backend, p.ej. `already_registered` en /auth/register.
  final String? code;

  const ApiException(this.message, {this.statusCode, this.code});

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 422;
  bool get isConflict => statusCode == 409;
  bool get isRateLimited => statusCode == 429;

  /// Traduce cualquier fallo de Dio a un mensaje mostrable en español.
  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final status = response?.statusCode;
    final data = response?.data;

    String? backendMessage;
    String? backendCode;
    if (data is Map) {
      backendMessage = data['message']?.toString();
      backendCode = data['code']?.toString();
    }

    if (status != null) {
      final fallback = switch (status) {
        401 => 'Tu sesión expiró, ingresa de nuevo.',
        404 => 'No disponible.',
        422 => 'Revisa los datos ingresados.',
        429 => 'Demasiados intentos. Espera un minuto e inténtalo otra vez.',
        >= 500 => 'El servidor no está disponible. Intenta más tarde.',
        _ => 'Ocurrió un error inesperado.',
      };
      return ApiException(
        backendMessage?.isNotEmpty == true ? backendMessage! : fallback,
        statusCode: status,
        code: backendCode,
      );
    }

    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'La conexión tardó demasiado. Revisa tu internet.',
      DioExceptionType.connectionError =>
        'No se pudo conectar con Celfix. Revisa tu conexión.',
      DioExceptionType.cancel => 'Solicitud cancelada.',
      _ => 'No se pudo completar la solicitud.',
    };
    return ApiException(message);
  }

  @override
  String toString() => message;
}
