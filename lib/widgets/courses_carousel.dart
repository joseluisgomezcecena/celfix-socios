import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/course.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'celfix_logo.dart';

/// Mismo alto que la tira de promos, para que Inicio no se vea desparejo.
const _carouselHeight = 172.0;

/// Tira de próximos cursos para Inicio.
///
/// Solo descubre: la inscripción se hace en la pantalla de Cursos, donde cabe
/// el detalle de cupo y horario completo.
class CoursesCarousel extends ConsumerStatefulWidget {
  final VoidCallback? onSeeAll;
  final void Function(Course course)? onTapCourse;

  const CoursesCarousel({super.key, this.onSeeAll, this.onTapCourse});

  @override
  ConsumerState<CoursesCarousel> createState() => _CoursesCarouselState();
}

class _CoursesCarouselState extends ConsumerState<CoursesCarousel> {
  final _controller = PageController(viewportFraction: 0.86);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesProvider);
    final enrolled = ref.watch(enrolledCourseIdsProvider).value ?? const <int>{};

    return courses.maybeWhen(
      data: (all) {
        // En Inicio no tiene sentido ofrecer cursos que ya arrancaron.
        final items = all.where((course) => !course.hasStarted).toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: CelfixShape.pageInset),
              child: SectionTitle(
                text: 'Cursos y talleres',
                trailing: widget.onSeeAll == null
                    ? null
                    : TextButton(
                        onPressed: widget.onSeeAll,
                        child: const Text('ver todos'),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: _carouselHeight,
              child: PageView.builder(
                controller: _controller,
                padEnds: false,
                onPageChanged: (page) => setState(() => _page = page),
                itemCount: items.length,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? CelfixShape.pageInset : 0,
                    right: 12,
                  ),
                  child: _CourseTile(
                    course: items[index],
                    isEnrolled: enrolled.contains(items[index].id),
                    onTap: widget.onTapCourse == null
                        ? null
                        : () => widget.onTapCourse!(items[index]),
                  ),
                ),
              ),
            ),
            if (items.length > 1) ...[
              const SizedBox(height: 12),
              Center(child: _Dots(count: items.length, active: _page)),
            ],
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final Course course;
  final bool isEnrolled;
  final VoidCallback? onTap;

  const _CourseTile({
    required this.course,
    required this.isEnrolled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = course.imageUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CelfixShape.cardRadius),
        child: Ink(
          decoration: CelfixShape.cardDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CelfixShape.cardRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const ColoredBox(color: CelfixColors.cardSoft),
                    errorWidget: (context, url, error) => const _Backdrop(),
                  )
                else
                  const _Backdrop(),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xCC000000), Color(0x00000000)],
                      stops: [0, 0.75],
                    ),
                  ),
                ),
                if (isEnrolled)
                  const Positioned(top: 10, right: 10, child: _EnrolledTag()),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        Fmt.courseSchedule(course.startsAt, course.endsAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EnrolledTag extends StatelessWidget {
  const _EnrolledTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 13, color: CelfixColors.blue),
          SizedBox(width: 4),
          Text(
            'Inscrito',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CelfixColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CelfixColors.cyan, CelfixColors.cyanDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CelfixMark(size: 30, background: Colors.white),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int active;

  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == active ? CelfixColors.cyan : CelfixColors.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
