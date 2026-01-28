import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/course_model.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';
import '../../auth/providers/auth_provider.dart';

// My Courses Provider
final myCoursesProvider = FutureProvider.autoDispose<List<Course>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final userId = authState.user?.id;

  if (userId == null) {
    throw Exception('User not logged in');
  }

  final api = ApiService();
  final response = await api.get('/api/students/$userId');
  final data = response.data;

  if (data is Map && data['data'] != null) {
    final student = data['data'];
    final courses = student['courses'] as List<dynamic>?;

    if (courses == null || courses.isEmpty) {
      return [];
    }

    // Extract course details from the courses array
    return courses
        .map((courseEntry) {
      final courseData = courseEntry['courseId'];
      if (courseData != null) {
        return Course.fromJson(courseData);
      }
      return null;
    })
        .where((course) => course != null)
        .cast<Course>()
        .toList();
  }

  return [];
});

class MyCoursesScreen extends ConsumerWidget {
  const MyCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(myCoursesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myCoursesProvider);
        },
        child: coursesAsync.when(
          loading: () => const ShimmerList(itemCount: 5, itemHeight: 160),
          error: (error, stack) => ErrorStateWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(myCoursesProvider),
          ),
          data: (courses) {
            if (courses.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.play_circle_outline,
                title: 'No Courses Enrolled',
                subtitle: 'Start learning by enrolling in courses',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              itemBuilder: (context, index) {
                return _MyCourseCard(course: courses[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _MyCourseCard extends StatelessWidget {
  final Course course;

  const _MyCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/course-content/${course.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 140,
              width: double.infinity,
              color: AppColors.grey200,
              child: course.imageUrl.isNotEmpty
                  ? Image.network(
                course.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
                  : _buildPlaceholder(),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Specialization badge
                  if (course.specialization.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: course.specialization.take(2).map((spec) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            spec,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    course.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Educator
                  if (course.educator != null)
                    Row(
                      children: [
                        UserAvatar(
                          imageUrl: course.educator!.profilePicture,
                          name: course.educator!.name,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          course.educator!.name ?? 'Educator',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push('/course-content/${course.id}'),
                      child: const Text('Continue Learning'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.play_circle_outline,
        size: 48,
        color: AppColors.grey400,
      ),
    );
  }
}
