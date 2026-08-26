# Celfix Socios

App Flutter del programa de fidelidad de Celfix (Mexicali, MX). Consume la API
pública del POS Laravel. Contrato completo en [docs/API_REFERENCE.md](docs/API_REFERENCE.md).

Un solo repo para Web, Android e iOS: no hay paquetes exclusivos de una
plataforma.

## Correr en desarrollo

El backend local (`php artisan serve`) se enlaza a IPv6, así que **`localhost`
resuelve pero `127.0.0.1` no**. Usa `localhost`:

```powershell
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000/api/v1
```

Sin `--dart-define` el default ya apunta ahí, pero conviene ser explícito.

## Build de producción

```powershell
flutter build web --dart-define=API_BASE=https://pos.celfix.mx/api/v1
```

## Builds nativos

Requieren Android SDK 36 / Xcode. El manifest de Android ya declara el permiso
`INTERNET` (Flutter solo lo agrega a los manifests de debug) y los `<queries>`
de Android 11+ para `url_launcher`. Info.plist ya declara
`LSApplicationQueriesSchemes`.

```powershell
flutter build apk    --dart-define=API_BASE=https://pos.celfix.mx/api/v1
flutter build ipa    --dart-define=API_BASE=https://pos.celfix.mx/api/v1
```

## Estructura

```
lib/
├── api/            Dio + interceptores, modelos, un archivo por grupo de endpoints
│   └── models/     fromJson tolerante (la API mezcla int/string en montos)
├── screens/        Una pantalla por archivo
├── state/          Providers de Riverpod (auth + datos)
├── utils/          Env, secure storage, formateo es-MX
├── widgets/        Compartidos entre pantallas
├── router.dart     go_router + guard de sesión
└── theme.dart      Material 3
```

## Notas de integración

- **Token**: `flutter_secure_storage`. En Android/iOS usa Keystore/Keychain; en
  Web cae a localStorage cifrado con AES (limitación del browser).
- **401**: el interceptor borra el token y `AuthNotifier` manda al login con el
  aviso "Tu sesión expiró".
- **Cambio de contraseña**: el backend rota el token y `AuthApi` guarda el nuevo.
- **Fechas**: la API responde en hora Mexicali sin sufijo `Z`. No se hace
  conversión de timezone en ningún punto.
- **QR de membresía**: se genera client-side con `qr_flutter` desde
  `customer.membership_no`, sin endpoint de backend.
- **Modo invitado**: Sucursales, Promos y Beneficios se navegan sin sesión. Solo
  Perfil, Compras y Reparaciones exigen login.

## Tests

```powershell
flutter test
```

Cubren el parseo tolerante de montos, las fechas sin conversión de timezone y
los horarios de sucursal — los tres puntos donde el JSON real difiere de lo que
documenta el API_REFERENCE.
