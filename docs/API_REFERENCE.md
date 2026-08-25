# Celfix Socios — App móvil (Flutter) + API

Documento de referencia autosuficiente para desarrollar la app Flutter que consume la API pública del POS de Celfix. Diseñado para pegarse en una sesión nueva de Claude sin contexto previo. Léelo completo antes de escribir código.

---

## 1. Contexto de negocio

- **Celfix** — cadena de retail de celulares en Mexicali, MX. 4 sucursales activas: Sucursal Nuevo Mexicali, Sucursal Americas, Sucursal Villa Fontana, Sucursal Benito Juárez. Almacén Equipos central.
- **Modelo de negocio del app**: "Celfix Socios" — programa de fidelidad para clientes. La app permite:
  - Ver sucursales, promos y beneficios activos (público, sin auth)
  - Iniciar sesión con teléfono + password
  - Ver perfil (membresía + expiración)
  - Consultar historial de compras
  - Consultar reparaciones en curso / entregadas
  - Cambiar contraseña
- **Producto físico**: app móvil (Flutter) → conecta a API Laravel en `https://pos.celfix.mx/api/v1/*`

---

## 2. Stack del backend

- **Base**: UltimatePOS v6.8.1 (fork open-source de POS, LTS de años). Es un Laravel 8.x con módulos custom.
- **Framework**: Laravel + Blade + Vue partials, MySQL, jQuery en front.
- **Repo Git**: `feature/pos-improved` y `master` (deploy es "push a GitHub" + subir archivos por FTP a hosting).
- **Producción**: `https://pos.celfix.mx` — hosting compartido cPanel, **sin acceso CLI ni artisan**. Deploy = subir archivos + correr SQL a mano en phpMyAdmin.
- **PHP 7.4/8.x**. Sin composer install en prod (todo se sube pre-vendored).
- **BD prod**: MySQL, DB name `pos_celfix_mx`, `business_id = 2` (Celfix).

**Implicaciones para la app**:
- La API es estable — no hay CI/CD sofisticado; los endpoints no cambian frecuentemente.
- No hay ambiente staging expuesto; existe `dev.celfix.mx` (staging) pero no siempre reflejará prod.
- Cualquier bug del backend requiere ciclo humano de deploy (subir archivo por FTP + SQL manual si aplica).

---

## 3. Estructura de la API

### URL base
```
https://pos.celfix.mx/api/v1
```

### Convenciones

- **Content-Type**: `application/json`
- **Charset**: UTF-8 (MX = ñ, acentos)
- **Formato respuesta OK**:
  ```json
  { "success": true, ... }
  ```
- **Formato respuesta error**:
  ```json
  { "success": false, "message": "..." }
  ```
- **Códigos HTTP**:
  - `200` — OK
  - `401` — no autenticado (bearer inválido o faltante)
  - `404` — recurso no encontrado (o no pertenece al cliente)
  - `422` — validación fallida
  - `429` — rate limit excedido (solo login)
  - `500` — error servidor

### Auth (bearer token)

- Headers protegidos:
  ```
  Authorization: Bearer <token>
  Accept: application/json
  ```
- El token viene de `POST /auth/login` en el campo `token` de la respuesta.
- El token se guarda en la BD **hasheado** (SHA-256) en `contacts.app_api_token`. El plaintext solo existe en la app.
- Un solo token vivo por cliente — si hace login desde otro dispositivo, el token viejo se invalida.
- **Guardar el token en `flutter_secure_storage`** (NO en SharedPreferences plano).

### Rate limits

- `POST /auth/login`: 5 intentos por minuto por IP.
- Resto de endpoints: sin límite explícito de app (Laravel default `throttle:60,1` a nivel middleware `api`).

---

## 4. Endpoints — referencia completa

### 4.1 Públicos (sin auth)

#### `GET /api/v1/locations`

Sucursales visibles en la app.

