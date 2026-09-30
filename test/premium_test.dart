import 'package:celfix_socios/api/models/app_designs.dart';
import 'package:celfix_socios/api/models/benefit.dart';
import 'package:celfix_socios/api/models/customer.dart';
import 'package:celfix_socios/api/models/promo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('is_premium del customer', () {
    test('lo toma del servidor, no lo recalcula de la fecha', () {
      // Fecha ya vencida pero el servidor dice que sí es premium: mandamos lo
      // que dice el servidor. El reloj del teléfono no decide esto.
      final customer = Customer.fromJson(const {
        'id': 1,
        'name': 'Mario',
        'mobile': '6861702069',
        'membership_no': '9001000001',
        'membership_expires_at': '2020-01-01',
        'is_premium': true,
        'profile_complete': true,
      });

      expect(customer.isPremium, isTrue);
      expect(customer.subscriptionLapsed, isFalse);
    });

    test('sin suscripción no es premium ni cuenta como vencida', () {
      final customer = Customer.fromJson(const {
        'id': 1,
        'name': 'Mario',
        'mobile': '6861702069',
        'membership_no': '9001000001',
        'membership_expires_at': null,
        'is_premium': false,
        'profile_complete': true,
      });

      expect(customer.isPremium, isFalse);
      // Nunca pagó: no es que se le haya vencido nada.
      expect(customer.subscriptionLapsed, isFalse);
    });

    test('con fecha y sin premium, la suscripción caducó', () {
      final customer = Customer.fromJson(const {
        'id': 1,
        'name': 'Mario',
        'mobile': '6861702069',
        'membership_no': '9001000001',
        'membership_expires_at': '2025-01-01',
        'is_premium': false,
        'profile_complete': true,
      });

      expect(customer.subscriptionLapsed, isTrue);
    });
  });

  group('profile_complete', () {
    test('respeta el campo del servidor', () {
      final customer = Customer.fromJson(const {
        'id': 1,
        'name': 'Mario Pérez',
        'first_name': 'Mario',
        'last_name': 'Pérez',
        'date_of_birth': '1990-05-15',
        'mobile': '6861702069',
        'membership_no': '9001000001',
        'profile_complete': true,
      });

      expect(customer.profileComplete, isTrue);
      expect(customer.dateOfBirth, DateTime(1990, 5, 15));
    });

    test('lo deduce si el backend todavía no manda el campo', () {
      // Protege contra una API vieja: sin este fallback la app encerraría al
      // socio en "completa tu perfil" para siempre.
      final incomplete = Customer.fromJson(const {
        'id': 1,
        'name': 'Mario',
        'mobile': '6861702069',
        'membership_no': '9001000001',
      });
      expect(incomplete.profileComplete, isFalse);

      final complete = Customer.fromJson(const {
        'id': 1,
        'name': 'Mario Pérez',
        'first_name': 'Mario',
        'last_name': 'Pérez',
        'date_of_birth': '1990-05-15',
        'mobile': '6861702069',
        'membership_no': '9001000001',
      });
      expect(complete.profileComplete, isTrue);
    });
  });

  group('iniciales del avatar', () {
    test('usa nombre y apellido', () {
      final customer = Customer.fromJson(const {
        'id': 1,
        'name': 'Mario Pérez',
        'first_name': 'Mario',
        'last_name': 'Pérez',
        'mobile': '6861702069',
        'membership_no': '9001000001',
      });
      expect(customer.initials, 'MP');
    });

    test('cae al nombre completo del POS si no hay first/last', () {
      final customer = Customer.fromJson(const {
        'id': 1,
        'name': 'Lesli Michelle Araiza',
        'mobile': '6861702069',
        'membership_no': '9001000001',
      });
      expect(customer.initials, 'LM');
    });
  });

  group('is_premium en el contenido', () {
    test('promos y beneficios lo parsean', () {
      final promo = Promo.fromJson(const {
        'id': 1,
        'title': '3x2 en fundas premium',
        'is_premium': true,
      });
      final benefit = Benefit.fromJson(const {
        'id': 1,
        'title': '10% en reparaciones',
        'is_premium': false,
      });

      expect(promo.isPremium, isTrue);
      expect(benefit.isPremium, isFalse);
    });

    test('un item sin el campo no se bloquea', () {
      // El backend viejo no manda is_premium; tratarlo como premium
      // escondería contenido gratis detrás del aviso de pago.
      final promo = Promo.fromJson(const {'id': 1, 'title': 'Promo vieja'});
      expect(promo.isPremium, isFalse);
    });
  });

  group('app designs', () {
    test('lee la key del fondo de la tarjeta', () {
      final designs = AppDesigns.fromJson(const {
        'designs': {
          'membership_card_background': 'https://pos.celfix.mx/storage/a.jpg',
        },
      });
      expect(designs.membershipCardBackground,
          'https://pos.celfix.mx/storage/a.jpg');
    });

    test('sin la key devuelve null para que la app use su fondo local', () {
      expect(
        AppDesigns.fromJson(const {'designs': {}}).membershipCardBackground,
        isNull,
      );
    });

    test('tolera que designs venga como lista vacía', () {
      // PHP serializa un array vacío como [] y no como {}.
      final designs = AppDesigns.fromJson(const {'designs': []});
      expect(designs.isEmpty, isTrue);
      expect(designs.membershipCardBackground, isNull);
    });
  });
}
