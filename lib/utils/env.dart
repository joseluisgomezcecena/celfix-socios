/// Configuración de entorno inyectada en tiempo de compilación.
///
/// Dev:  flutter run -d chrome --dart-define=API_BASE=http://localhost:8000/api/v1
/// Prod: flutter build web --dart-define=API_BASE=https://pos.celfix.mx/api/v1
class Env {
  const Env._();

  /// El default apunta al POS local. Ojo: `php artisan serve` se enlaza a ::1,
  /// así que `localhost` resuelve pero `127.0.0.1` no.
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  /// Se manda como X-App-Version en cada request. El backend aún no lo valida,
  /// pero deja el contrato listo (sección 6 del API_REFERENCE).
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static bool get isProduction => apiBase.startsWith('https://pos.celfix.mx');
}
