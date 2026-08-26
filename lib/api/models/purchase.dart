import 'json.dart';

/// Item del listado `/purchases`. Ojo: aquí `date` y `time` vienen SEPARADOS,
/// mientras que en `/purchases/{id}` viene un datetime completo. Son dos shapes
/// distintos a propósito, no un bug.
class Purchase {
  final int id;
  final String invoiceNo;
  final String date;
  final String time;
  final String location;
  final double total;
  final double paid;
  final double balance;
  final int itemsCount;
  final bool isRepair;
  final String? repairStatus;

  const Purchase({
    required this.id,
    required this.invoiceNo,
    required this.date,
    required this.time,
    required this.location,
    required this.total,
    required this.paid,
    required this.balance,
    required this.itemsCount,
    required this.isRepair,
    required this.repairStatus,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: asInt(json['id']),
        invoiceNo: asString(json['invoice_no']),
        date: asString(json['date']),
        time: asString(json['time']),
        location: asString(json['location']),
        total: asDouble(json['total']),
        paid: asDouble(json['paid']),
        balance: asDouble(json['balance']),
        itemsCount: asInt(json['items_count']),
        isRepair: asBool(json['is_repair']),
        repairStatus: asStringOrNull(json['repair_status']),
      );

  /// Sin conversión de timezone: la API responde en hora Mexicali sin sufijo Z.
  DateTime? get dateTime => DateTime.tryParse('$date $time:00');

  /// balance > 0 = el cliente debe. balance < 0 = sobrepago (visto en prod).
  bool get hasDebt => balance > 0;
}

class Pagination {
  final int current;
  final int perPage;
  final int total;
  final int last;

  const Pagination({
    required this.current,
    required this.perPage,
    required this.total,
    required this.last,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        current: asInt(json['current'], fallback: 1),
        perPage: asInt(json['per_page'], fallback: 20),
        total: asInt(json['total']),
        last: asInt(json['last'], fallback: 1),
      );

  bool get hasMore => current < last;
}

class PurchasePage {
  final List<Purchase> items;
  final Pagination pagination;

  const PurchasePage({required this.items, required this.pagination});
}
