import 'json.dart';

enum RepairFilter {
  all('all', 'Todas'),
  pending('pending', 'En reparación'),
  delivered('delivered', 'Entregadas');

  const RepairFilter(this.value, this.label);
  final String value;
  final String label;
}

class RepairOrder {
  final int id;
  final String invoiceNo;
  final String date;
  final String location;
  final String status;

  /// Ya viene traducido por el backend — no lo re-traducimos.
  final String? statusLabel;
  final String? deliveredAt;
  final double total;
  final double paid;
  final double balance;
  final String? products;
  final String? notes;

  const RepairOrder({
    required this.id,
    required this.invoiceNo,
    required this.date,
    required this.location,
    required this.status,
    required this.statusLabel,
    required this.deliveredAt,
    required this.total,
    required this.paid,
    required this.balance,
    required this.products,
    required this.notes,
  });

  factory RepairOrder.fromJson(Map<String, dynamic> json) => RepairOrder(
        id: asInt(json['id']),
        invoiceNo: asString(json['invoice_no']),
        date: asString(json['date']),
        location: asString(json['location']),
        status: asString(json['status']),
        statusLabel: asStringOrNull(json['status_label']),
        deliveredAt: asStringOrNull(json['delivered_at']),
        total: asDouble(json['total']),
        paid: asDouble(json['paid']),
        balance: asDouble(json['balance']),
        products: asStringOrNull(json['products']),
        notes: asStringOrNull(json['notes']),
      );

  bool get isPending => status == 'pending';
  bool get hasDebt => balance > 0;

  String get displayStatus =>
      statusLabel ?? (isPending ? 'En reparación' : 'Entregada');
}
