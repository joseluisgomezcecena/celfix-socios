import 'package:celfix_socios/api/models/benefit.dart';
import 'package:celfix_socios/api/models/location.dart';
import 'package:celfix_socios/api/models/purchase.dart';
import 'package:celfix_socios/api/models/purchase_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseo tolerante de montos', () {
    test('acepta enteros JSON, que es lo que manda el POS real', () {
      // La API responde "total":500, no "500.00" — un cast a double revienta.
      final purchase = Purchase.fromJson(const {
        'id': 138571,
        'invoice_no': '78273',
        'date': '2026-08-04',
        'time': '17:09',
        'location': 'Sucursal Americas',
        'total': 500,
        'paid': 500,
        'balance': 0,
        'items_count': 2,
        'is_repair': false,
        'repair_status': null,
      });

      expect(purchase.total, 500.0);
      expect(purchase.hasDebt, isFalse);
    });

    test('acepta decimales como string por si Laravel los castea', () {
      final purchase = Purchase.fromJson(const {
        'id': 1,
        'invoice_no': '1',
        'date': '2026-08-04',
        'time': '10:00',
        'location': 'Sucursal Americas',
        'total': '150.50',
        'paid': '150.50',
        'balance': '0',
        'items_count': 1,
        'is_repair': false,
      });

      expect(purchase.total, 150.5);
    });

    test('balance negativo es sobrepago, no deuda', () {
      final purchase = Purchase.fromJson(const {
        'id': 133026,
        'invoice_no': '74813',
        'date': '2026-07-21',
        'time': '15:47',
        'location': 'Sucursal Americas',
        'total': 150,
        'paid': 500,
        'balance': -350,
        'items_count': 2,
        'is_repair': false,
      });

      expect(purchase.balance, -350.0);
      expect(purchase.hasDebt, isFalse);
    });
  });

  group('fechas sin conversión de timezone', () {
    test('combina date + time del listado en hora local Mexicali', () {
      final purchase = Purchase.fromJson(const {
        'id': 1,
        'invoice_no': '1',
        'date': '2026-08-04',
        'time': '17:09',
        'location': 'Sucursal Americas',
        'total': 0,
        'paid': 0,
        'balance': 0,
        'items_count': 0,
        'is_repair': false,
      });

      // 17:09 debe seguir siendo 17:09: la API no manda sufijo Z.
      expect(purchase.dateTime?.hour, 17);
      expect(purchase.dateTime?.minute, 9);
    });

    test('el detalle trae datetime completo en un solo campo', () {
      final detail = PurchaseDetail.fromJson(const {
        'id': 138571,
        'invoice_no': '78273',
        'date': '2026-08-04 17:09:00',
        'location': 'Sucursal Americas',
        'total': 500,
        'discount_amount': 0,
        'tax_amount': 0,
        'paid': 500,
        'balance': 0,
        'is_repair': false,
        'items': [
          {
            'product_name': 'VIDRIO TEMPLADO IPHONE 15 PRO MAX',
            'sku': 'CF-VTIP15PM-P',
            'quantity': 1,
            'unit_price': 150,
            'subtotal': 150,
            'quantity_returned': 0,
          }
        ],
        'payments': [
          {
            'method': 'card',
            'amount': 500,
            'is_return': false,
            'paid_on': '2026-08-04 17:10:39',
          }
        ],
      });

      expect(detail.dateTime?.hour, 17);
      expect(detail.items.single.productName, contains('VIDRIO'));
      expect(detail.payments.single.methodLabel, 'Tarjeta');
    });
  });

  group('horarios de sucursal', () {
    test('distingue día abierto de día cerrado', () {
      final location = StoreLocation.fromJson(const {
        'id': 6,
        'name': 'Sucursal Americas',
        'address': 'Calz. de las Américas 18',
        'phone': '6862474298',
        'hours': {
          'mon': {'open': '09:00', 'close': '18:00'},
          'sun': {'closed': true},
        },
        'latitude': 32.6524671,
        'longitude': -115.46818,
        'maps_url': 'https://maps.example/x',
      });

      expect(location.hours['mon']!.label, '09:00 - 18:00');
      expect(location.hours['sun']!.closed, isTrue);
      expect(location.hours['sun']!.label, 'Cerrado');
    });
  });

  group('beneficios', () {
    test('usa display_value del backend sin reconstruirlo', () {
      // value_type real es 'amount'/'percent', no lo que documentaba el doc.
      final benefit = Benefit.fromJson(const {
        'id': 1,
        'title': 'Cupón de Regalo \$100',
        'value_type': 'amount',
        'value': 100,
        'display_value': '\$100',
        'min_purchase': 499,
      });

      expect(benefit.displayValue, '\$100');
      expect(benefit.minPurchase, 499.0);
      expect(benefit.isGlobal, isTrue);
    });
  });
}
