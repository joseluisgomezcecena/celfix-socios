import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'router.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sin esto, los DateFormat con locale 'es_MX' lanzan en tiempo de ejecución.
  await initializeDateFormatting('es_MX');
  runApp(const ProviderScope(child: CelfixSociosApp()));
}

class CelfixSociosApp extends ConsumerWidget {
  const CelfixSociosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Celfix Socios',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      // El diseño de Celfix es solo claro; sin esto el modo oscuro del sistema
      // dejaba las tarjetas y la barra inferior en negro.
      themeMode: ThemeMode.light,
      routerConfig: router,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
