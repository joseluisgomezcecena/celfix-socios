/// Imágenes que el admin sube desde el POS (App Config → Diseños).
///
/// Una key ausente significa "sin imagen configurada": la app cae a su propio
/// diseño local. Por eso todo aquí es nullable y nunca se asume que exista.
class AppDesigns {
  final Map<String, String> _designs;

  const AppDesigns(this._designs);

  const AppDesigns.empty() : _designs = const {};

  factory AppDesigns.fromJson(Map<String, dynamic> json) {
    final raw = json['designs'];
    if (raw is! Map) return const AppDesigns.empty();
    final designs = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value?.toString();
      if (value != null && value.isNotEmpty) {
        designs[entry.key.toString()] = value;
      }
    }
    return AppDesigns(designs);
  }

  /// Fondo de la tarjeta de membresía. 1600 × 1000 px, 16:10.
  String? get membershipCardBackground => _designs['membership_card_background'];

  bool get isEmpty => _designs.isEmpty;
}
