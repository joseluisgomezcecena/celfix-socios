import 'package:celfix_socios/api/models/course.dart';
import 'package:celfix_socios/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Course _course(Map<String, dynamic> overrides) => Course.fromJson({
      'id': 4,
      'title': 'Curso de reparación básica',
      'starts_at': '2026-10-15T10:00:00-07:00',
      'ends_at': '2026-10-15T13:00:00-07:00',
      'capacity': 20,
      'enrolled_count': 8,
      'spots_left': 12,
      'is_full': false,
      'has_started': false,
      ...overrides,
    });

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  group('fechas con offset', () {
    test('conserva la hora que programó el admin', () {
      // DateTime.parse convertiría "10:00-07:00" a 17:00Z, y toLocal() lo
      // movería según la zona del teléfono. El curso empieza a las 10 en la
      // tienda y así debe verse en cualquier dispositivo.
      final course = _course(const {});

      expect(course.startsAt!.hour, 10);
      expect(course.startsAt!.minute, 0);
      expect(course.endsAt!.hour, 13);
      expect(course.startsAt!.day, 15);
    });

    test('tolera otros formatos de zona', () {
      for (final raw in const [
        '2026-10-15T10:00:00Z',
        '2026-10-15T10:00:00+05:30',
        '2026-10-15T10:00:00-0700',
        '2026-10-15T10:00:00',
      ]) {
        final course = _course({'starts_at': raw});
        expect(course.startsAt!.hour, 10, reason: raw);
      }
    });

    test('el horario se arma en español y sin repetir el día', () {
      final course = _course(const {});
      final label = Fmt.courseSchedule(course.startsAt, course.endsAt);

      expect(label, startsWith('Jueves 15 de octubre'));
      expect(label, contains('a'));
      // Un solo día: no debe aparecer dos veces la fecha.
      expect('octubre'.allMatches(label).length, 1);
    });

    test('sin fecha no inventa una', () {
      expect(Fmt.courseSchedule(null, null), 'Fecha por confirmar');
    });
  });

  group('cupo', () {
    test('capacity 0 es ilimitado', () {
      final course = _course(const {'capacity': 0, 'spots_left': null});
      expect(course.isUnlimited, isTrue);
      expect(course.isRunningOut, isFalse);
    });

    test('marca urgencia solo con pocos lugares', () {
      expect(_course(const {'spots_left': 12}).isRunningOut, isFalse);
      expect(_course(const {'spots_left': 3}).isRunningOut, isTrue);
      expect(_course(const {'spots_left': 0}).isRunningOut, isFalse);
    });

    test('me/courses no trae campos de cupo y no truena', () {
      final course = Course.fromJson(const {
        'id': 4,
        'title': 'Curso',
        'starts_at': '2026-10-15T10:00:00-07:00',
        'has_started': false,
        'has_ended': false,
      });

      expect(course.capacity, isNull);
      expect(course.isUnlimited, isTrue);
      expect(course.hasEnded, isFalse);
    });
  });

  group('acción del botón', () {
    CourseAction action({
      bool authenticated = true,
      bool enrolled = false,
      bool full = false,
      bool started = false,
    }) =>
        resolveCourseAction(
          course: _course({'is_full': full, 'has_started': started}),
          isAuthenticated: authenticated,
          isEnrolled: enrolled,
        );

    test('invitado siempre va a login, aunque esté lleno o iniciado', () {
      expect(action(authenticated: false), CourseAction.signIn);
      expect(action(authenticated: false, full: true), CourseAction.signIn);
      expect(action(authenticated: false, started: true), CourseAction.signIn);
    });

    test('socio no inscrito puede inscribirse', () {
      expect(action(), CourseAction.enroll);
    });

    test('cupo lleno bloquea solo a quien no está inscrito', () {
      expect(action(full: true), CourseAction.full);
      // Ya inscrito: el cupo lleno no le quita su lugar.
      expect(action(full: true, enrolled: true), CourseAction.cancel);
    });

    test('curso iniciado bloquea inscripción y cancelación', () {
      expect(action(started: true), CourseAction.started);
      // El backend responde 422 al cancelar algo ya iniciado: no lo ofrecemos.
      expect(action(started: true, enrolled: true), CourseAction.enrolled);
    });

    test('inscrito y sin iniciar puede cancelar', () {
      expect(action(enrolled: true), CourseAction.cancel);
    });
  });
}
