import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../api/auth_api.dart';
import '../api/customer_api.dart';
import '../api/models/customer.dart';
import '../utils/secure_storage.dart';
import 'providers.dart';

enum AuthStatus {
  /// Todavía no sabemos: el splash está leyendo el token del storage.
  unknown,

  /// Sin sesión. Puede navegar las pestañas públicas (modo invitado).
  guest,

  authenticated,
}

@immutable
class AuthState {
  final AuthStatus status;
  final Customer? customer;

  /// Se llena cuando el interceptor detecta un 401, para avisar en el login.
  final String? sessionMessage;

  /// El cliente sigue con la password del backfill ("password1").
  final bool usingDefaultPassword;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.customer,
    this.sessionMessage,
    this.usingDefaultPassword = false,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isResolved => status != AuthStatus.unknown;

  AuthState copyWith({
    AuthStatus? status,
    Customer? customer,
    String? sessionMessage,
    bool? usingDefaultPassword,
    bool clearCustomer = false,
    bool clearMessage = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        customer: clearCustomer ? null : (customer ?? this.customer),
        sessionMessage: clearMessage ? null : (sessionMessage ?? this.sessionMessage),
        usingDefaultPassword: usingDefaultPassword ?? this.usingDefaultPassword,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthApi _authApi;
  late final CustomerApi _customerApi;
  late final SecureStorage _storage;

  @override
  AuthState build() {
    _authApi = ref.read(authApiProvider);
    _customerApi = ref.read(customerApiProvider);
    _storage = ref.read(secureStorageProvider);

    // El interceptor de 401 desemboca aquí sin que la capa API conozca el router.
    ref.read(apiClientProvider).onUnauthorized = _onUnauthorized;

    return const AuthState();
  }

  /// Arranque: hay token guardado? Lo validamos contra /me antes de confiar en él.
  Future<void> bootstrap() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(status: AuthStatus.guest, clearCustomer: true);
      return;
    }
    final usingDefault = await _storage.readUsingDefaultPassword();
    try {
      final customer = await _customerApi.me();
      state = AuthState(
        status: AuthStatus.authenticated,
        customer: customer,
        usingDefaultPassword: usingDefault,
      );
    } on ApiException catch (error) {
      // El 401 ya limpió el token vía interceptor. Cualquier otro fallo (server
      // caído, sin red) tampoco debe dejar al usuario en un splash infinito.
      if (!error.isUnauthorized) await _storage.clearToken();
      state = AuthState(
        status: AuthStatus.guest,
        sessionMessage: error.isUnauthorized
            ? 'Tu sesión expiró, ingresa de nuevo.'
            : null,
      );
    }
  }

  Future<void> login(String mobile, String password) async {
    final result = await _authApi.login(mobile, password);
    state = AuthState(
      status: AuthStatus.authenticated,
      customer: result.customer,
      usingDefaultPassword: password == kDefaultPassword,
    );
    _invalidateCustomerData();
  }

  Future<void> register({
    required String mobile,
    required String name,
    required String password,
  }) async {
    final result = await _authApi.register(
      mobile: mobile,
      name: name,
      password: password,
    );
    state = AuthState(
      status: AuthStatus.authenticated,
      customer: result.customer,
    );
    _invalidateCustomerData();
  }

  Future<void> logout() async {
    await _authApi.logout();
    state = const AuthState(status: AuthStatus.guest);
    _invalidateCustomerData();
  }

  /// Tras cambiar la password el token rota; refrescamos el perfil por si acaso.
  Future<void> onPasswordChanged() async {
    state = state.copyWith(usingDefaultPassword: false);
    _invalidateCustomerData();
  }

  Future<void> refreshProfile() async {
    final customer = await _customerApi.me();
    state = state.copyWith(customer: customer);
  }

  void clearSessionMessage() {
    if (state.sessionMessage != null) {
      state = state.copyWith(clearMessage: true);
    }
  }

  void _onUnauthorized() {
    if (state.status == AuthStatus.guest) return;
    state = const AuthState(
      status: AuthStatus.guest,
      sessionMessage: 'Tu sesión expiró, ingresa de nuevo.',
    );
    _invalidateCustomerData();
  }

  /// Los datos personales del cliente anterior no deben sobrevivir al cambio
  /// de sesión.
  void _invalidateCustomerData() {
    ref.invalidate(profileProvider);
    ref.invalidate(purchasesProvider);
    ref.invalidate(repairOrdersProvider);
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