Respuesta:
```json
{
  "success": true,
  "data": [
    {
      "id": 6,
      "name": "Sucursal Americas",
      "address": "Blvd. Las Américas, Mexicali, 21100",
      "phone": "6861234567",
      "hours": {
        "mon": {"open": "09:00", "close": "20:00"},
        "tue": {"open": "09:00", "close": "20:00"},
        "sun": {"closed": true}
      },
      "latitude": 32.6541,
      "longitude": -115.4681,
      "maps_url": "https://www.google.com/maps/search/?api=1&query=32.6541,-115.4681"
    }
  ]
}
```

Notas:
- Solo devuelve sucursales con `is_public_in_app = 1` (marcado por admin en `/app-config/locations`).
- `hours` es un objeto keyed por día (`mon`, `tue`, `wed`, `thu`, `fri`, `sat`, `sun`). Cada día puede ser `{open, close}` o `{closed: true}`.
- `maps_url` viene pre-construido — la app solo lo abre con `url_launcher`.

#### `GET /api/v1/promos?location_id={id}`

Promos activas y vigentes.

Query params:
- `location_id` (opcional): si se pasa, devuelve globales + de esa sucursal. Sin param → solo globales.

Respuesta:
```json
{
  "success": true,
  "data": [
    {
      "id": 12,
      "title": "2x1 en micas de vidrio",
      "description": "Todos los modelos iPhone y Samsung",
      "category": "accesorios",
      "starts_at": "2026-08-15",
      "ends_at": "2026-08-31",
      "target_location_id": null,
      "image_url": "https://pos.celfix.mx/storage/promos/2x1-micas.jpg"
    }
  ]
}
```

Notas:
- Filtrado server-side por fecha (`starts_at <= today <= ends_at`) e `is_active = 1`.
- `image_url` puede ser `null` si no se subió imagen.
- Orden: `sort_order ASC, id DESC`.

#### `GET /api/v1/benefits?location_id={id}`

Beneficios permanentes de la membresía.

Query params: mismo comportamiento que promos.

Respuesta:
```json
{
  "success": true,
  "data": [
    {
      "id": 3,
      "title": "10% descuento en reparaciones",
      "description": "Al presentar tu membresía",
      "value_type": "percentage",
      "value": 10.0,
      "value_text": null,
      "display_value": "10%",
      "min_purchase": 0,
      "conditions": "No acumulable con otras promociones",
      "target_location_id": null
    }
  ]
}
```

Notas:
- `value_type` puede ser: `percentage`, `fixed`, `text`.
- `display_value` viene pre-formateado por el backend (`"10%"`, `"$50 MXN"`, `"Producto GRATIS"`) — la app solo lo muestra.

---

### 4.2 Auth

#### `POST /api/v1/auth/register`

Body:
```json
{
  "mobile": "6861234567",
  "name": "Juan Pérez",
  "password": "miPass123",
  "password_confirmation": "miPass123"
}
```

Público, rate-limitado a **3 intentos/min por IP** para frenar registros masivos.

**Comportamiento:**

- **Cliente nuevo** (mobile no está en el POS) → crea el Contact como customer del business 2, genera bearer token y auto-login:

  ```json
  // HTTP 201
  {
    "success": true,
    "message": "Registro exitoso. Bienvenido a Celfix Socios.",
    "token": "abc123...60 chars",
    "customer": {
      "id": 42,
      "name": "Juan Pérez",
      "mobile": "6861234567",
      "email": null,
      "membership_no": "9001000042",
      "membership_expires_at": null
    }
  }
  ```

  El `membership_no` se auto-genera por el hook `booted()` del modelo Contact.

- **Cliente ya registrado** (mobile ya existe) → devuelve `409 Conflict`:

  ```json
  // HTTP 409
  {
    "success": false,
    "code": "already_registered",
    "message": "Este número ya está registrado. Te enviaremos un SMS para recuperar el acceso."
  }
  ```

  El backend **loguea la intención** de enviar SMS (`storage/logs/laravel.log`) — hoy es SIMULADO, sin envío real. Cuando se contrate Twilio (o equivalente) se activa el envío. No se revela información privada del cliente existente.

