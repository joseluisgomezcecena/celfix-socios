@Tags(['golden'])
library;

import 'dart:io';

import 'package:celfix_socios/api/models/benefit.dart';
import 'package:celfix_socios/api/models/customer.dart';
import 'package:celfix_socios/api/models/location.dart';
import 'package:celfix_socios/api/models/promo.dart';
import 'package:celfix_socios/screens/login_screen.dart';
import 'package:celfix_socios/state/auth_provider.dart';
import 'package:celfix_socios/theme.dart';
import 'package:celfix_socios/widgets/benefit_card.dart';
import 'package:celfix_socios/widgets/celfix_header.dart';
import 'package:celfix_socios/widgets/celfix_logo.dart';
import 'package:celfix_socios/widgets/location_card.dart';
import 'package:celfix_socios/widgets/membership_card.dart';
import 'package:celfix_socios/widgets/premium.dart';
import 'package:celfix_socios/state/providers.dart';
import 'package:celfix_socios/widgets/promo_card.dart';
import 'package:celfix_socios/widgets/promos_carousel.dart';
import 'package:celfix_socios/widgets/qr_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Renderiza las piezas de UI del rediseño a PNG para revisarlas contra el
/// mockup sin tener que abrir la app.
///
/// Correr con: flutter test test/golden_screens_test.dart --update-goldens
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_MX');
    await _loadFont('Poppins', [
      'assets/fonts/Poppins-Regular.ttf',
      'assets/fonts/Poppins-Medium.ttf',
      'assets/fonts/Poppins-SemiBold.ttf',
      'assets/fonts/Poppins-Bold.ttf',
    ]);
    // La fuente de iconos no está en el bundle del test; se toma del SDK
    // para que el patrón del header y los iconos no salgan como cuadros.
    const materialIcons =
        'C:/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf';
    if (File(materialIcons).existsSync()) {
      await _loadFont('MaterialIcons', [materialIcons]);
    }
  });

  testWidgets('inicio: header, credencial y QR', (tester) async {
    await _pump(tester, const _HomePreview(), size: const Size(430, 932));
    await expectLater(
      find.byType(_HomePreview),
      matchesGoldenFile('goldens/inicio.png'),
    );
  });

  testWidgets('beneficios: valor grande a la derecha', (tester) async {
    await _pump(tester, const _BenefitsPreview(), size: const Size(430, 900));
    await expectLater(
      find.byType(_BenefitsPreview),
      matchesGoldenFile('goldens/beneficios.png'),
    );
  });

  testWidgets('tiendas: dirección y horario agrupado', (tester) async {
    await _pump(tester, const _LocationsPreview(), size: const Size(430, 760));
    await expectLater(
      find.byType(_LocationsPreview),
      matchesGoldenFile('goldens/tiendas.png'),
    );
  });

  testWidgets('inicio premium: tarjeta con pill dorada', (tester) async {
    await _pump(tester, const _PremiumHomePreview(),
        size: const Size(430, 560));
    await expectLater(
      find.byType(_PremiumHomePreview),
      matchesGoldenFile('goldens/inicio_premium.png'),
    );
  });

  testWidgets('beneficios: item premium bloqueado para no suscriptor',
      (tester) async {
    await _pump(tester, const _GatedBenefitsPreview(),
        size: const Size(430, 420));
    await expectLater(
      find.byType(_GatedBenefitsPreview),
      matchesGoldenFile('goldens/beneficios_bloqueado.png'),
    );
  });

  testWidgets('login: logo de marca y formulario', (tester) async {
    await _pump(tester, const _LoginPreview(), size: const Size(430, 820));
    await expectLater(
      find.byType(_LoginPreview),
      matchesGoldenFile('goldens/login.png'),
    );
  });

  testWidgets('promos: bloque de título y vigencia', (tester) async {
    await _pump(tester, const _PromosPreview(), size: const Size(430, 700));
    await expectLater(
      find.byType(_PromosPreview),
      matchesGoldenFile('goldens/promos.png'),
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Renderizamos con el SISTEMA EN MODO OSCURO a propósito: el diseño de
  // Celfix es solo claro y la app fuerza ThemeMode.light. Si alguien vuelve a
  // introducir un darkTheme a medias, las tarjetas saldrían negras y estos
  // goldens fallarían.
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
  await tester.pumpAndSettle();

  // Image.asset resuelve de forma asíncrona: sin precargar, el golden se
  // captura antes de que el isotipo llegue a pintarse.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

// --- Datos de muestra (los mismos que devuelve el POS) ---------------------

Customer _customerJson({bool isPremium = false}) => Customer.fromJson({
      'id': 122,
      'name': 'Mario Pérez',
      'first_name': 'Mario',
      'last_name': 'Pérez',
      'mobile': '6861702069',
      'email': null,
      'date_of_birth': '1990-05-15',
      'membership_no': '9001000122',
      'membership_expires_at': isPremium ? '2027-07-04' : null,
      'is_premium': isPremium,
      'photo_url': null,
      'profile_complete': true,
    });

final _customer = _customerJson();
final _premiumCustomer = _customerJson(isPremium: true);

final _benefits = [
  Benefit.fromJson(const {
    'id': 1,
    'title': 'Cupón de Regalo \$100',
    'description': 'Compra mínima \$499',
    'value_type': 'amount',
    'value': 100,
    'display_value': '\$100',
  }),
  Benefit.fromJson(const {
    'id': 2,
    'title': '50% de descuento',
    'description': 'en Cases Seleccionados',
    'value_type': 'percent',
    'value': 50,
    'display_value': '50%',
    'conditions': '*No acumulable en otras promociones',
  }),
  Benefit.fromJson(const {
    'id': 3,
    'title': '\$100 Pesos de Descuento',
    'description': 'en Reparaciones',
    'value_type': 'amount',
    'value': 100,
    'display_value': '\$100',
  }),
];

final _promos = [
  _promo,
  Promo.fromJson(const {
    'id': 2,
    'title': '20% en cambio de batería',
    'description': 'Todos los modelos',
    'category': 'REPARACIÓN',
    'ends_at': '2026-10-15',
  }),
];

final _premiumBenefit = Benefit.fromJson(const {
  'id': 9,
  'title': '3x2 en fundas premium',
  'description': 'Exclusivo para socios Premium',
  'value_type': 'text',
  'display_value': '3x2',
  'is_premium': true,
});

final _location = StoreLocation.fromJson(const {
  'id': 6,
  'name': 'Celfix Americas',
  'address': 'Calz. de las Américas 18, Cuauhtémoc Sur, 21200',
  'phone': '6862474298',
  'hours': {
    'mon': {'open': '09:00 AM', 'close': '6:00 PM'},
    'tue': {'open': '09:00 AM', 'close': '6:00 PM'},
    'wed': {'open': '09:00 AM', 'close': '6:00 PM'},
    'thu': {'open': '09:00 AM', 'close': '6:00 PM'},
    'fri': {'open': '09:00 AM', 'close': '6:00 PM'},
    'sat': {'open': '09:00 AM', 'close': '3:00 PM'},
    'sun': {'closed': true},
  },
  'maps_url': 'https://maps.example/x',
});

final _promo = Promo.fromJson(const {
  'id': 1,
  'title': '¡Obtén Vidrio Templado Gratis!',
  'description': 'En tu compra de Cases Participantes',
  'category': 'GENERAL',
  'starts_at': '2026-06-22',
  'ends_at': '2026-07-30',
});

// --- Previews --------------------------------------------------------------
// Reconstruyen la composición de cada pantalla sin depender de Riverpod ni de
// la red, usando los mismos widgets del rediseño.

class _HomePreview extends StatelessWidget {
  const _HomePreview();

  @override
  Widget build(BuildContext context) => ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _FakeAuth(_customer)),
          promosProvider.overrideWith((ref) async => _promos),
        ],
        child: const _HomeBody(),
      );
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) => _Preview(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            CelfixHeader(
              greeting: '¡Hola ${_customer.name.split(' ').first}!',
              overlay: MembershipCard(customer: _customer),
              overlayOverflow: 152,
              onMenuTap: () {},
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: CelfixShape.pageInset),
              child: MembershipIdentity(
                customer: _customer,
                onSeePurchases: () {},
                onSeeRepairs: () {},
              ),
            ),
            const SizedBox(height: 16),
            QrReveal(customer: _customer),
            const SizedBox(height: 22),
            const PromosCarousel(),
            const SizedBox(height: 32),
          ],
        ),
      );
}

