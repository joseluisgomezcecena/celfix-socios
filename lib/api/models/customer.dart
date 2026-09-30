import 'json.dart';

class Customer {
  final int id;
  final String name;

  /// Pueden ser null en clientes que ya existían en el POS y nunca
  /// completaron su perfil desde la app.
  final String? firstName;
  final String? lastName;
  final DateTime? dateOfBirth;

  final String mobile;
  final String? email;
  final String membershipNo;
  final DateTime? membershipExpiresAt;

  /// Lo calcula el servidor desde `membership_expires_at`. Es la fuente de
  /// verdad del gating: nunca lo recalculamos en el cliente, porque el reloj
  /// del teléfono puede estar desfasado.
  final bool isPremium;

  final String? photoUrl;

  /// true cuando first_name, last_name y date_of_birth tienen valor. Mientras
  /// sea false la app obliga a completar el perfil.
  final bool profileComplete;

  const Customer({
    required this.id,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.mobile,
    required this.email,
    required this.membershipNo,
    required this.membershipExpiresAt,
    required this.isPremium,
    required this.photoUrl,
    required this.profileComplete,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: asInt(json['id']),
        name: asString(json['name']),
        firstName: asStringOrNull(json['first_name']),
        lastName: asStringOrNull(json['last_name']),
        dateOfBirth: DateTime.tryParse(asString(json['date_of_birth'])),
        mobile: asString(json['mobile']),
        email: asStringOrNull(json['email']),
        membershipNo: asString(json['membership_no']),
        membershipExpiresAt:
            DateTime.tryParse(asString(json['membership_expires_at'])),
        isPremium: asBool(json['is_premium']),
        photoUrl: asStringOrNull(json['photo_url']),
        // Si el backend todavía no manda el campo, lo deducimos de los datos
        // para no bloquear la app contra una versión vieja de la API.
        profileComplete: json.containsKey('profile_complete')
            ? asBool(json['profile_complete'])
            : asStringOrNull(json['first_name']) != null &&
                asStringOrNull(json['last_name']) != null &&
                asStringOrNull(json['date_of_birth']) != null,
      );

  /// null = cliente registrado sin suscripción (no es un error).
  bool get hasExpiry => membershipExpiresAt != null;

  /// Tuvo suscripción y se le venció. Distinto de nunca haber pagado: a este
  /// sí tiene sentido invitarlo a renovar.
  bool get subscriptionLapsed => hasExpiry && !isPremium;

  /// Iniciales para el avatar cuando no hay foto.
  String get initials {
    final source = [firstName, lastName].whereType<String>().toList();
    final parts = source.isNotEmpty ? source : name.split(' ');
    final letters = parts
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part.trim()[0].toUpperCase());
    return letters.isEmpty ? '?' : letters.join();
  }
}
