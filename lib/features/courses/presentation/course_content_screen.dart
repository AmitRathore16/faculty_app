import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/course_model.dart';
import '../../../shared/widgets/state_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

// Course Content Provider
final courseContentProvider =
FutureProvider.family.autoDispose<Course, String>((ref, id) async {
  final api = ApiService();
  final response = await api.get('/api/courses/$id');
  final data = response.data;

  Map<String, dynamic> courseData = {};
  if (data is Map && data['course'] != null) {
    courseData = Map<String, dynamic>.from(data['course']);
  } else if (data is Map) {
    courseData = Map<String, dynamic>.from(data);
  }

  return Course.fromJson(courseData);
});
// =======================
// COURSE RATING (STUDENT)
// =======================

final courseRatingValueProvider =
StateProvider.autoDispose.family<int, String>((ref, courseId) => 0);

final submitCourseRatingProvider =
FutureProvider.autoDispose.family<void, ({String courseId, int rating})>(
        (ref, args) async {
      final api = ApiService();

      await api.post(
        "/api/courses/${args.courseId}/rating",
        data: {"rating": args.rating},
      );

      // refresh course details after rating submit
      ref.invalidate(courseContentProvider(args.courseId));
    });

class CourseContentScreen extends ConsumerWidget {
  final String courseId;

  const CourseContentScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseContentProvider(courseId));

    return Scaffold(
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Scaffold(
          appBar: AppBar(),
          body: ErrorStateWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(courseContentProvider(courseId)),
          ),
        ),
        data: (course) => _buildContent(context,ref, course),
      ),
    );
  }

  Widget _buildContent(BuildContext context,WidgetRef ref, Course course) {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              course.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: Colors.black45, blurRadius: 8),
                ],
              ),
            ),
            background: Container(
              color: AppColors.grey200,
              child: course.imageUrl.isNotEmpty
                  ? Image.network(
                course.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
                  : _buildPlaceholder(),
            ),
          ),
        ),

        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course Overview Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Course Overview',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        if (course.description != null)
                          Text(
                            course.description!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Course Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        Icons.video_library,
                        'Videos',
                        '${course.videoCount ?? 0}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        Icons.live_tv,
                        'Live Classes',
                        '${course.liveClassCount ?? 0}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ⭐ Course Rating Section
                _buildRatingSection(context, ref, course),
                const SizedBox(height: 16),

                // Videos Section
                if (course.videos != null && course.videos!.isNotEmpty) ...[
                  Text(
                    'Course Videos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ...course.videos!
                      .map((video) => _buildVideoItem(context, video)),
                ] else ...[
                  const EmptyStateWidget(
                    icon: Icons.video_library_outlined,
                    title: 'No Videos Yet',
                    subtitle: 'Videos will be added soon',
                  ),
                ],

                const SizedBox(height: 24),

                // Study Materials
                if (course.studyMaterials != null &&
                    course.studyMaterials!.isNotEmpty) ...[
                  Text(
                    'Study Materials',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ...course.studyMaterials!
                      .map((material) => _buildMaterialItem(context, material)),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildRatingSection(BuildContext context, WidgetRef ref, Course course) {
    final selectedRating =
    ref.watch(courseRatingValueProvider(course.id));

    final submitAsync = ref.watch(
      submitCourseRatingProvider((courseId: course.id, rating: selectedRating)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Rate this Course",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),

            Text(
              "Your rating helps others choose better.",
              style: TextStyle(color: AppColors.grey600, fontSize: 12),
            ),

            const SizedBox(height: 12),

            Row(
              children: List.generate(5, (index) {
                final value = index + 1;
                final filled = value <= selectedRating;

                return IconButton(
                  onPressed: () {
                    ref
                        .read(courseRatingValueProvider(course.id).notifier)
                        .state = value;
                  },
                  icon: Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: filled ? Colors.amber : AppColors.grey400,
                  ),
                );
              }),
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (selectedRating == 0 || submitAsync.isLoading)
                    ? null
                    : () async {
                  try {
                    await ref.read(
                      submitCourseRatingProvider(
                        (courseId: course.id, rating: selectedRating),
                      ).future,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Thanks! Rating submitted ✅"),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Rating failed: $e"),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: submitAsync.isLoading
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text("Submit Rating"),
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
        size: 64,
        color: AppColors.grey400,
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context,
      IconData icon,
      String label,
      String value,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoItem(BuildContext context, CourseVideo video) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.play_arrow, color: AppColors.primary),
        ),
        title: Text(video.title ?? 'Video'),
        subtitle:
        video.duration != null ? Text('Duration: ${video.duration}') : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          if (video.link != null && video.link!.isNotEmpty) {
            final uri = Uri.parse(video.link!);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
      ),
    );
  }

  Widget _buildMaterialItem(BuildContext context, StudyMaterial material) {
    IconData icon;
    switch (material.fileType?.toUpperCase()) {
      case 'PDF':
        icon = Icons.picture_as_pdf;
        break;
      case 'DOC':
        icon = Icons.description;
        break;
      case 'PPT':
        icon = Icons.slideshow;
        break;
      default:
        icon = Icons.insert_drive_file;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(material.title ?? 'Study Material'),
        subtitle: Text(material.fileType ?? 'File'),
        trailing: const Icon(Icons.download),
        onTap: () async {
          if (material.link != null && material.link!.isNotEmpty) {
            final uri = Uri.parse(material.link!);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
      ),
    );
  }
}