class _BenefitsPreview extends StatelessWidget {
  const _BenefitsPreview();

  @override
  Widget build(BuildContext context) => _Preview(
        child: Column(
          children: [
            CelfixHeader(greeting: 'Beneficios', onMenuTap: () {}),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    CelfixShape.pageInset, 20, CelfixShape.pageInset, 32),
                itemCount: _benefits.length + 1,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => index == 0
                    ? const SectionTitle(text: 'Beneficios Socios CELFIX')
                    : BenefitCard(benefit: _benefits[index - 1]),
              ),
            ),
          ],
        ),
      );
}

class _LocationsPreview extends StatelessWidget {
  const _LocationsPreview();

  @override
  Widget build(BuildContext context) => _Preview(
        child: Column(
          children: [
            CelfixHeader(greeting: 'Tiendas', onMenuTap: () {}),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    CelfixShape.pageInset, 20, CelfixShape.pageInset, 32),
                children: [
                  const Text(
                    'Selecciona una sucursal',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CelfixColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Consulta horarios de servicio e indicaciones para llegar',
                    style:
                        TextStyle(fontSize: 12.5, color: CelfixColors.inkSoft),
                  ),
                  const SizedBox(height: 12),
                  LocationCard(location: _location),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PromosPreview extends StatelessWidget {
  const _PromosPreview();

  @override
  Widget build(BuildContext context) => _Preview(
        child: Column(
          children: [
            CelfixHeader(greeting: 'Promos', onMenuTap: () {}),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    CelfixShape.pageInset, 20, CelfixShape.pageInset, 32),
                children: [
                  const SectionTitle(text: 'Socios CELFIX'),
                  const SizedBox(height: 12),
                  PromoCard(promo: _promo),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Chrome común: fondo de la app y la barra de navegación del diseño.
class _Preview extends StatelessWidget {
  final Widget child;

  const _Preview({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CelfixColors.canvas,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: CelfixColors.line)),
        ),
        child: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.account_circle_outlined), label: 'Inicio'),
            NavigationDestination(
                icon: Icon(Icons.location_on_outlined), label: 'Tiendas'),
            NavigationDestination(
                icon: Icon(Icons.local_fire_department_outlined),
                label: 'Promos'),
            NavigationDestination(
                icon: Icon(Icons.workspace_premium_outlined),
                label: 'Beneficios'),
          ],
        ),
      ),
    );
  }
}