- **Validaciones (HTTP 422):**
  - `mobile` < 10 dígitos → "Ingresa un teléfono válido de 10 dígitos."
  - `name` vacío → "El nombre es obligatorio."
  - `password` < 6 chars → "La contraseña debe tener al menos 6 caracteres."
  - `password ≠ password_confirmation` → "La confirmación de la contraseña no coincide."

**Flow sugerido en la app:**

1. Usuario llena teléfono, nombre y password
2. POST `/register`
3. Si `201` → guardar `token`, ir a Home
4. Si `409 already_registered` → mostrar mensaje "Ya está registrado — te enviamos SMS" y llevar a pantalla de login (o esperar el OTP cuando la Fase 2 esté lista)
5. Si `422` → mostrar el `message` como error de formulario
6. Si `429` → "Demasiados intentos, espera un minuto"

#### `POST /api/v1/auth/login`

Body:
```json
{ "mobile": "6861234567", "password": "password1" }
```

Respuesta OK:
```json
{
  "success": true,
  "token": "abc123...60 chars random",
  "customer": {
    "id": 42,
    "name": "Juan Pérez",
    "mobile": "6861234567",
    "email": "juan@example.com",
    "membership_no": "9001000042",
    "membership_expires_at": "2027-08-19"
  }
}
```

Respuesta fallida:
```json
{ "success": false, "message": "Credenciales inválidas." }
```
HTTP 401 en cualquier fallo (mobile no existe, password mala, cliente sin password asignada).

**Normalización de mobile (importante)**:
- El backend acepta `"+52 (686) 123-4567"`, `"686-123-4567"`, `"6861234567"` — internamente se limpia a solo dígitos y matchea por los últimos 10.
- La app debe permitir que el user escriba en cualquier formato; NO forzar formato específico en el input.

**Password inicial**:
- Todos los clientes existentes al momento del backfill tienen password `"password1"`.
- Los clientes deben cambiarla con `/auth/change-password` después del primer login.
- La app debe **detectar si el user aún tiene la password default** y sugerir el cambio (opcional).

#### `POST /api/v1/auth/logout`

Headers: `Authorization: Bearer <token>`

Sin body.

Respuesta:
```json
{ "success": true, "message": "Sesión cerrada." }
```

Invalida el token en la BD. Después de logout, el token no sirve para más requests.

#### `POST /api/v1/auth/change-password`

Headers: `Authorization: Bearer <token>`

Body:
```json
{
  "current_password": "password1",
  "new_password": "miNueva123",
  "new_password_confirmation": "miNueva123"
}
```

Respuesta OK:
```json
{
  "success": true,
  "message": "Contraseña actualizada.",
  "token": "<nuevo bearer token>"
}
```

Validaciones (fallan con 422):
- Faltantes → `"Faltan campos."`
- `new_password` < 6 chars → `"La nueva contraseña debe tener al menos 6 caracteres."`
- `new != confirmation` → `"La confirmación no coincide."`
- `current` incorrecta → `401` `"La contraseña actual es incorrecta."`
- `new == current` → `422` `"La nueva contraseña debe ser distinta a la actual."`

**Importante**: al cambiar exitosamente, el **token se rota**. La app debe:
1. Descartar el token viejo.
2. Guardar el nuevo `token` de la respuesta.
3. Sesiones activas en otros dispositivos quedan invalidadas automáticamente.

---

### 4.3 Perfil y datos personales (bearer)

Todos requieren `Authorization: Bearer <token>`.

#### `GET /api/v1/me`

Perfil del cliente autenticado.

Respuesta:
```json
{
  "success": true,
  "customer": {
    "id": 42,
    "name": "Juan Pérez",
    "mobile": "6861234567",
    "email": "juan@example.com",
    "membership_no": "9001000042",
    "membership_expires_at": "2027-08-19"
  }
}
```

