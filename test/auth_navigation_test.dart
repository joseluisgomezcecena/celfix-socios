import 'dart:typed_data';

import 'package:celfix_socios/api/api_client.dart';
import 'package:celfix_socios/router.dart';
import 'package:celfix_socios/screens/home_tab.dart';
import 'package:celfix_socios/screens/login_screen.dart';
import 'package:celfix_socios/screens/profile_form_screen.dart';
import 'package:celfix_socios/state/auth_provider.dart';
import 'package:celfix_socios/state/providers.dart';
import 'package:celfix_socios/theme.dart';
import 'package:celfix_socios/utils/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// El plugin real habla por un canal de plataforma que en tests nunca
/// responde y dejaría los `await` colgados.
class _MemoryStorage implements SecureStorage {
  String? _token;
  bool _defaultPassword = false;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async => _token = token;

  @override
  Future<void> clearToken() async {
    _token = null;
    _defaultPassword = false;
  }

  @override
  Future<bool> readUsingDefaultPassword() async => _defaultPassword;

  @override
  Future<void> writeUsingDefaultPassword(bool value) async =>
      _defaultPassword = value;
}

/// Backend simulado que responde como el POS en el flujo de sesión.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.profileComplete = true});

  /// Permite simular un socio que aún no llenó nombre y fecha de nacimiento.
  final bool profileComplete;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final customer = '{"id":42,"name":"Mario Pérez",'
        '"first_name":${profileComplete ? '"Mario"' : 'null'},'
        '"last_name":${profileComplete ? '"Pérez"' : 'null'},'
        '"date_of_birth":${profileComplete ? '"1990-05-15"' : 'null'},'
        '"mobile":"6861702069","email":null,'
        '"membership_no":"9001000042","membership_expires_at":null,'
        '"is_premium":false,"photo_url":null,'
        '"profile_complete":$profileComplete}';

    final body = switch (options.path) {
      final path when path.endsWith('/auth/login') =>
        '{"success":true,"token":"tok-123","customer":$customer}',
      final path when path.endsWith('/me') =>
        '{"success":true,"customer":$customer}',
      _ => '{"success":true,"data":[]}',
    };

    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _container(
  SecureStorage storage, {
  bool profileComplete = true,
}) =>
    ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWith((ref) {
          final client = ApiClient(ref.watch(secureStorageProvider));
          client.dio.httpClientAdapter =
              _FakeAdapter(profileComplete: profileComplete);
          return client;
        }),
      ],
    );

Future<void> _pumpApp(WidgetTester tester, ProviderContainer container) =>
    tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            theme: appTheme,
            themeMode: ThemeMode.light,
            routerConfig: ref.watch(routerProvider),
            locale: const Locale('es', 'MX'),
            supportedLocales: const [Locale('es', 'MX')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ),
      ),
    );

/// Avanza unos frames sin esperar a que todo quede quieto: los spinners de
/// carga animan indefinidamente y colgarían a pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  // Suficientes frames para que termine la transición de ruta (~300 ms) sin
  // usar pumpAndSettle, que nunca retorna con los spinners animando.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Las llamadas HTTP tienen que correr en el zone real: dentro de testWidgets
/// el reloj es falso y los eventos del stream de Dio nunca se entregan, así
/// que un `await` directo se cuelga para siempre.
Future<void> _network(WidgetTester tester, Future<void> Function() call) async {
  await tester.runAsync(call);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_MX');
  });

  testWidgets('tras iniciar sesión la app sale de la pantalla de login sola',
      (tester) async {
    final container = _container(_MemoryStorage());
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    // Sin token guardado, el arranque deja al invitado en Inicio.
    await container.read(authProvider.notifier).bootstrap();
    await _settle(tester);
    expect(find.byType(HomeTab), findsOneWidget);

    // El invitado abre login con el botón "INICIAR SESIÓN".
    await tester.tap(find.text('INICIAR SESIÓN'));
    await _settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    // Credenciales correctas.
    await _network(
      tester,
      () => container.read(authProvider.notifier).login('6861702069', 'x'),
    );
    await _settle(tester);

    // Esto es lo que fallaba: la sesión quedaba iniciada pero la pantalla de
    // login seguía encima y el usuario no veía ningún cambio.
    expect(
      find.byType(LoginScreen),
      findsNothing,
      reason: 'después del login la pantalla de login debe cerrarse sola',
    );
    expect(find.byType(HomeTab), findsOneWidget);
    expect(container.read(authProvider).isAuthenticated, isTrue);
  });

  testWidgets('al cerrar sesión regresa al inicio de invitado', (tester) async {
    final storage = _MemoryStorage();
    await storage.writeToken('tok-123');

    final container = _container(storage);
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    // Con token guardado el arranque lo valida contra /me y entra con sesión.
    await _network(
      tester,
      () => container.read(authProvider.notifier).bootstrap(),
    );
    await _settle(tester);
    expect(container.read(authProvider).isAuthenticated, isTrue);

    await _network(
      tester,
      () => container.read(authProvider.notifier).logout(),
    );
    await _settle(tester);

    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
  });

  testWidgets('con el perfil incompleto la app obliga a completarlo',
      (tester) async {
    final storage = _MemoryStorage();
    await storage.writeToken('tok-123');

    final container = _container(storage, profileComplete: false);
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    await _network(
      tester,
      () => container.read(authProvider.notifier).bootstrap(),
    );
    await _settle(tester);

    // No debe poder quedarse en Inicio con el perfil a medias.
    expect(find.byType(ProfileFormScreen), findsOneWidget);
    expect(find.byType(HomeTab), findsNothing);
    expect(find.text('Completa tu perfil'), findsOneWidget);
  });

  testWidgets('con el perfil completo entra normal a Inicio', (tester) async {
    final storage = _MemoryStorage();
    await storage.writeToken('tok-123');

    final container = _container(storage);
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    await _network(
      tester,
      () => container.read(authProvider.notifier).bootstrap(),
    );
    await _settle(tester);

    expect(find.byType(ProfileFormScreen), findsNothing);
    expect(find.byType(HomeTab), findsOneWidget);
  });

  testWidgets('un invitado no entra a promos ni beneficios por URL',
      (tester) async {
    final container = _container(_MemoryStorage());
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    await container.read(authProvider.notifier).bootstrap();
    await _settle(tester);

    // En Web la URL se puede teclear, así que no basta con esconder la
    // pestaña: el router tiene que rechazar la ruta.
    for (final route in [Routes.promos, Routes.benefits]) {
      container.read(routerProvider).go(route);
      await _settle(tester);
      expect(
        find.byType(LoginScreen),
        findsOneWidget,
        reason: '$route debe exigir sesión',
      );
    }
  });
}
