import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/course.dart';
import '../state/auth_provider.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/celfix_logo.dart';
import '../widgets/course_card.dart';

/// Cursos y talleres: primero los del socio, luego los próximos.
class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider);
    final mine = ref.watch(myCoursesProvider).value ?? const <Course>[];
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('Cursos y talleres')),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshCourses(ref);
          await ref.read(coursesProvider.future);
        },
        child: courses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              SizedBox(
                height: 400,
                child: ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(coursesProvider),
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty && mine.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 420,
                    child: EmptyView(
                      icon: Icons.school_outlined,
                      title: 'Aún no hay cursos programados',
                      subtitle:
                          'Cuando Celfix agende un taller, lo vas a ver aquí.',
                    ),
                  ),
                ],
              );
            }

            // Los que ya tomó no vuelven a aparecer abajo: se muestran una
            // sola vez, en la sección que les toca.
            final mineIds = mine.map((course) => course.id).toSet();
            final upcoming = isAuthenticated
                ? items.where((c) => !mineIds.contains(c.id)).toList()
                : items;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  CelfixShape.pageInset, 20, CelfixShape.pageInset, 32),
              children: [
                if (mine.isNotEmpty) ...[
                  const SectionTitle(text: 'Mis cursos'),
                  const SizedBox(height: 12),
                  for (final course in mine) ...[
                    CourseCard(course: course, assumeEnrolled: true),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                ],
                if (upcoming.isNotEmpty) ...[
                  SectionTitle(
                    text: mine.isEmpty ? 'Próximos cursos' : 'Otros cursos',
                  ),
                  const SizedBox(height: 12),
                  for (final course in upcoming) ...[
                    CourseCard(course: course),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