Notas:
- `membership_no` es el ID de membresía (10 dígitos: `9001` + id con padding).
- **Usa este número para el QR de identificación** en el mostrador.
- `membership_expires_at` puede ser `null` (membresía vitalicia o no asignada).

#### `GET /api/v1/purchases?page=N`

Historial paginado (20 por página, ordenado por fecha desc).

Query params:
- `page` (default: 1)

Respuesta:
```json
{
  "success": true,
  "data": [
    {
      "id": 143983,
      "invoice_no": "81675",
      "date": "2026-08-18",
      "time": "17:44",
      "location": "Sucursal Villa Fontana",
      "total": 150.00,
      "paid": 150.00,
      "balance": 0,
      "items_count": 1,
      "is_repair": false,
      "repair_status": null
    }
  ],
  "pagination": {
    "current": 1,
    "per_page": 20,
    "total": 87,
    "last": 5
  }
}
```

Notas:
- `is_repair = true` cuando la compra tiene `repair_status` (reparación).
- `balance > 0` significa que el cliente aún debe dinero (típico en reparación pending).
- `items_count` es la cantidad de líneas (no la suma de cantidades).

#### `GET /api/v1/purchases/{id}`

Detalle de una compra específica.

Respuesta:
```json
{
  "success": true,
  "purchase": {
    "id": 143983,
    "invoice_no": "81675",
    "date": "2026-08-18 17:44:00",
    "location": "Sucursal Villa Fontana",
    "total": 150.00,
    "discount_amount": 0,
    "tax_amount": 0,
    "paid": 150.00,
    "balance": 0,
    "notes": "Cliente pidió factura",
    "is_repair": false,
    "repair_status": null,
    "repair_delivered_at": null,
    "items": [
      {
        "product_name": "Mica de Vidrio iPhone 15 Pro",
        "sku": "CF-MICA-IP15P",
        "quantity": 1,
        "unit_price": 150.00,
        "subtotal": 150.00,
        "quantity_returned": 0
      }
    ],
    "payments": [
      {
        "method": "cash",
        "amount": 150.00,
        "is_return": false,
        "paid_on": "2026-08-18 17:44:00"
      }
    ]
  }
}
```

Errores:
- `404` si el `id` no existe o pertenece a otro cliente (no revela cuál).

Notas:
- `payments[].method`: `cash`, `card`, `bank_transfer`, `cheque`.
- `payments[].is_return = true` es cambio devuelto (vuelto), no un pago.
- `items[].quantity_returned > 0` si el cliente devolvió parte del producto.

#### `GET /api/v1/repair-orders?status={pending|delivered|all}`

Órdenes de reparación del cliente. Default `status=all`.

Respuesta:
```json
{
  "success": true,
  "data": [
    {
      "id": 12345,
      "invoice_no": "81488",
      "date": "2026-08-14",
      "location": "Sucursal Villa Fontana",
      "status": "pending",
      "status_label": "En reparación",
      "delivered_at": null,
      "total": 500.00,
      "paid": 200.00,
      "balance": 300.00,
      "products": "Reparación pantalla iPhone 12",
      "notes": "Cliente reporta que no enciende"
    }
  ]
}
```

Notas:
- `status`: `pending` (recibida, en reparación) o `delivered` (entregada).
- `status_label` viene traducido al español.
- `delivered_at` es `null` en pendings; timestamp cuando `status = delivered`.
- `balance` es lo que el cliente aún debe al recoger el equipo.
- `products` es la concatenación de nombres de líneas del ticket (equipo + refacciones + servicios).

---

## 5. Modelo de datos relevante

### Tabla `contacts` (clientes)

Columnas relevantes para la app:

