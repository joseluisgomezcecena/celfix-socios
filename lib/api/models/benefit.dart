import 'json.dart';

class Benefit {
  final int id;
  final String title;
  final String? description;

  /// En datos reales llega `amount` / `percent` (el doc decía
  /// `percentage`/`fixed`/`text`). No dependemos de estos valores: para mostrar
  /// usamos siempre `displayValue`, que el backend ya formatea.
  final String? valueType;
  final double? value;
  final String? valueText;
  final String? displayValue;
  final double? minPurchase;
  final String? conditions;
  final int? targetLocationId;

  /// Contenido exclusivo de suscriptores. Los no premium igual lo ven, pero
  /// en gris con el aviso de suscripción: es embudo de conversión, no un
  /// filtro.
  final bool isPremium;

  const Benefit({
    required this.id,
    required this.title,
    required this.description,
    required this.valueType,
    required this.value,
    required this.valueText,
    required this.displayValue,
    required this.minPurchase,
    required this.conditions,
    required this.targetLocationId,
    required this.isPremium,
  });

  factory Benefit.fromJson(Map<String, dynamic> json) => Benefit(
        id: asInt(json['id']),
        title: asString(json['title']),
        description: asStringOrNull(json['description']),
        valueType: asStringOrNull(json['value_type']),
        value: asDoubleOrNull(json['value']),
        valueText: asStringOrNull(json['value_text']),
        displayValue: asStringOrNull(json['display_value']),
        minPurchase: asDoubleOrNull(json['min_purchase']),
        conditions: asStringOrNull(json['conditions']),
        targetLocationId: asIntOrNull(json['target_location_id']),
        isPremium: asBool(json['is_premium']),
      );

  bool get isGlobal => targetLocationId == null;
}
