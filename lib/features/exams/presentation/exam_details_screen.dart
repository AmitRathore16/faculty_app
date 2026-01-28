import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';

import '../../../shared/models/course_model.dart';
import '../../../shared/models/test_series_model.dart';
import '../../../shared/models/educator_model.dart';

import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';

/// ================================
/// Specialization Mapper (EXAMS)
/// ================================
String specializationForApi(String examType) {
  switch (examType.toLowerCase()) {
    case 'iit-jee':
      return 'IIT-JEE';
    case 'neet':
      return 'NEET';
    case 'cbse':
      return 'CBSE';
    default:
      return examType.toUpperCase();
  }
}

/// ================================
/// Courses Provider (Already done)
/// ================================
final examCoursesProvider =
FutureProvider.family.autoDispose<List<Course>, String>((ref, examType) async {
  final api = ApiService();
  final specialization = specializationForApi(examType);

  final response = await api.get('/api/courses/specialization/$specialization');
  final data = response.data;

  List<dynamic> coursesList = [];
  if (data is Map && data['courses'] != null) {
    coursesList = data['courses'] as List;
  } else if (data is List) {
    coursesList = data;
  }

  return coursesList.map((e) => Course.fromJson(e)).toList();
});

/// ================================
/// ✅ NEW: Test Series Provider (filtered by specialization)
/// Uses: GET /api/test-series?specialization=IIT-JEE
/// ================================
final examTestSeriesProvider =
FutureProvider.family.autoDispose<List<TestSeries>, String>((ref, examType) async {
  final api = ApiService();
  final specialization = specializationForApi(examType);

  final response = await api.get(
    '/api/test-series',
    queryParameters: {
      "specialization": specialization,
      "limit": 50,
      "page": 1,
    },
  );

  final data = response.data;

  List<dynamic> seriesList = [];

  if (data is Map && data['testSeries'] is List) {
    seriesList = data['testSeries'];
  } else if (data is List) {
    seriesList = data;
  }

  return seriesList.map((e) => TestSeries.fromJson(e)).toList();
});

/// ================================
/// ✅ NEW: Educators Provider (filtered by specialization)
/// Uses: GET /api/educators?specialization=IIT-JEE
/// ================================
final examEducatorsProvider =
FutureProvider.family.autoDispose<List<Educator>, String>((ref, examType) async {
  final api = ApiService();
  final specialization = specializationForApi(examType);

  final response = await api.get(
    '/api/educators',
    queryParameters: {
      "specialization": specialization,
      "limit": 50,
      "page": 1,
      "status": "active",
    },
  );

  dynamic data = response.data;

  List<dynamic> educatorsList = [];

  // ✅ your backend sends: { success, data: { educators: [] } }
  if (data is Map &&
      data['data'] is Map &&
      data['data']['educators'] is List) {
    educatorsList = data['data']['educators'] as List;
  }

  return educatorsList.map((e) => Educator.fromJson(e)).toList();
});

/// ================================
/// Screen
/// ================================
class ExamDetailsScreen extends ConsumerWidget {
  final String examType;

  const ExamDetailsScreen({super.key, required this.examType});

  String get examName {
    switch (examType.toLowerCase()) {
      case 'iit-jee':
        return 'IIT-JEE';
      case 'neet':
        return 'NEET';
      case 'cbse':
        return 'CBSE';
      default:
        return examType.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$examName Preparation'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Courses'),
              Tab(text: 'Test Series'),
              Tab(text: 'Educators'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CoursesTab(examType: examType),
            _TestSeriesTab(examType: examType), // ✅ updated
            _EducatorsTab(examType: examType), // ✅ updated
          ],
        ),
      ),
    );
  }
}

/// ================================
/// Courses Tab
/// ================================
class _CoursesTab extends ConsumerWidget {
  final String examType;