| Columna | Tipo | Uso |
|---|---|---|
| `id` | int | PK |
| `business_id` | int | Siempre `2` para Celfix |
| `type` | enum | `customer`, `supplier`, `both` — la API solo acepta `customer`/`both` |
| `name` | varchar | Nombre completo |
| `first_name`, `last_name` | varchar | Alternos (fallback si `name` está vacío) |
| `mobile` | varchar | Teléfono principal (match de login) |
| `alternate_number` | varchar | Teléfono alterno (también matched en login) |
| `email` | varchar | Puede ser null |
| `membership_no` | varchar | Auto-generado: `"9001" + id con padding a 6` |
| `membership_expires_at` | date | Nullable |
| `app_password` | varchar (bcrypt) | Hash de la contraseña de la app |
| `app_api_token` | varchar(64) | SHA-256 del bearer token vivo (o `null`) |
| `deleted_at` | timestamp | Soft delete (Eloquent lo excluye por default) |

### Tabla `transactions` (ventas y reparaciones)

Una reparación es una transaction con `type='sell'` + `repair_status IS NOT NULL`.

| Columna | Uso en app |
|---|---|
| `id`, `invoice_no`, `transaction_date` | ID interno, folio para mostrar al cliente, fecha |
| `contact_id` | FK a `contacts.id` (dueño de la compra) |
| `location_id` | FK a `business_locations.id` |
| `type` | `sell`, `sell_return`, `purchase`, etc. La API solo devuelve `sell` |
| `status` | `final`, `draft`, `cancelled`, `suspended` |
| `final_total` | Total con impuestos y descuentos |
| `repair_status` | `null` (venta normal), `pending`, `delivered` |
| `repair_delivered_at` | timestamp cuando se entregó la reparación |

### Tablas de payloads secundarias

- `transaction_sell_lines` → items de cada venta (`product_id`, `variation_id`, `quantity`, `unit_price_inc_tax`)
- `transaction_payments` → pagos (`method`, `amount`, `is_return`, `paid_on`)
- `business_locations` → sucursales (`id`, `name`, columnas custom Celfix: `is_public_in_app`, `hours_json`, `latitude`, `longitude`, `phone_app`)
- `app_promos`, `app_benefits` → contenido gestionado desde `/app-config` en el admin

---

## 6. Consideraciones críticas

### `business_id = 2` está hardcoded

Todos los endpoints filtran por `business_id = 2` (Celfix). Si algún día hubiera otra cadena, hay que refactorizar el backend. La app **no envía** este campo; se asume.

### Timezone

- El server MySQL corre en **UTC**.
- Laravel corre con `APP_TIMEZONE=America/Los_Angeles` (equivalente a Tijuana/Mexicali sin DST del lado de MX).
- Las fechas devueltas por la API vienen en formato **ISO / MySQL datetime** en zona local Mexicali (no UTC).
- Ejemplo: `"2026-08-18 17:44:00"` = 5:44 PM hora Mexicali.
- La app debería mostrarlas tal cual (no hacer conversión de timezone salvo que use `intl` para formateo).

### Normalización de mobile en login

El backend hace el match por los últimos 10 dígitos. Si el user escribe `"+52 686 123 4567"` o `"6861234567"`, ambos matcheanel mismo contact. La app **no debe validar formato estricto** en el input de mobile.

### Errores 401 → forzar re-login

Cualquier request protegido que devuelva 401 significa:
- Token expirado (si algún día se agrega expiración; hoy no expiran)
- Cliente hizo logout desde otro dispositivo
- Cambió password en otro dispositivo

La app debe:
1. Descartar el token guardado
2. Redirigir a la pantalla de login
3. Mostrar mensaje "Tu sesión expiró, ingresa de nuevo"

### Errores 404 en `purchases/{id}` y `repair-orders`

No siempre significan "no existe". Puede significar "existe pero es de otro cliente" — el backend lo trata igual para no filtrar información. La app trata todos los 404 como "no disponible".

### Cache local

**No cachees agresivamente**:
- **Sucursales, promos, beneficios**: cache 15-30 min OK (contenido cambia lento).
- **Perfil, compras, reparaciones**: no cachear más de 5 min — el user espera datos actuales.
- **Al abrir la app siempre pull-to-refresh** las pantallas de datos personales.

### Sin CORS explícito

