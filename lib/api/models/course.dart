import 'json.dart';

/// Curso o taller que Celfix programa desde el POS.
///
/// El mismo modelo cubre `/courses` y `/me/courses`: el segundo omite los
/// campos de cupo porque al inscrito no le sirven, así que esos son nullables.
class Course {
  final int id;
  final String title;
  final String? description;
  final String? instructorName;
  final String? imageUrl;
  final int? targetLocationId;

  /// Hora de pared tal como la programó el admin (ver [asWallClock]).
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// 0 = ilimitado. Ausente en `/me/courses`.
  final int? capacity;
  final int? enrolledCount;

  /// null cuando el cupo es ilimitado.
  final int? spotsLeft;

  final bool isFull;
  final bool hasStarted;

  /// Solo viene en `/me/courses`.
  final bool hasEnded;

  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.instructorName,
    required this.imageUrl,
    required this.targetLocationId,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.enrolledCount,
    required this.spotsLeft,
    required this.isFull,
    required this.hasStarted,
    required this.hasEnded,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: asInt(json['id']),
        title: asString(json['title']),
        description: asStringOrNull(json['description']),
        instructorName: asStringOrNull(json['instructor_name']),
        imageUrl: asStringOrNull(json['image_url']),
        targetLocationId: asIntOrNull(json['target_location_id']),
        startsAt: asWallClock(json['starts_at']),
        endsAt: asWallClock(json['ends_at']),
        capacity: asIntOrNull(json['capacity']),
        enrolledCount: asIntOrNull(json['enrolled_count']),
        spotsLeft: asIntOrNull(json['spots_left']),
        isFull: asBool(json['is_full']),
        hasStarted: asBool(json['has_started']),
        hasEnded: asBool(json['has_ended']),
      );

  /// capacity 0 (o ausente) significa sin tope.
  bool get isUnlimited => capacity == null || capacity == 0;

  /// Solo tiene sentido avisar del cupo cuando queda poco.
  bool get isRunningOut =>
      !isUnlimited && spotsLeft != null && spotsLeft! > 0 && spotsLeft! <= 5;
}

/// Lo que la app puede ofrecer para un curso, ya cruzada la lista pública con
/// las inscripciones del socio.
enum CourseAction {
  /// Invitado: primero hay que entrar.
  signIn,

  enroll,
  cancel,

  /// Inscrito y el curso ya arrancó: se muestra, sin acción.
  enrolled,

  full,
  started,
}

/// Decide qué ofrecer para un curso.
///
/// `isEnrolled` sale de cruzar contra `/me/courses`; el backend no manda un
/// flag en `/courses` a propósito, para dejarlo cacheable.
CourseAction resolveCourseAction({
  required Course course,
  required bool isAuthenticated,
  required bool isEnrolled,
}) {
  if (!isAuthenticated) return CourseAction.signIn;

  if (isEnrolled) {
    // Ya empezado no se puede cancelar: el backend responde 422.
    return course.hasStarted ? CourseAction.enrolled : CourseAction.cancel;
  }

  if (course.hasStarted) return CourseAction.started;
  if (course.isFull) return CourseAction.full;
  return CourseAction.enroll;
}
