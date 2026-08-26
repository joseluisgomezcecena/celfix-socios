import 'dart:typed_data';

import 'package:celfix_socios/api/api_client.dart';
import 'package:celfix_socios/router.dart';
import 'package:celfix_socios/screens/purchases_screen.dart';
import 'package:celfix_socios/screens/repair_orders_screen.dart';
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

class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    const customer = '{"id":42,"name":"Mario Pérez","mobile":"6861702069",'
        '"email":null,"membership_no":"9001000042",'
        '"membership_expires_at":null}';

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

ProviderContainer _container(SecureStorage storage) => ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWith((ref) {
          final client = ApiClient(ref.watch(secureStorageProvider));
          client.dio.httpClientAdapter = _FakeAdapter();
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Deja la app con sesión iniciada y en la pestaña Inicio.
Future<ProviderContainer> _signedIn(WidgetTester tester) async {
  final storage = _MemoryStorage();
  await storage.writeToken('tok-123');
  final container = _container(storage);
  addTearDown(container.dispose);
  await _pumpApp(tester, container);

  // La red va en el zone real: dentro de testWidgets el reloj es falso y los
  // eventos del stream de Dio nunca se entregan.
  await tester.runAsync(() => container.read(authProvider.notifier).bootstrap());
  await _settle(tester);

  // Inicio muestra un spinner hasta que /me responde; sin resolverlo aquí la
  // ficha del socio (y sus enlaces) nunca llega a pintarse.
  await tester.runAsync(() => container.read(profileProvider.future));
  await _settle(tester);
  return container;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_MX');
  });

  testWidgets('el botón de menú abre el drawer con Cerrar sesión',
      (tester) async {
    final container = await _signedIn(tester);
    expect(container.read(authProvider).isAuthenticated, isTrue);

    // Antes de abrir, las opciones del menú no están visibles.
    expect(find.text('Cerrar sesión'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await _settle(tester);

    expect(
      find.text('Cerrar sesión'),
      findsOneWidget,
      reason: 'el hamburguesa debe abrir el menú lateral',
    );
    expect(find.text('Mis compras'), findsOneWidget);
    expect(find.text('Mis reparaciones'), findsOneWidget);
    expect(find.text('Cambiar contraseña'), findsOneWidget);
  });

  testWidgets('Cerrar sesión del menú termina la sesión', (tester) async {
    final container = await _signedIn(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await _settle(tester);

    // El onTap del menú es asíncrono (hace POST /auth/logout), así que el tap
    // regresa antes de que termine: hay que dejar correr el zone real.
    await tester.runAsync(() async {
      await tester.tap(find.text('Cerrar sesión'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await _settle(tester);

    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
  });

  testWidgets('como invitado el menú ofrece Iniciar sesión', (tester) async {
    final container = _container(_MemoryStorage());
    addTearDown(container.dispose);
    await _pumpApp(tester, container);
    await container.read(authProvider.notifier).bootstrap();
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await _settle(tester);

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsNothing);
  });

  testWidgets('desde Inicio se llega a compras y a reparaciones',
      (tester) async {
    await _signedIn(tester);

    await tester.tap(find.text('reparaciones'));
    await _settle(tester);
    expect(find.byType(RepairOrdersScreen), findsOneWidget);

    // pageBack() busca el botón de Cupertino y byTooltip('Back') falla porque
    // la app está localizada en español; el ícono es estable en ambos casos.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);

    await tester.tap(find.text('ver compras'));
    await _settle(tester);
    expect(find.byType(PurchasesScreen), findsOneWidget);
  });
}