El backend NO tiene headers CORS agregados. Para app nativa iOS/Android eso NO es problema (no hay CORS). Pero si algún día se hace Flutter Web, hay que agregar `laravel-cors` al backend.

### La API no tiene versionado real

`v1` es solo un prefijo de URL, no un contrato versionado. Si algún día se rompe compatibilidad, la app vieja fallará. Considera:
- Enviar un header `X-App-Version` en cada request desde Flutter.
- El backend puede rechazar versiones muy viejas con 426 "Upgrade Required".

Este contrato **aún no está implementado**. Agrégalo si escala el proyecto.

---

## 7. Cosas que NO existen en la API (aún)

Estos endpoints **NO** existen y hay que agregarlos si la app los necesita:

| Endpoint | Uso pendiente |
|---|---|
| `POST /auth/request-otp` + `verify-otp` | Recuperar contraseña vía SMS (Twilio) |
| `GET /membership/qr` | QR/barcode del membership_no (opcional — se puede generar client-side) |
| `POST /device-token` | Guardar FCM token para push |
| `GET /notifications` | Historial de notificaciones al cliente |
| `POST /appointments` | Agendar cita de reparación |
| `GET /points` | Consulta de puntos de fidelidad (`rp_earned` del contact) |

Si necesitas alguno de estos, avísale a la persona que mantiene el backend — hay que:
1. Crear controller en `app/Http/Controllers/Api/V1/`
2. Agregar ruta en `routes/api.php`
3. (Si aplica) migración SQL para columnas nuevas
4. Deploy manual a prod (FTP + SQL)

---

## 8. Stack sugerido para la app Flutter

### Paquetes recomendados

| Paquete | Para qué |
|---|---|
| `dio` o `http` | HTTP client (dio preferido por interceptors) |
| `flutter_secure_storage` | Guardar bearer token de forma segura |
| `provider` o `riverpod` | State management |
| `go_router` | Navegación declarativa |
| `intl` | Formato de fechas / números en es-MX |
| `url_launcher` | Abrir Google Maps con `maps_url` |
| `qr_flutter` | Generar QR del membership_no |
| `pull_to_refresh` | Refrescar pantallas |
| `cached_network_image` | Imágenes de promos |
| `firebase_messaging` | Push notifications (fase 2) |
| `flutter_svg` | Íconos y assets vectoriales |

### Arquitectura sugerida

```
lib/
├── api/
│   ├── api_client.dart         (Dio + interceptor de auth)
│   ├── auth_api.dart
│   ├── customer_api.dart
│   ├── public_api.dart
│   └── models/
│       ├── customer.dart
│       ├── location.dart
│       ├── promo.dart
│       ├── benefit.dart
│       ├── purchase.dart
│       ├── purchase_detail.dart
│       └── repair_order.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── home_screen.dart        (tabs: sucursales, promos, beneficios, perfil)
│   ├── locations_tab.dart
│   ├── promos_tab.dart
│   ├── benefits_tab.dart
│   ├── profile_tab.dart
│   ├── change_password_screen.dart
│   ├── purchases_screen.dart
│   ├── purchase_detail_screen.dart
│   └── repair_orders_screen.dart
├── state/
│   ├── auth_provider.dart
│   └── theme_provider.dart
├── utils/
│   ├── secure_storage.dart
│   └── formatters.dart
└── main.dart
```

### Ejemplo de ApiClient (Dio)

```dart
class ApiClient {
  final Dio _dio;
  final SecureStorage _storage;

  ApiClient(this._storage)
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://pos.celfix.mx/api/v1',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401) {
          await _storage.clearToken();
          // Navigator global → login screen
        }
        return handler.next(err);
      },
    ));
  }

  Dio get dio => _dio;
}
```

### Ejemplo de auth flow

