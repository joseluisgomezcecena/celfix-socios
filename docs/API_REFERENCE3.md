# Celfix Socios — App móvil (Flutter) + API

Documento de referencia autosuficiente para desarrollar la app Flutter que consume la API pública del POS de Celfix. Diseñado para pegarse en una sesión nueva de Claude sin contexto previo. Léelo completo antes de escribir código.

---

## 0. Últimas actualizaciones del backend

Cambios recientes visibles para la app. Los detalles están en las secciones correspondientes.

**2026-09-30 — Módulo Cursos**
- Cursos programados desde el POS (App Config → Cursos): fecha/hora, sucursal opcional, capacidad (0 = ilimitado), imagen opcional. Los socios se inscriben desde la app.
- Nuevos endpoints: `GET /courses` (público), `GET /me/courses`, `POST /courses/{id}/enroll`, `DELETE /courses/{id}/enroll` (bearer).
- Nuevas tablas: `app_courses`, `app_course_enrollments`.
- Detalles: sección **4.1** (GET público) y **4.3** (endpoints autenticados).

**2026-09-30 — CORS en /storage/* (Flutter Web only)**
- Web browser bloqueaba imágenes con HTTP 200 pero sin `Access-Control-Allow-Origin`. Fix aplicado del lado backend (server.php + .htaccess). Nada que cambiar en el app; solo actualizar dev/prod. APK Android/iOS no está afectado.

**2026-09-29 — Membresías Premium + gating**
- `customer.is_premium` (bool) en todos los payloads de cliente. Cada item de `/promos` y `/benefits` trae `is_premium`. Items premium se muestran en gris con "Paga tu suscripción para acceder" para no-premium.
- La tarjeta de membresía es una sola para todos (background desde `/app-designs`); premium solo lleva un pill dorado "Premium".
- Detalles: sección **5.5 Premium / Gating**.

**2026-09-29 — Diseños dinámicos**
- Nuevo endpoint `GET /app-designs` con backgrounds subidos desde el POS (hoy: `membership_card_background`). App usa la URL y hace fallback a asset local si la key no viene.
- Detalles: sección **4.1**.

**2026-09-29 — Perfil editable + foto de perfil**
- `PUT /me` (first_name, last_name, date_of_birth obligatorios; email opcional). `POST /me/photo` (multipart) y `DELETE /me/photo`. `customer` ahora trae `first_name`, `last_name`, `date_of_birth`, `photo_url`, `profile_complete`.
- Detalles: sección **4.3**.

---

## 1. Contexto de negocio

- **Celfix** — cadena de retail de celulares en Mexicali, MX. 4 sucursales activas: Sucursal Nuevo Mexicali, Sucursal Americas, Sucursal Villa Fontana, Sucursal Benito Juárez. Almacén Equipos central.
- **Modelo de negocio del app**: "Celfix Socios" — programa de fidelidad para clientes. La app permite:
  - Ver sucursales, promos y beneficios activos (público, sin auth)
  - Ver cursos y talleres programados; inscribirse/cancelar (bearer)
  - Iniciar sesión con teléfono + password
  - Ver perfil (membresía + expiración + is_premium)
  - Editar datos personales y subir foto de perfil (bearer)
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
      "image_url": "https://pos.celfix.mx/storage/promos/2x1-micas.jpg",
      "is_premium": false
    },
    {
      "id": 15,
      "title": "3x2 en fundas premium",
      "description": "Exclusivo para socios Premium",
      "category": "accesorios",
      "starts_at": null,
      "ends_at": null,
      "target_location_id": null,
      "image_url": "https://pos.celfix.mx/storage/promos/3x2-fundas.jpg",
      "is_premium": true
    }
  ]
}
```

Notas:
- Filtrado server-side por fecha (`starts_at <= today <= ends_at`) e `is_active = 1`.
- `image_url` puede ser `null` si no se subió imagen.
- Orden: `sort_order ASC, id DESC`.
- **Aspect ratio recomendado en el admin del POS:** 1200 × 675 px (16:9). Diseña tus cards de promo en Flutter asumiendo ese ratio para consistencia visual. Máx 2 MB.
- **`is_premium`**: si es `true` y el cliente autenticado no es premium (`customer.is_premium == false`), la card se renderiza en escala de grises con overlay "Paga tu suscripción para acceder". Si es premium, se ve normal. Ver **[Sección Premium / Gating](#premium-gating)** más abajo.

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
      "target_location_id": null,
      "is_premium": false
    },
    {
      "id": 7,
      "title": "20% descuento en accesorios",
      "description": "Exclusivo socios Premium",
      "value_type": "percentage",
      "value": 20.0,
      "value_text": null,
      "display_value": "20%",
      "min_purchase": 0,
      "conditions": null,
      "target_location_id": null,
      "is_premium": true
    }
  ]
}
```

Notas:
- `value_type` puede ser: `percentage`, `fixed`, `text`.
- `display_value` viene pre-formateado por el backend (`"10%"`, `"$50 MXN"`, `"Producto GRATIS"`) — la app solo lo muestra.
- **`is_premium`**: mismo tratamiento que en promos — grayed out + overlay "Paga tu suscripción para acceder" cuando el cliente no es premium. Ver **[Premium / Gating](#premium-gating)**.

#### `GET /api/v1/app-designs`

Imágenes y diseños visuales configurables desde el admin del POS (**App Config → Diseños**). Se usan como fondos, logos o assets dinámicos en la app.

Respuesta:
```json
{
  "success": true,
  "designs": {
    "membership_card_background": "https://pos.celfix.mx/storage/app_designs/membership_card_background_ab12cd34.jpg"
  }
}
```

**Keys soportadas actualmente:**

| Key | Uso | Tamaño recomendado | Aspect ratio |
|---|---|---|---|
| `membership_card_background` | Fondo de la tarjeta de membresía (detrás del QR y datos del socio) | 1600 × 1000 px | 16:10 |

**Comportamiento:**

- Si una key NO tiene imagen configurada en el POS, **no aparece en la respuesta**. La app debe usar un fallback local (asset propio del bundle Flutter) cuando la key esté ausente.
- El objeto `designs` es un JSON object (siempre `{}`, nunca `[]`), incluso si está vacío.
- Se puede cachear (por ejemplo con `cached_network_image`) — cuando el admin sube una imagen nueva, la URL cambia (nombre aleatorio) para invalidar el cache automáticamente.

**Ejemplo de uso en Flutter:**

```dart
class AppDesigns {
  final Map<String, String> _designs;
  AppDesigns(this._designs);
  String? get membershipCardBackground => _designs['membership_card_background'];
}

// Al iniciar la app o refrescar
Future<AppDesigns> fetchDesigns() async {
  final r = await _dio.get('/app-designs');
  final map = Map<String, String>.from(r.data['designs'] ?? {});
  return AppDesigns(map);
}

// En el widget de la tarjeta:
final bg = designs.membershipCardBackground;
DecoratedBox(
  decoration: BoxDecoration(
    image: bg != null
      ? DecorationImage(image: CachedNetworkImageProvider(bg), fit: BoxFit.cover)
      : DecorationImage(image: AssetImage('assets/card_bg_default.png'), fit: BoxFit.cover),
    borderRadius: BorderRadius.circular(16),
  ),
  child: ...,  // QR + nombre + membership_no
)
```

**Notas de negocio:**

- Los futuros diseños (logo, splash screen, banner promocional, etc.) se agregan como nuevas keys en el backend sin cambiar el contrato del endpoint.
- El admin del POS ve el tamaño recomendado y aspect ratio en el form de subida (`/app-config/designs`).
- Las imágenes se sirven desde el mismo servidor que el resto de assets (`/storage/app_designs/...`).

#### `GET /api/v1/courses?location_id={id}&include_past=0`

Lista de cursos activos (talleres, capacitaciones, eventos) que Celfix programa desde el POS (**App Config → Cursos**).

Query params:
- `location_id` (opcional): globales + los de esa sucursal. Sin param → todos los activos.
- `include_past` (opcional, `0`|`1`, default `0`): con `1` incluye cursos que ya terminaron. Útil para pantalla de "historial".

Respuesta:
```json
{
  "success": true,
  "data": [
    {
      "id": 4,
      "title": "Curso de reparación básica de celulares",
      "description": "Aprende a diagnosticar problemas comunes de pantalla y batería.",
      "instructor_name": "Ing. Juan Pérez",
      "image_url": "https://pos.celfix.mx/storage/app_courses/repbasica.jpg",
      "target_location_id": null,
      "starts_at": "2026-10-15T10:00:00-07:00",
      "ends_at":   "2026-10-15T13:00:00-07:00",
      "capacity": 20,
      "enrolled_count": 8,
      "spots_left": 12,
      "is_full": false,
      "has_started": false
    }
  ]
}
```

Notas:
- `starts_at` y `ends_at` son ISO 8601 con timezone Mexicali. `has_started = true` cuando el curso ya inició (la inscripción se bloquea; ver `POST /courses/{id}/enroll`).
- `capacity`: **0 significa ilimitado**. Si es `>0` y `enrolled_count >= capacity`, `is_full = true` y `spots_left = 0`.
- `spots_left` es `null` cuando `capacity = 0` (ilimitado); número entero cuando hay tope.
- **`is_enrolled` NO viene en este payload** — se cruza contra `/me/courses` (ver 4.3). Regla sugerida en la UI:
  - Si no autenticado → botón "Iniciar sesión para inscribirte".
  - Si autenticado y NO está en `/me/courses` y no `is_full` y no `has_started` → botón "Inscribirme".
  - Si autenticado y está en `/me/courses` → botón "Cancelar inscripción".
  - Si `is_full` y no inscrito → botón deshabilitado "Cupo lleno".
  - Si `has_started` y no inscrito → deshabilitado "Ya inició".

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
      "membership_expires_at": null,
      "is_premium": false
    }
  }
  ```

  El `membership_no` se auto-genera por el hook `booted()` del modelo Contact.
  Todos los registros nuevos entran como **no premium** (`is_premium: false`, `membership_expires_at: null`); la activación premium se hace desde el POS en **App Config → Membresías Premium**.

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
    "membership_expires_at": "2027-08-19",
    "is_premium": true
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
    "name": "Juan Pérez López",
    "first_name": "Juan",
    "last_name": "Pérez López",
    "mobile": "6861234567",
    "email": "juan@example.com",
    "date_of_birth": "1990-05-15",
    "membership_no": "9001000042",
    "membership_expires_at": "2027-08-19",
    "is_premium": true,
    "photo_url": "https://pos.celfix.mx/storage/customer_photos/42_abc123.jpg",
    "profile_complete": true
  }
}
```

Este payload es el mismo que devuelven `/auth/login`, `/auth/register`, `/auth/change-password` y `/me/photo` (todos incluyen el objeto `customer` completo).

Notas:
- `membership_no` es el ID de membresía (10 dígitos: `9001` + id con padding).
- **Usa este número para el QR de identificación** en el mostrador.
- `membership_expires_at`: fecha ISO `YYYY-MM-DD` en que expira la suscripción premium; `null` = cliente registrado sin suscripción.
- `is_premium` (**boolean**, calculado server-side): `true` si `membership_expires_at != null && membership_expires_at >= hoy`. **Fuente de verdad para gating de contenido premium en la app** (no calcules is_premium en el cliente — pueden desincronizarse las zonas horarias).
- `first_name`, `last_name`, `date_of_birth` pueden ser `null` si el cliente aún no completó su perfil (típicamente clientes existentes en la BD del POS que nunca actualizaron datos desde la app).
- `photo_url` puede ser `null` si aún no subió foto de perfil. Cuando existe, es URL absoluta lista para usar en `Image.network()` de Flutter.
- `profile_complete` es `true` cuando `first_name`, `last_name` y `date_of_birth` tienen valor. **La app debe bloquear el resto de features y forzar al user a completar su perfil cuando esto sea `false`.**

#### `PUT /api/v1/me`

Actualiza los datos personales del cliente.

Rate limit: **20 requests/hora por token** (para evitar spam accidental por autosave/debounce en la app).

Body:
```json
{
  "first_name": "Juan",
  "last_name": "Pérez López",
  "date_of_birth": "1990-05-15",
  "email": "juan@example.com"
}
```

Reglas:
- `first_name`: **requerido**, 1-191 caracteres
- `last_name`: **requerido**, 1-191 caracteres
- `date_of_birth`: **requerido**, formato `YYYY-MM-DD`, entre 1900 y hoy − 13 años
- `email`: opcional. Si viene debe ser un email válido. Enviar `""` (string vacío) para dejarlo en null.

**Nota importante:** el backend sincroniza automáticamente el campo interno `name` de UltimatePOS como `first_name + " " + last_name` para consistencia en tickets, reportes y el POS.

Respuesta OK:
```json
{
  "success": true,
  "message": "Datos actualizados.",
  "customer": { ...payload completo... }
}
```

Respuestas de error (todas `422`):

| Escenario | `message` |
|---|---|
| Falta `first_name` | `"El nombre es obligatorio."` |
| `first_name` > 191 chars | `"El nombre es demasiado largo."` |
| Falta `last_name` | `"Los apellidos son obligatorios."` |
| `last_name` > 191 chars | `"Los apellidos son demasiado largos."` |
| Falta `date_of_birth` | `"La fecha de nacimiento es obligatoria."` |
| DOB en formato incorrecto | `"Fecha de nacimiento inválida. Usa formato YYYY-MM-DD."` |
| DOB con menos de 13 años (edad mínima) | `"Debes tener al menos 13 años para usar la app."` |
| DOB inválida (año < 1900 o parse falla) | `"Fecha de nacimiento inválida."` |
| Email malformado | `"El correo electrónico no es válido."` |

Rate limit excedido → `429`.

**Flow sugerido en la app:**

1. Al hacer login o entrar a la app, revisar `customer.profile_complete`
2. Si es `false`, mostrar pantalla "Completa tu perfil" con los 4 campos (email opcional)
3. Al guardar → `PUT /me` con los datos
4. Si la respuesta trae `customer.profile_complete: true`, desbloquear el resto de la app

#### `POST /api/v1/me/photo`

Sube foto de perfil del cliente.

Rate limit: **10 uploads/hora por token**.

Body: `multipart/form-data` con el campo `photo` (imagen).

Restricciones:
- Máximo **5 MB**
- Formatos: `JPG`, `JPEG`, `PNG`, `WEBP`
- El backend hace resize a máx 800×800 (proporcional) + corrección EXIF + conversión siempre a JPEG calidad 85
- Al subir una nueva foto se **borra automáticamente** la anterior

Respuesta OK:
```json
{
  "success": true,
  "message": "Foto de perfil actualizada.",
  "photo_url": "https://pos.celfix.mx/storage/customer_photos/42_abc123.jpg"
}
```

Errores:

| HTTP | `message` |
|---|---|
| 422 | `"Debes enviar una imagen en el campo \"photo\"."` |
| 422 | `"La imagen no llegó completa. Intenta de nuevo."` |
| 422 | `"La imagen es muy grande (máximo 5 MB)."` |
| 422 | `"Formato no soportado. Usa JPG, PNG o WEBP."` |
| 500 | `"No pudimos procesar la imagen. Intenta con otra."` |
| 500 | `"No pudimos guardar la imagen. Intenta más tarde."` |
| 429 | Rate limit excedido |

**Ejemplo con Dio (Flutter):**

```dart
Future<String> uploadPhoto(File imageFile) async {
  final formData = FormData.fromMap({
    'photo': await MultipartFile.fromFile(
      imageFile.path,
      filename: 'profile.jpg',
      contentType: MediaType('image', 'jpeg'),
    ),
  });
  final r = await _api.dio.post('/me/photo', data: formData);
  if (r.data['success'] == true) {
    return r.data['photo_url'];
  }
  throw Exception(r.data['message'] ?? 'Error subiendo foto');
}
```

Para elegir la imagen desde cámara o galería, usa el package `image_picker`:

```dart
final picker = ImagePicker();
final XFile? picked = await picker.pickImage(
  source: ImageSource.gallery,   // o ImageSource.camera
  imageQuality: 90,               // opcional, para reducir MB antes de subir
);
if (picked != null) {
  final url = await uploadPhoto(File(picked.path));
  // actualiza el estado / customer.photo_url
}
```

#### `DELETE /api/v1/me/photo`

Borra la foto de perfil actual (archivo + campo en BD).

Sin body. Sin rate limit específico.

Respuesta OK:
```json
{
  "success": true,
  "message": "Foto de perfil eliminada.",
  "photo_url": null
}
```

Si el cliente no tenía foto, también devuelve `200` con `photo_url: null`.

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

#### `GET /api/v1/me/courses?include_past=0`

Cursos en los que **el cliente autenticado** está inscrito.

Query params:
- `include_past` (opcional, `0`|`1`, default `0`): con `1` incluye cursos que ya terminaron (historial).

Respuesta:
```json
{
  "success": true,
  "data": [
    {
      "id": 4,
      "title": "Curso de reparación básica de celulares",
      "description": "Aprende a diagnosticar problemas comunes...",
      "instructor_name": "Ing. Juan Pérez",
      "image_url": "https://pos.celfix.mx/storage/app_courses/repbasica.jpg",
      "target_location_id": null,
      "starts_at": "2026-10-15T10:00:00-07:00",
      "ends_at":   "2026-10-15T13:00:00-07:00",
      "has_started": false,
      "has_ended": false
    }
  ]
}
```

Notas:
- Devuelve los mismos campos que `/courses` menos `capacity`/`enrolled_count`/`spots_left` (irrelevantes para el owner).
- La app puede pintar una sección **"Mis cursos"** con estos + acción "Cancelar" mientras `has_started == false`.
- Para saber si un curso del listado público está inscrito por el usuario: cruzar `/courses[].id` contra `/me/courses[].id`.

#### `POST /api/v1/courses/{id}/enroll`

Inscribe al cliente autenticado en el curso.

Headers: `Authorization: Bearer <token>`. Sin body.

Rate-limit: **20 requests / minuto** por cliente.

Respuestas:

- **200 OK — inscripción confirmada:**
  ```json
  { "success": true, "message": "Inscripción confirmada. ¡Nos vemos en el curso!" }
  ```

- **200 OK — ya estaba inscrito (idempotente):**
  ```json
  { "success": true, "message": "Ya estás inscrito en este curso.", "already_enrolled": true }
  ```

- **404** — el curso no existe o está inactivo.
- **409** — cupo lleno (`{"success":false,"message":"Este curso ya está lleno."}`).
- **422** — el curso ya inició (`{"success":false,"message":"Este curso ya inició, no se aceptan más inscripciones."}`).

**Flow sugerido en la app:**
1. Botón "Inscribirme" visible cuando `is_full == false && has_started == false && !isEnrolledLocally`.
2. Tap → POST /enroll.
3. On success → invalidar cache de `/courses` y `/me/courses` para que el botón cambie a "Cancelar".
4. On 409 → mostrar snackbar "Cupo lleno" y refrescar `/courses` para que el UI se actualice.

#### `DELETE /api/v1/courses/{id}/enroll`

Cancela la inscripción del cliente autenticado.

Headers: `Authorization: Bearer <token>`. Sin body.

Respuestas:
- **200 OK** — `{"success":true,"message":"Inscripción cancelada."}`
- **404** — no estaba inscrito, o el curso no existe.
- **422** — el curso ya inició (no se permite cancelar retroactivamente).

Después de cancelar, refrescar `/courses` y `/me/courses` para reflejar el cupo liberado.

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
| `first_name`, `last_name` | varchar | Nombres del cliente. Editables desde la app vía `PUT /me`. El backend mantiene `name` sincronizado como `first_name + " " + last_name`. |
| `dob` | date | Fecha de nacimiento. Editable desde la app. Obligatorio para que `profile_complete` sea `true`. |
| `mobile` | varchar | Teléfono principal (match de login) |
| `alternate_number` | varchar | Teléfono alterno (también matched en login) |
| `email` | varchar | Opcional. Editable desde la app. |
| `membership_no` | varchar | Auto-generado: `"9001" + id con padding a 6` |
| `membership_expires_at` | date | Nullable. Fecha de expiración de la suscripción premium. Un cliente es premium cuando esta fecha existe y `>= hoy`. Gestionado desde el POS: **App Config → Membresías Premium**. Ver **[Premium / Gating](#premium-gating)**. |
| `app_password` | varchar (bcrypt) | Hash de la contraseña de la app |
| `app_api_token` | varchar(64) | SHA-256 del bearer token vivo (o `null`) |
| `photo_path` | varchar(255) | Path relativo al disk `public` de la foto de perfil (ej. `customer_photos/42_abc123.jpg`). El backend devuelve la URL absoluta ya construida en `customer.photo_url`. |
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
- `app_promos`, `app_benefits` → contenido gestionado desde `/app-config` en el admin. Ambas tablas tienen columna `is_premium TINYINT(1) NOT NULL DEFAULT 0` que la API expone tal cual.
- `app_courses`, `app_course_enrollments` → cursos programados desde `/app-config/courses`. `app_course_enrollments` tiene UNIQUE `(course_id, contact_id)` para evitar doble inscripción; ON DELETE CASCADE al borrar el curso.

---

<a id="premium-gating"></a>
## 5.5 Premium / Gating de contenido

### Modelo de suscripción

Celfix distingue dos tipos de clientes:

| Tipo | `is_premium` | Cómo se convierte |
|---|---|---|
| **Registrado** | `false` | Auto-registro desde la app (`POST /auth/register`). Todos empiezan aquí. |
| **Premium** | `true` | Pagó suscripción anual en tienda. Un admin lo activa en el POS (**App Config → Membresías Premium**). Dura 1 año exacto. |

- La fuente de verdad es la columna `contacts.membership_expires_at` (DATE, nullable).
- El backend calcula `is_premium = membership_expires_at != null && membership_expires_at >= today` y lo devuelve en **cada** payload de `customer` (login, register, /me, change-password, upload/delete de foto, PUT /me).
- La app **NUNCA debe calcular is_premium en el cliente** — si el reloj del teléfono está desincronizado o hay TZ distintas, se rompe. Confiar solo en el bool que devuelve el servidor.

### Contenido con flag `is_premium`

`GET /api/v1/promos` y `GET /api/v1/benefits` incluyen `is_premium: bool` en cada item.

**Regla de UX:**
- Cliente **premium** (`customer.is_premium == true`) → ve TODOS los items normales.
- Cliente **no premium** (`customer.is_premium == false`) → los items con `is_premium: true` se muestran **grayed out (escala de grises + opacidad ~50%)** con un overlay/pill que dice **"Paga tu suscripción para acceder"**.
- **No filtrar del lado del cliente** — los items premium DEBEN mostrarse (grised) para que los no-premium sepan que existe algo por lo que pagar. Es un funnel de conversión.

### Snippet Flutter sugerido

```dart
Widget premiumWrapper({
  required bool isPremiumItem,
  required bool userIsPremium,
  required Widget child,
}) {
  if (!isPremiumItem || userIsPremium) return child;

  return Stack(
    children: [
      // Contenido en gris y bajado de opacidad
      ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: Opacity(opacity: 0.55, child: child),
      ),
      // Overlay con call-to-action
      Positioned.fill(
        child: Container(
          alignment: Alignment.center,
          color: Colors.black26,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text('Paga tu suscripción para acceder',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
```

### Refrescar el estado premium

Cuando el admin activa/renueva/cancela una membresía en el POS, el cliente sigue viendo su valor cacheado hasta que la app le pida a `/me` de nuevo. **Recomendación:** llamar `GET /me` al abrir la app y al hacer pull-to-refresh en Home. No es necesario polling agresivo — cambia raramente.

### Tarjeta de membresía (importante)

La tarjeta de membresía es **una sola** para todos los socios — registrados y premium. El background se sube desde el POS (`membership_card_background`) y sirve para ambos tipos; **no** rendericen un diseño distinto para premium.

Diferencia visible entre los dos:
- **Premium** (`customer.is_premium == true`) → misma tarjeta + **pill/badge dorado "Premium"** encima (ej. arriba a la derecha o sobre el borde). Sugerido: fondo `#f0ad4e`, texto blanco, icono estrella (mismo tratamiento que usa el admin del POS en el listado).
- **Registrado no premium** → misma tarjeta, sin la pill.

Por qué: el diseño de la tarjeta es marca única de Celfix Socios; el "premium" es un modificador visual, no un rediseño. Si un cliente paga la suscripción, la única diferencia visual es que aparece la pill dorada — el resto (QR, nombre, `membership_no`, fondo) es idéntico.

### Endpoints admin (solo referencia — no las consume la app)

Estos viven en el POS bajo `App Config → Membresías Premium` y NO están en `/api/v1`:

- `GET  /app-config/memberships` — pantalla admin
- `GET  /app-config/memberships/search?q=…` — autocomplete AJAX
- `POST /app-config/memberships/{id}/activate` — fija `expires_at = hoy + 1 año`
- `POST /app-config/memberships/{id}/renew` — extiende 1 año desde su fecha vigente (o desde hoy si expiró)
- `POST /app-config/memberships/{id}/cancel` — `expires_at = null` (efecto inmediato)

Duración fija: 12 meses (constante `MembershipController::DURATION_MONTHS`).

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
| `GET /membership/qr` | QR/barcode del membership_no (opcional — se puede generar client-side con `qr_flutter` a partir de `customer.membership_no`) |
| `POST /device-token` | Guardar FCM token para push |
| `GET /notifications` | Historial de notificaciones al cliente |
| `POST /appointments` | Agendar cita de reparación |
| `GET /points` | Consulta de puntos de fidelidad (`rp_earned` del contact) |

**Ya implementados** (para referencia — hay documentación completa arriba):
- `POST /auth/register` (registro con simulación SMS)
- `POST /auth/forgot-password` (recuperación por WhatsApp, con provider stub/meta)
- `PUT /me` (actualizar first_name, last_name, date_of_birth, email)
- `POST /me/photo` + `DELETE /me/photo` (foto de perfil con cámara/galería)

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
| `cached_network_image` | Imágenes de promos + foto de perfil (con placeholder mientras carga) |
| `image_picker` | Elegir foto desde cámara o galería (upload a `POS /me/photo`) |
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
