import 'json.dart';

class Customer {
  final int id;
  final String name;
  final String mobile;
  final String? email;
  final String membershipNo;
  final DateTime? membershipExpiresAt;

  const Customer({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    required this.membershipNo,
    required this.membershipExpiresAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: asInt(json['id']),
        name: asString(json['name']),
        mobile: asString(json['mobile']),
        email: asStringOrNull(json['email']),
        membershipNo: asString(json['membership_no']),
        membershipExpiresAt:
            DateTime.tryParse(asString(json['membership_expires_at'])),
      );

  /// null = membresía vitalicia o sin asignar (no es un error).
  bool get hasExpiry => membershipExpiresAt != null;

  bool get isExpired {
    final expiry = membershipExpiresAt;
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }
}
