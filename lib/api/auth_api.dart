import '../utils/secure_storage.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'models/customer.dart';

/// Password que el backfill del backend asignó a todos los clientes existentes.
const kDefaultPassword = 'password1';

class AuthResult {
  final String token;
  final Customer customer;

  const AuthResult({required this.token, required this.customer});
}

class AuthApi {
  final ApiClient _api;
  final SecureStorage _storage;

  AuthApi(this._api, this._storage);

  /// El backend normaliza el teléfono por los últimos 10 dígitos, así que
  /// mandamos lo que el usuario escribió sin validar formato.
  Future<AuthResult> login(String mobile, String password) =>
      _api.guard(() async {
        final response = await _api.dio.post<dynamic>(
          '/auth/login',
          data: {'mobile': mobile, 'password': password},
        );
        final json = _api.unwrap(response);
        final result = AuthResult(
          token: json['token'].toString(),
          customer:
              Customer.fromJson((json['customer'] as Map).cast<String, dynamic>()),
        );
        await _persist(result, usingDefaultPassword: password == kDefaultPassword);
        return result;
      });

  /// 201 = alta + auto-login. 409 `already_registered` = el móvil ya existe.
  Future<AuthResult> register({
    required String mobile,
    required String name,
    required String password,
  }) =>
      _api.guard(() async {
        final response = await _api.dio.post<dynamic>(
          '/auth/register',
          data: {
            'mobile': mobile,
            'name': name,
            'password': password,
            'password_confirmation': password,
          },
        );
        final json = _api.unwrap(response);
        final result = AuthResult(
          token: json['token'].toString(),
          customer:
              Customer.fromJson((json['customer'] as Map).cast<String, dynamic>()),
        );
        await _persist(result, usingDefaultPassword: false);
        return result;
      });

  /// Limpia el token local pase lo que pase: si el server ya lo invalidó, el
  /// 401 no debe dejar al usuario atrapado en una sesión muerta.
  Future<void> logout() async {
    try {
      await _api.dio.post<dynamic>('/auth/logout');
    } on Object {
      // Ignorado a propósito.
    } finally {
      await _storage.clearToken();
    }
  }

  /// El backend ROTA el token: hay que guardar el nuevo o el siguiente request
  /// se va con uno muerto.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _api.guard(() async {
        final response = await _api.dio.post<dynamic>(
          '/auth/change-password',
          data: {
            'current_password': currentPassword,
            'new_password': newPassword,
            'new_password_confirmation': newPassword,
          },
        );
        final json = _api.unwrap(response);
        final token = json['token']?.toString();
        if (token == null || token.isEmpty) {
          throw const ApiException(
            'El servidor no devolvió una sesión nueva. Vuelve a iniciar sesión.',
          );
        }
        await _storage.writeToken(token);
        await _storage.writeUsingDefaultPassword(newPassword == kDefaultPassword);
      });

  Future<void> _persist(AuthResult result,
      {required bool usingDefaultPassword}) async {
    await _storage.writeToken(result.token);
    await _storage.writeUsingDefaultPassword(usingDefaultPassword);
  }
}
