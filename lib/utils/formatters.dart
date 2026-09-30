import 'package:intl/intl.dart';

/// Formateo es-MX.
///
/// Regla de timezone: la API responde en hora Mexicali SIN sufijo `Z`. Al
/// parsearlas obtenemos un DateTime local-naive y lo mostramos tal cual — no
/// hay `toLocal()` en ningún lado a propósito.
class Fmt {
  const Fmt._();

  static final _currency =
      NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 2);
  static final _longDate = DateFormat("d 'de' MMMM 'de' y", 'es_MX');
  static final _shortDate = DateFormat('d MMM y', 'es_MX');
  static final _dateTime = DateFormat("d MMM y, h:mm a", 'es_MX');
  static final _courseDay = DateFormat("EEEE d 'de' MMMM", 'es_MX');
  static final _time = DateFormat('h:mm a', 'es_MX');

  static String money(double value) => _currency.format(value);

  static String longDate(DateTime? date) =>
      date == null ? '—' : _longDate.format(date);

  static String shortDate(DateTime? date) =>
      date == null ? '—' : _shortDate.format(date);

  static String dateTime(DateTime? date) =>
      date == null ? '—' : _dateTime.format(date);

  /// "Miércoles 15 de octubre · 10:00 a. m. a 1:00 p. m."
  ///
  /// Si inicio y fin caen el mismo día, la fecha no se repite.
  static String courseSchedule(DateTime? start, DateTime? end) {
    if (start == null) return 'Fecha por confirmar';

    final day = _capitalize(_courseDay.format(start));
    if (end == null) return '$day · ${_time.format(start)}';

    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (sameDay) {
      return '$day · ${_time.format(start)} a ${_time.format(end)}';
    }
    return '$day ${_time.format(start)} — '
        '${_capitalize(_courseDay.format(end))} ${_time.format(end)}';
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  /// Para strings que ya vienen del backend en formato MySQL datetime.
  static String rawDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : _dateTime.format(parsed);
  }

  static String rawDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : _shortDate.format(parsed);
  }

  /// Cantidades de líneas de venta: "2" en vez de "2.0", "1.5" cuando aplica.
  static String quantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  /// Agrupa el membership_no de 10 dígitos para leerlo en voz alta en caja.
  static String membership(String value) {
    if (value.length != 10) return value;
    return '${value.substring(0, 4)} ${value.substring(4, 7)} ${value.substring(7)}';
  }

  /// Formatea a 10 dígitos solo para MOSTRAR. El input de login nunca se toca:
  /// el backend acepta cualquier formato y matchea por los últimos 10 dígitos.
  static String phone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return value;
    final last10 = digits.substring(digits.length - 10);
    return '(${last10.substring(0, 3)}) ${last10.substring(3, 6)}-${last10.substring(6)}';
  }
}
