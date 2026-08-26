import 'json.dart';

/// Horario de un día. La API manda `{open, close}` o `{closed: true}`.
class DayHours {
  final String? open;
  final String? close;
  final bool closed;

  const DayHours({this.open, this.close, this.closed = false});

  factory DayHours.fromJson(Map<String, dynamic> json) {
    if (asBool(json['closed'])) return const DayHours(closed: true);
    return DayHours(
      open: asStringOrNull(json['open']),
      close: asStringOrNull(json['close']),
    );
  }

  String get label => closed || open == null || close == null
      ? 'Cerrado'
      : '$open - $close';
}

class StoreLocation {
  static const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const dayLabels = {
    'mon': 'Lunes',
    'tue': 'Martes',
    'wed': 'Miércoles',
    'thu': 'Jueves',
    'fri': 'Viernes',
    'sat': 'Sábado',
    'sun': 'Domingo',
  };

  final int id;
  final String name;
  final String? address;
  final String? phone;
  final Map<String, DayHours> hours;
  final double? latitude;
  final double? longitude;
  final String? mapsUrl;

  const StoreLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.hours,
    required this.latitude,
    required this.longitude,
    required this.mapsUrl,
  });

  factory StoreLocation.fromJson(Map<String, dynamic> json) {
    final raw = json['hours'];
    final hours = <String, DayHours>{};
    if (raw is Map) {
      for (final key in dayKeys) {
        final day = raw[key];
        if (day is Map) hours[key] = DayHours.fromJson(day.cast<String, dynamic>());
      }
    }
    return StoreLocation(
      id: asInt(json['id']),
      name: asString(json['name']),
      address: asStringOrNull(json['address']),
      phone: asStringOrNull(json['phone']),
      hours: hours,
      latitude: asDoubleOrNull(json['latitude']),
      longitude: asDoubleOrNull(json['longitude']),
      mapsUrl: asStringOrNull(json['maps_url']),
    );
  }

  /// Horario de hoy. DateTime.weekday es 1=lunes..7=domingo.
  DayHours? get todayHours => hours[dayKeys[DateTime.now().weekday - 1]];
}
