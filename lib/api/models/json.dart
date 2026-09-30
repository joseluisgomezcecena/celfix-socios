/// Helpers de parseo tolerante.
///
/// Laravel serializa los decimales de forma inconsistente: `total` llega como
/// entero JSON (500) en unos casos y podría llegar como string ("500.00") en
/// otros. Un cast directo `as double` revienta con el primero.
double asDouble(Object? value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

double? asDoubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int asInt(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

int? asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String asString(Object? value, {String fallback = ''}) =>
    value?.toString() ?? fallback;

/// Normaliza strings vacíos a null: la API manda "" y null indistintamente.
String? asStringOrNull(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

bool asBool(Object? value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().toLowerCase();
  return text == 'true' || text == '1';
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}

/// Convierte una fecha ISO 8601 **con** offset a la hora de pared que trae.
///
/// El módulo de cursos manda `"2026-10-15T10:00:00-07:00"`, a diferencia del
/// resto de la API que manda fechas sin zona. `DateTime.parse` lo convertiría
/// a UTC (17:00Z) y `toLocal()` lo movería según la zona del teléfono: un
/// socio con el celular en otra zona vería una hora distinta a la que dice el
/// POS. Aquí recortamos el offset y conservamos la hora tal cual la programó
/// el admin, que es lo que va a pasar en la tienda.
DateTime? asWallClock(Object? value) {
  final raw = asStringOrNull(value);
  if (raw == null) return null;

  // Corta la zona final: "Z", "+07:00", "-0700".
  final match = RegExp(r'^(.*?)(?:Z|[+-]\d{2}:?\d{2})$').firstMatch(raw.trim());
  return DateTime.tryParse(match != null ? match.group(1)! : raw);
}
