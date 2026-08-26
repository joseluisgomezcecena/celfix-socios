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
      );

  bool get isGlobal => targetLocationId == null;
}