```dart
// Login
Future<Customer> login(String mobile, String password) async {
  final r = await _api.dio.post('/auth/login', data: {
    'mobile': mobile,
    'password': password,
  });
  if (r.data['success'] == true) {
    await _storage.saveToken(r.data['token']);
    return Customer.fromJson(r.data['customer']);
  }
  throw AuthException(r.data['message'] ?? 'Error de autenticación');
}

// Change password (rota token — hay que guardarlo)
Future<void> changePassword(String current, String next) async {
  final r = await _api.dio.post('/auth/change-password', data: {
    'current_password': current,
    'new_password': next,
    'new_password_confirmation': next,
  });
  if (r.data['success'] == true) {
    await _storage.saveToken(r.data['token']); // token rotado
  }
}
```

---

## 9. Testing y debugging

### Cuenta de prueba

- **Mobile**: cualquier `contacts.mobile` de la BD de prod (pregunta al mantenedor por uno de prueba).
- **Password inicial**: `password1` para todos los clientes existentes.
- **Endpoint de prueba rápida (público)**:
  ```
  curl https://pos.celfix.mx/api/v1/locations
  ```

### Errores comunes al integrar

| Síntoma | Causa probable |
|---|---|
| `401 Credenciales inválidas` con mobile correcto | El cliente no tiene `app_password` asignada (contactar admin) |
| `404` al pedir una compra que sí existe | La compra no pertenece al cliente autenticado |
| `429 Too Many Attempts` en login | Ejecutaste 5+ intentos de login en 1 min desde la misma IP |
| Fecha con offset raro | El server responde en zona Mexicali sin `Z` (no UTC); no conviertas timezone |
| `token` no funciona al segundo request | Otro dispositivo hizo login con el mismo cliente (invalidó el anterior) |

### Postman collection

Aún no existe una collection oficial. Puedes armar una manual con los endpoints de este doc.

---

## 10. Recomendación de orden para MVP

1. **Setup Flutter + navegación básica** (login → home con 4 tabs)
2. **Login + guardar token** (`/auth/login`, `flutter_secure_storage`)
3. **Interceptor 401 → logout automático**
4. **Tab Sucursales** con `/locations` + Google Maps + `url_launcher`
5. **Tab Promos** con `/promos?location_id=X` (dropdown de sucursal opcional)
6. **Tab Beneficios** con `/benefits`
7. **Tab Perfil** con `/me` + QR del `membership_no` (`qr_flutter`)
8. **Botón cambiar contraseña** → `/auth/change-password` + actualizar token
9. **Pantalla Historial** con `/purchases?page=N` + pull-to-refresh + paginación
10. **Detalle compra** con `/purchases/{id}`
11. **Pantalla Reparaciones** con `/repair-orders?status=pending`

Una vez el MVP esté en tienda, el mantenedor del backend agregará:
- Registro desde app
- OTP por SMS para recuperar contraseña
- Push notifications
- Otros endpoints según demanda real

---

## 11. Estructura del repo backend (referencia)

Si necesitas mirar el código Laravel:

```
c:\xampp\htdocs\pos.celfix.mx.dev\
├── app/
│   ├── Http/Controllers/Api/V1/
│   │   ├── AuthController.php
│   │   ├── MeController.php
│   │   ├── PublicController.php
│   │   ├── PurchasesController.php
│   │   └── RepairOrdersController.php
│   ├── Http/Middleware/AuthCustomerApi.php
│   ├── Contact.php                 (hook membership_no auto-gen)
│   ├── AppPromo.php
│   ├── AppBenefit.php
│   └── BusinessLocation.php
├── routes/api.php                  (define /api/v1/*)
├── docs/mobile-app/README.md       (ESTE DOCUMENTO)
└── ...
```

Ramas activas:
- `master` — producción
- `feature/pos-improved` — desarrollo (todo merge a master vía fast-forward)

Deploy manual: subir archivos por FTP a hosting cPanel; correr SQL de migración a mano.

---

## 12. Contactos

- **Mantenedor backend**: José Luis Gómez (dueño del POS)
- **Cadena**: Celfix Mexicali, MX

**Fecha de este documento**: 2026-08-20.
