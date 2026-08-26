import 'json.dart';

class PurchaseItem {
  final String productName;
  final String? sku;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final double quantityReturned;

  const PurchaseItem({
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.quantityReturned,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        productName: asString(json['product_name']),
        sku: asStringOrNull(json['sku']),
        quantity: asDouble(json['quantity']),
        unitPrice: asDouble(json['unit_price']),
        subtotal: asDouble(json['subtotal']),
        quantityReturned: asDouble(json['quantity_returned']),
      );

  bool get hasReturn => quantityReturned > 0;
}

class PurchasePayment {
  final String method;
  final double amount;

  /// true = vuelto entregado al cliente, NO un pago recibido.
  final bool isReturn;
  final String? paidOn;

  const PurchasePayment({
    required this.method,
    required this.amount,
    required this.isReturn,
    required this.paidOn,
  });

  factory PurchasePayment.fromJson(Map<String, dynamic> json) =>
      PurchasePayment(
        method: asString(json['method']),
        amount: asDouble(json['amount']),
        isReturn: asBool(json['is_return']),
        paidOn: asStringOrNull(json['paid_on']),
      );

  static const _methodLabels = {
    'cash': 'Efectivo',
    'card': 'Tarjeta',
    'bank_transfer': 'Transferencia',
    'cheque': 'Cheque',
  };

  String get methodLabel => _methodLabels[method] ?? method;
}

class PurchaseDetail {
  final int id;
  final String invoiceNo;
  final String date;
  final String location;
  final double total;
  final double discountAmount;
  final double taxAmount;
  final double paid;
  final double balance;
  final String? notes;
  final bool isRepair;
  final String? repairStatus;
  final String? repairDeliveredAt;
  final List<PurchaseItem> items;
  final List<PurchasePayment> payments;

  const PurchaseDetail({
    required this.id,
    required this.invoiceNo,
    required this.date,
    required this.location,
    required this.total,
    required this.discountAmount,
    required this.taxAmount,
    required this.paid,
    required this.balance,
    required this.notes,
    required this.isRepair,
    required this.repairStatus,
    required this.repairDeliveredAt,
    required this.items,
    required this.payments,
  });

  factory PurchaseDetail.fromJson(Map<String, dynamic> json) => PurchaseDetail(
        id: asInt(json['id']),
        invoiceNo: asString(json['invoice_no']),
        date: asString(json['date']),
        location: asString(json['location']),
        total: asDouble(json['total']),
        discountAmount: asDouble(json['discount_amount']),
        taxAmount: asDouble(json['tax_amount']),
        paid: asDouble(json['paid']),
        balance: asDouble(json['balance']),
        notes: asStringOrNull(json['notes']),
        isRepair: asBool(json['is_repair']),
        repairStatus: asStringOrNull(json['repair_status']),
        repairDeliveredAt: asStringOrNull(json['repair_delivered_at']),
        items: asMapList(json['items']).map(PurchaseItem.fromJson).toList(),
        payments:
            asMapList(json['payments']).map(PurchasePayment.fromJson).toList(),
      );

  DateTime? get dateTime => DateTime.tryParse(date);
  bool get hasDebt => balance > 0;
}
