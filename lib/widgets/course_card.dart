import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_exception.dart';
import '../api/models/course.dart';
import '../router.dart';
import '../state/auth_provider.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'celfix_logo.dart';

/// Tarjeta de curso con su acción. Decide el botón cruzando la lista pública
/// con las inscripciones del socio.
class CourseCard extends ConsumerStatefulWidget {
  final Course course;

  /// En "Mis cursos" ya sabemos que está inscrito y no hace falta cruzar.
  final bool assumeEnrolled;

  const CourseCard({
    super.key,
    required this.course,
    this.assumeEnrolled = false,
  });

  @override
  ConsumerState<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends ConsumerState<CourseCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      // Las dos listas cambian a la vez: el cupo y el botón deben moverse
      // juntos o el socio ve datos incoherentes.
      refreshCourses(ref);
      if (mounted) _toast(okMessage);
    } on ApiException catch (error) {
      if (!mounted) return;
      _toast(error.message);
      // 409 (lleno) y 422 (ya inició) significan que nuestra copia está
      // vieja: recargamos para que el botón refleje la realidad.
      if (error.isConflict || error.isValidation) refreshCourses(ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;
    final enrolledIds = ref.watch(enrolledCourseIdsProvider);

    // Mientras no sepamos si está inscrito, no arriesgamos un botón erróneo.
    final resolving = isAuthenticated &&
        !widget.assumeEnrolled &&
        !enrolledIds.hasValue;

    final action = resolveCourseAction(
      course: course,
      isAuthenticated: isAuthenticated,
      isEnrolled: widget.assumeEnrolled ||
          (enrolledIds.value?.contains(course.id) ?? false),
    );

    return Container(
      decoration: CelfixShape.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CourseImage(course: course),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CelfixColors.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                _MetaRow(
                  icon: Icons.event_outlined,
                  text: Fmt.courseSchedule(course.startsAt, course.endsAt),
                ),
                if (course.instructorName != null)
                  _MetaRow(
                    icon: Icons.person_outline,
                    text: course.instructorName!,
                  ),
                if (course.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    course.description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CelfixColors.inkSoft,
                      height: 1.35,
                    ),
                  ),
                ],
                if (!widget.assumeEnrolled) ...[
                  const SizedBox(height: 10),
                  _Capacity(course: course),
                ],
                const SizedBox(height: 14),
                _ActionButton(
                  action: action,
                  busy: _busy,
                  resolving: resolving,
                  onEnroll: () => _run(
                    () => ref.read(customerApiProvider).enroll(course.id),
                    '¡Listo! Quedaste inscrito.',
                  ),
                  onCancel: () => _run(
                    () => ref
                        .read(customerApiProvider)
                        .cancelEnrollment(course.id),
                    'Inscripción cancelada.',
                  ),
                  onSignIn: () => context.go(Routes.login),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseImage extends StatelessWidget {
  final Course course;

  const _CourseImage({required this.course});

  @override
  Widget build(BuildContext context) {
    final image = course.imageUrl;
    if (image == null) return const _CourseBackdrop();

    return CachedNetworkImage(
      imageUrl: image,
      height: 140,
      fit: BoxFit.cover,
      placeholder: (context, url) =>
          const SizedBox(height: 140, child: ColoredBox(color: CelfixColors.cardSoft)),
      errorWidget: (context, url, error) => const _CourseBackdrop(),
    );
  }
}

class _CourseBackdrop extends StatelessWidget {
  const _CourseBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [CelfixColors.cyan, CelfixColors.cyanDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: CelfixMark(size: 44, background: Colors.white)),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: CelfixColors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: CelfixColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _Capacity extends StatelessWidget {
  final Course course;

  const _Capacity({required this.course});

  @override
  Widget build(BuildContext context) {
    if (course.isUnlimited) {
      return const Text(
        'Cupo abierto',
        style: TextStyle(fontSize: 12, color: CelfixColors.inkSoft),
      );
    }

    if (course.isFull) {
      return const Text(
        'Cupo lleno',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: CelfixColors.danger,
        ),
      );
    }

    final left = course.spotsLeft;
    return Text(
      left == null
          ? 'Cupo limitado'
          : '$left ${left == 1 ? "lugar disponible" : "lugares disponibles"}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: course.isRunningOut ? FontWeight.w600 : FontWeight.w400,
        // Pocos lugares se resalta; con cupo holgado no hay que presionar.
        color: course.isRunningOut ? kCourseUrgent : CelfixColors.inkSoft,
      ),
    );
  }
}

/// Ámbar para "quedan pocos lugares".
const kCourseUrgent = Color(0xFFB26A00);

class _ActionButton extends StatelessWidget {
  final CourseAction action;
  final bool busy;
  final bool resolving;
  final VoidCallback onEnroll;
  final VoidCallback onCancel;
  final VoidCallback onSignIn;

  const _ActionButton({
    required this.action,
    required this.busy,
    required this.resolving,
    required this.onEnroll,
    required this.onCancel,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    if (busy || resolving) {
      return const SizedBox(
        height: 46,
        child: Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return switch (action) {
      CourseAction.signIn => OutlinedButton(
          onPressed: onSignIn,
          child: const Text('Iniciar sesión para inscribirte'),
        ),
      CourseAction.enroll => FilledButton(
          onPressed: onEnroll,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          child: const Text('INSCRIBIRME'),
        ),
      CourseAction.cancel => OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: CelfixColors.danger,
            side: const BorderSide(color: CelfixColors.line),
          ),
          child: const Text('Cancelar inscripción'),
        ),
      CourseAction.enrolled => const _Status(
          icon: Icons.check_circle,
          label: 'Inscrito',
          color: CelfixColors.blue,
        ),
      CourseAction.full => const _Status(
          icon: Icons.block,
          label: 'Cupo lleno',
          color: CelfixColors.inkSoft,
        ),
      CourseAction.started => const _Status(
          icon: Icons.schedule,
          label: 'Ya inició',
          color: CelfixColors.inkSoft,
        ),
    };
  }
}

/// Estado sin acción: se ve claramente inerte, no como un botón apagado que
/// invite a picarle.
class _Status extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Status({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CelfixColors.cardSoft,
        borderRadius: BorderRadius.circular(CelfixShape.buttonRadius),
        border: Border.all(color: CelfixColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