  const _CoursesTab({required this.examType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(examCoursesProvider(examType));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(examCoursesProvider(examType)),
      child: coursesAsync.when(
        loading: () => const ShimmerList(itemCount: 5),
        error: (error, stack) => ErrorStateWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(examCoursesProvider(examType)),
        ),
        data: (courses) {
          if (courses.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.play_circle_outline,
              title: 'No Courses Available',
              subtitle: 'Check back later for new courses',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return _CourseListItem(course: course);
            },
          );
        },
      ),
    );
  }
}

class _CourseListItem extends StatelessWidget {
  final Course course;

  const _CourseListItem({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/course/${course.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: AppColors.grey200,
                  child: const Icon(Icons.play_circle, color: AppColors.grey400),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.educator?.name ?? 'Educator',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₹${course.finalPrice.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        if (course.hasDiscount) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₹${course.fees?.toInt()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.grey500,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.grey400),
            ],
          ),
        ),
      ),
    );
  }
}

/// ================================
/// ✅ Test Series Tab (FILTERED)
/// ================================
class _TestSeriesTab extends ConsumerWidget {
  final String examType;

  const _TestSeriesTab({required this.examType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testSeriesAsync = ref.watch(examTestSeriesProvider(examType));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(examTestSeriesProvider(examType)),
      child: testSeriesAsync.when(
        loading: () => const ShimmerList(itemCount: 5, itemHeight: 140),
        error: (error, stack) => ErrorStateWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(examTestSeriesProvider(examType)),
        ),
        data: (series) {
          if (series.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.assignment_outlined,
              title: 'No Test Series Available',
              subtitle: 'Check back later for new test series',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: series.length,
            itemBuilder: (context, index) {
              final s = series[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () => context.push('/test-series/${s.id}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (s.educatorName != null)
                          Text(
                            'By ${s.educatorName}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _chip(Icons.quiz, '${s.totalTests ?? 0} Tests'),
                            const SizedBox(width: 12),
                            _chip(Icons.people, '${s.enrolledCount ?? 0} Enrolled'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            PriceWidget(
                              price: s.fees ?? 0,
                              discount: s.discount,
                              originalPrice: s.fees,
                            ),
                            ElevatedButton(
                              onPressed: () => context.push('/test-series/${s.id}'),
                              child: const Text('View'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.grey600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.grey600,
          ),
        ),
      ],
    );
  }
}

/// ================================
/// ✅ Educators Tab (FILTERED)
/// ================================
class _EducatorsTab extends ConsumerWidget {
  final String examType;

  const _EducatorsTab({required this.examType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final educatorsAsync = ref.watch(examEducatorsProvider(examType));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(examEducatorsProvider(examType)),
      child: educatorsAsync.when(
        loading: () => const ShimmerList(itemCount: 6, itemHeight: 140),
        error: (error, stack) => ErrorStateWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(examEducatorsProvider(examType)),
        ),
        data: (educators) {
          if (educators.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.people_outline,
              title: 'No Educators Found',
              subtitle: 'Check back later for educators',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: educators.length,
            itemBuilder: (context, index) {
              final educator = educators[index];
              return _EducatorCard(educator: educator);
            },
          );
        },
      ),
    );
  }
}

/// Same UI as your EducatorsScreen card (reused)
class _EducatorCard extends StatelessWidget {
  final Educator educator;

  const _EducatorCard({required this.educator});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/educator/${educator.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                imageUrl: educator.imageUrl,
                name: educator.displayName,
                size: 70,
                showBorder: educator.status == 'active',
                borderColor: AppColors.success,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            educator.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (educator.status == 'active')
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.book, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            educator.displaySubjects,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (educator.bio != null && educator.bio!.isNotEmpty)
                      Text(
                        educator.bio!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildInfoChip(Icons.people, '${educator.followerCount} followers'),
                        const SizedBox(width: 12),
                        _buildInfoChip(Icons.work, educator.displayExperience),
                        const Spacer(),
                        if (educator.rating != null)
                          RatingWidget(
                            rating: educator.rating!.average ?? 0,
                            count: educator.rating!.count,
                            size: 14,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.grey500),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.grey600,
          ),
        ),
      ],
    );
  }
}