/// El login no vive dentro del shell de pestañas: se renderiza tal cual.
/// Necesita ProviderScope porque lee el aviso de sesión desde authProvider.
class _LoginPreview extends StatelessWidget {
  const _LoginPreview();

  @override
  Widget build(BuildContext context) =>
      const ProviderScope(child: LoginScreen());
}

/// Sesión simulada para los widgets que consultan si el socio es premium.
class _FakeAuth extends AuthNotifier {
  _FakeAuth(this._customer);

  final Customer _customer;

  @override
  AuthState build() => AuthState(
        status: AuthStatus.authenticated,
        customer: _customer,
      );
}

/// Solo la credencial: es donde se ve la diferencia entre premium y no.
class _PremiumHomePreview extends StatelessWidget {
  const _PremiumHomePreview();

  @override
  Widget build(BuildContext context) => _Preview(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            CelfixHeader(
              greeting: '¡Hola Mario!',
              overlay: MembershipCard(customer: _premiumCustomer),
              overlayOverflow: 152,
              onMenuTap: () {},
            ),
            const SizedBox(height: 16),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: CelfixShape.pageInset),
              child: MembershipIdentity(
                customer: _premiumCustomer,
                onSeePurchases: () {},
                onSeeRepairs: () {},
              ),
            ),
          ],
        ),
      );
}

/// Un beneficio normal y uno premium, vistos por alguien NO suscrito.
class _GatedBenefitsPreview extends StatelessWidget {
  const _GatedBenefitsPreview();

  @override
  Widget build(BuildContext context) => ProviderScope(
        overrides: [authProvider.overrideWith(() => _FakeAuth(_customer))],
        child: _Preview(
          child: Column(
            children: [
              CelfixHeader(greeting: 'Beneficios', onMenuTap: () {}),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      CelfixShape.pageInset, 20, CelfixShape.pageInset, 32),
                  children: [
                    const SectionTitle(text: 'Beneficios Socios CELFIX'),
                    const SizedBox(height: 12),
                    BenefitCard(benefit: _benefits.first),
                    const SizedBox(height: 12),
                    PremiumGate(
                      isPremiumItem: _premiumBenefit.isPremium,
                      child: BenefitCard(benefit: _premiumBenefit),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
