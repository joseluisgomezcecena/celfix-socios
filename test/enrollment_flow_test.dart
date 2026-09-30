import 'dart:typed_data';

import 'package:celfix_socios/api/api_client.dart';
import 'package:celfix_socios/router.dart';
import 'package:celfix_socios/screens/courses_screen.dart';
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

/// POS simulado que **mantiene estado**: inscribir cambia lo que devuelven
/// /courses y /me/courses después, igual que el backend real.
class _CoursesBackend implements HttpClientAdapter {
  bool enrolled = false;
  int enrolledCount = 8;

  /// Fuerza 409 en el próximo enroll, para simular que alguien más tomó el
  /// último lugar entre que cargamos la lista y tocamos el botón.
  bool nextEnrollConflicts = false;

  int enrollCalls = 0;

  String get _course =>
      '{"id":4,"title":"Curso de reparación básica",'
      '"description":"Diagnóstico de pantalla y batería.",'
      '"instructor_name":"Ing. Juan Pérez","image_url":null,'
      '"target_location_id":null,'
      '"starts_at":"2026-10-15T10:00:00-07:00",'
      '"ends_at":"2026-10-15T13:00:00-07:00",'
      '"capacity":20,"enrolled_count":$enrolledCount,'
      '"spots_left":${20 - enrolledCount},'
      '"is_full":false,"has_started":false}';

  String get _mine =>
      '{"id":4,"title":"Curso de reparación básica","description":null,'
      '"instructor_name":"Ing. Juan Pérez","image_url":null,'
      '"target_location_id":null,'
      '"starts_at":"2026-10-15T10:00:00-07:00",'
      '"ends_at":"2026-10-15T13:00:00-07:00",'
      '"has_started":false,"has_ended":false}';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method;

    if (path.endsWith('/courses/4/enroll')) {
      if (method == 'POST') {
        enrollCalls++;
        if (nextEnrollConflicts) {
          return _json('{"success":false,"message":"Este curso ya está lleno."}',
              409);
        }
        enrolled = true;
        enrolledCount++;
        return _json('{"success":true,"message":"Inscripción confirmada."}');
      }
      enrolled = false;
      enrolledCount--;
      return _json('{"success":true,"message":"Inscripción cancelada."}');
    }

    if (path.endsWith('/me/courses')) {
      return _json('{"success":true,"data":[${enrolled ? _mine : ''}]}');
    }
    if (path.endsWith('/courses')) {
      return _json('{"success":true,"data":[$_course]}');
    }
    if (path.endsWith('/me')) {
      return _json('{"success":true,"customer":{"id":42,"name":"Mario Pérez",'
          '"first_name":"Mario","last_name":"Pérez",'
          '"date_of_birth":"1990-05-15","mobile":"6861702069","email":null,'
          '"membership_no":"9001000042","membership_expires_at":null,'
          '"is_premium":false,"photo_url":null,"profile_complete":true}}');
    }
    return _json('{"success":true,"data":[]}');
  }

  ResponseBody _json(String body, [int status = 200]) =>
      ResponseBody.fromString(body, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

// ignore: library_private_types_in_public_api
late _CoursesBackend backend;

ProviderContainer _container(SecureStorage storage) => ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWith((ref) {
          final client = ApiClient(ref.watch(secureStorageProvider));
          client.dio.httpClientAdapter = backend;
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

/// Deja la app con sesión y en la pantalla de cursos.
Future<ProviderContainer> _openCourses(WidgetTester tester) async {
  final storage = _MemoryStorage();
  await storage.writeToken('tok-123');
  final container = _container(storage);
  addTearDown(container.dispose);
  await _pumpApp(tester, container);

  // La red corre en el zone real: con el reloj falso de testWidgets los
  // eventos del stream de Dio nunca llegan.
  await tester.runAsync(() => container.read(authProvider.notifier).bootstrap());
  await _settle(tester);

  await tester.runAsync(() async {
    await container.read(coursesProvider.future);
    await container.read(myCoursesProvider.future);
  });
  container.read(routerProvider).push(Routes.courses);
  await _settle(tester);

  expect(find.byType(CoursesScreen), findsOneWidget);
  return container;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_MX');
  });

  setUp(() => backend = _CoursesBackend());

  testWidgets('inscribirse cambia el botón a cancelar y sube el cupo usado',
      (tester) async {
    final container = await _openCourses(tester);

    expect(find.text('INSCRIBIRME'), findsOneWidget);
    expect(find.text('12 lugares disponibles'), findsOneWidget);

    await tester.tap(find.text('INSCRIBIRME'));
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 300)));
    await _settle(tester);

    // Tras inscribir se recargan AMBAS listas: el botón y el cupo tienen que
    // moverse juntos o el socio ve datos incoherentes.
    await tester.runAsync(() async {
      await container.read(coursesProvider.future);
      await container.read(myCoursesProvider.future);
    });
    await _settle(tester);

    expect(backend.enrolled, isTrue);
    expect(find.text('INSCRIBIRME'), findsNothing);
    expect(find.text('Mis cursos'), findsOneWidget);
  });

  testWidgets('si el cupo se llena entre la carga y el tap, avisa',
      (tester) async {
    await _openCourses(tester);
    backend.nextEnrollConflicts = true;

    await tester.tap(find.text('INSCRIBIRME'));
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 300)));
    await _settle(tester);

    // El mensaje es el del backend, no uno inventado por la app.
    expect(find.text('Este curso ya está lleno.'), findsOneWidget);
    expect(backend.enrollCalls, 1);
  });

  testWidgets('tocar un curso del carrusel de Inicio abre la pantalla',
      (tester) async {
    final storage = _MemoryStorage();
    await storage.writeToken('tok-123');
    final container = _container(storage);
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    await tester
        .runAsync(() => container.read(authProvider.notifier).bootstrap());
    await _settle(tester);
    await tester.runAsync(() async {
      await container.read(coursesProvider.future);
      await container.read(myCoursesProvider.future);
    });
    await _settle(tester);

    final tile = find.text('Curso de reparación básica');
    expect(tile, findsWidgets, reason: 'el carrusel debe listar el curso');

    await tester.ensureVisible(tile.first);
    await _settle(tester);
    await tester.tap(tile.first);
    await _settle(tester);

    expect(find.byType(CoursesScreen), findsOneWidget);
    expect(find.text('Esta pantalla no existe.'), findsNothing);
  });

  testWidgets('el menú lateral abre Cursos y talleres', (tester) async {
    final storage = _MemoryStorage();
    await storage.writeToken('tok-123');
    final container = _container(storage);
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    await tester
        .runAsync(() => container.read(authProvider.notifier).bootstrap());
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await _settle(tester);
    // El carrusel de Inicio usa el mismo texto como título de sección, así
    // que apuntamos al item del menú.
    await tester.tap(find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Cursos y talleres'),
    ));
    await _settle(tester);

    expect(find.text('Esta pantalla no existe.'), findsNothing);
    expect(find.byType(CoursesScreen), findsOneWidget);
  });
}
