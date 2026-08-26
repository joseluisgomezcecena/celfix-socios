import 'json.dart';

class Promo {
  final int id;
  final String title;
  final String? description;
  final String? category;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? targetLocationId;
  final String? imageUrl;

  const Promo({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.startsAt,
    required this.endsAt,
    required this.targetLocationId,
    required this.imageUrl,
  });

  factory Promo.fromJson(Map<String, dynamic> json) => Promo(
        id: asInt(json['id']),
        title: asString(json['title']),
        description: asStringOrNull(json['description']),
        category: asStringOrNull(json['category']),
        startsAt: DateTime.tryParse(asString(json['starts_at'])),
        endsAt: DateTime.tryParse(asString(json['ends_at'])),
        targetLocationId: asIntOrNull(json['target_location_id']),
        imageUrl: asStringOrNull(json['image_url']),
      );

  bool get isGlobal => targetLocationId == null;
}
