import 'package:flutter/material.dart';

/// Paleta Celfix tomada del diseño de pantallas.
class CelfixColors {
  const CelfixColors._();

  /// Cyan del header y de los estados activos.
  static const cyan = Color(0xFF17B2E8);
  static const cyanDark = Color(0xFF0F9FD4);

  /// Azul de marca: títulos, valores destacados y botones.
  static const blue = Color(0xFF1266C4);
  static const blueDeep = Color(0xFF0B57B8);

  static const ink = Color(0xFF1A2B45);
  static const inkSoft = Color(0xFF6B7A90);
  static const line = Color(0xFFE4EAF2);
  static const canvas = Color(0xFFF7F9FC);
  static const card = Color(0xFFFFFFFF);
  static const cardSoft = Color(0xFFFAFBFD);
  static const danger = Color(0xFFD64545);
}

/// Radios y espaciados repetidos en el diseño.
class CelfixShape {
  const CelfixShape._();

  /// Curva inferior del header cyan.
  static const headerRadius = 28.0;
  static const cardRadius = 14.0;
  static const buttonRadius = 10.0;
  static const pageInset = 20.0;

  /// Sombra suave de las tarjetas. Se usa tanto en Card (vía elevation) como
  /// en los contenedores que dibujan su propia decoración, para que todas se
  /// vean igual.
  static const cardShadow = [
    BoxShadow(
      color: Color(0x14101F35),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  /// Decoración estándar de tarjeta blanca con borde y sombra.
  static BoxDecoration cardDecoration({Color color = CelfixColors.card}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: CelfixColors.line),
        boxShadow: cardShadow,
      );
}

const _fontFamily = 'Poppins';

ThemeData _build() {

  final scheme = ColorScheme.fromSeed(
    seedColor: CelfixColors.blue,
    brightness: Brightness.light,
  ).copyWith(
    primary: CelfixColors.blue,
    onPrimary: Colors.white,
    secondary: CelfixColors.cyan,
    onSecondary: Colors.white,
    error: CelfixColors.danger,
    surface: CelfixColors.canvas,
    onSurface: CelfixColors.ink,
    onSurfaceVariant: CelfixColors.inkSoft,
    outlineVariant: CelfixColors.line,
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: CelfixColors.canvas,
    textTheme: base.textTheme.apply(fontFamily: _fontFamily),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _fontFamily),

    // Las pantallas usan el header cyan propio, así que el AppBar de Material
    // queda plano y sin color de fondo propio.
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: CelfixColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: CelfixColors.blue,
      ),
    ),

    cardTheme: CardThemeData(
      color: CelfixColors.card,
      // surfaceTintColor transparente: Material 3 tiñe las superficies
      // elevadas y ensuciaría el blanco de la tarjeta.
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x14101F35),
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CelfixShape.cardRadius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    // Botones tipo "BUSCAR CERCA DE MI": azul sólido, altos, texto en mayúsculas.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CelfixColors.blueDeep,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CelfixShape.buttonRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CelfixColors.blue,
        minimumSize: const Size.fromHeight(46),
        side: const BorderSide(color: CelfixColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CelfixShape.buttonRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CelfixColors.blue,
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CelfixShape.buttonRadius),
        borderSide: const BorderSide(color: CelfixColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CelfixShape.buttonRadius),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CelfixShape.buttonRadius),
        borderSide: const BorderSide(color: CelfixColors.blue, width: 1.6),
      ),
      labelStyle: const TextStyle(fontFamily: _fontFamily),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? CelfixColors.cyan : CelfixColors.inkSoft,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? CelfixColors.cyan : CelfixColors.inkSoft,
        );
      }),
    ),

    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(fontFamily: _fontFamily, color: Colors.white),
    ),
  );
}

/// Tema único de la app. No hay variante oscura: el diseño de Celfix está
/// definido en claro y la app fuerza ThemeMode.light.
final appTheme = _build();
