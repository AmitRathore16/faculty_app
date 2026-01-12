import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/educator_model.dart';
import '../../../shared/models/course_model.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';

// Educator Detail Provider
final educatorDetailProvider = FutureProvider.family.autoDispose<Educator, String>((ref, id) async {
  final api = ApiService();
  final response = await api.get('/api/educators/$id');
  final data = response.data;
  
  Map<String, dynamic> educatorData = {};
  if (data is Map && data['educator'] != null) {
    educatorData = data['educator'];
  } else if (data is Map) {
    educatorData = Map<String, dynamic>.from(data);
  }
  
  return Educator.fromJson(educatorData);
});

// Educator Courses Provider
final educatorCoursesProvider = FutureProvider.family.autoDispose<List<Course>, String>((ref, id) async {
  final api = ApiService();
  final response = await api.get('/api/courses/educator/$id');
  final data = response.data;
  
  List<dynamic> coursesList = [];
  if (data is Map && data['courses'] != null) {
    coursesList = data['courses'] as List;
  } else if (data is List) {
    coursesList = data;
  }
  
  return coursesList.map((e) => Course.fromJson(e)).toList();
});

class EducatorProfileScreen extends ConsumerWidget {
  final String educatorId;
  
  const EducatorProfileScreen({super.key, required this.educatorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final educatorAsync = ref.watch(educatorDetailProvider(educatorId));
    
    return Scaffold(
      body: educatorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Scaffold(
          appBar: AppBar(),
          body: ErrorStateWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(educatorDetailProvider(educatorId)),
          ),
        ),
        data: (educator) => _buildProfile(context, ref, educator),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, WidgetRef ref, Educator educator) {
    return CustomScrollView(
      slivers: [
        // App Bar with Profile Header
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildProfileHeader(context, educator),
          ),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share, color: Colors.white),
              ),
              onPressed: () {
                // Share educator profile
              },
            ),
          ],
        ),
        
        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats
                _buildStatsRow(educator),
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.person_add),
                        label: const Text('Follow'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.message),
                        label: const Text('Message'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // About
                if (educator.bio != null && educator.bio!.isNotEmpty) ...[
                  Text('About', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    educator.bio!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Qualifications
                if (educator.qualifications.isNotEmpty) ...[
                  Text('Qualifications', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  ...educator.qualifications.map((q) => _buildQualificationItem(context, q)),
                  const SizedBox(height: 24),
                ],
                
                // Courses Section
                Text('Courses', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        
        // Courses List
        _buildCoursesList(ref),
        
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context, Educator educator) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            UserAvatar(
              imageUrl: educator.imageUrl,
              name: educator.displayName,
              size: 100,
              showBorder: true,
              borderColor: Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              educator.displayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              educator.displaySubjects,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            if (educator.rating != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${educator.rating!.average?.toStringAsFixed(1) ?? 'N/A'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' (${educator.rating!.count ?? 0} reviews)',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(Educator educator) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Followers', '${educator.followerCount}'),
          _buildStatDivider(),
          _buildStatItem('Experience', educator.displayExperience),
          _buildStatDivider(),
          _buildStatItem('Courses', '10+'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.grey600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: AppColors.grey300,
    );
  }

  Widget _buildQualificationItem(BuildContext context, Qualification qual) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.school, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  qual.title ?? qual.degree ?? 'Qualification',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (qual.institution != null)
                  Text(
                    qual.institution!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.grey600,
                    ),
                  ),
              ],
            ),
          ),
          if (qual.year != null)
            Text(
              qual.year!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.grey500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoursesList(WidgetRef ref) {
    final coursesAsync = ref.watch(educatorCoursesProvider(educatorId));
    
    return coursesAsync.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: List.generate(3, (_) => const ShimmerCard()),
          ),
        ),
      ),
      error: (error, stack) => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Failed to load courses'),
        ),
      ),
      data: (courses) {
        if (courses.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('No courses available'),
                ),
              ),
            ),
          );
        }
        
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final course = courses[index];
              return _CourseCard(course: course);
            },
            childCount: courses.length,
          ),
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  child: course.imageUrl.isNotEmpty
                      ? Image.network(
                          course.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.play_circle,
                            size: 32,
                            color: AppColors.grey400,
                          ),
                        )
                      : const Icon(
                          Icons.play_circle,
                          size: 32,
                          color: AppColors.grey400,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.subject.join(', '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PriceWidget(
                      price: course.finalPrice,
                      originalPrice: course.fees,
                      discount: course.discount,
                      fontSize: 14,
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
