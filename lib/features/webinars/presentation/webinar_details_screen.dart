import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/webinar_model.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';

// Webinar Detail Provider
final webinarDetailProvider =
FutureProvider.family.autoDispose<Webinar, String>((ref, id) async {
  final api = ApiService();
  final response = await api.get('/api/webinars/$id');

  final raw = response.data;

  if (raw is Map && raw['data'] is Map<String, dynamic>) {
    return Webinar.fromJson(Map<String, dynamic>.from(raw['data']));
  }

  // fallback (in case backend returns direct object someday)
  if (raw is Map<String, dynamic>) {
    return Webinar.fromJson(raw);
  }

  throw Exception("Invalid webinar response");
});


class WebinarDetailsScreen extends ConsumerWidget {
  final String webinarId;
  
  const WebinarDetailsScreen({super.key, required this.webinarId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webinarAsync = ref.watch(webinarDetailProvider(webinarId));
    
    return Scaffold(
      body: webinarAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Scaffold(
          appBar: AppBar(),
          body: ErrorStateWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(webinarDetailProvider(webinarId)),
          ),
        ),
        data: (webinar) => _buildContent(context, webinar),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Webinar webinar) {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: AppColors.grey200,
                  child: webinar.imageUrl.isNotEmpty
                      ? Image.network(
                          webinar.imageUrl,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.videocam, size: 64, color: AppColors.grey400),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                if (webinar.isLive)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 8),
                          SizedBox(width: 6),
                          Text(
                            'LIVE NOW',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
                // Title
                Text(
                  webinar.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                
                // Date and Time
                if (webinar.scheduledAt != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.event, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormatter.formatDate(webinar.scheduledAt!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                DateFormatter.formatTime(webinar.scheduledAt!),
                                style: TextStyle(color: AppColors.grey600),
                              ),
                            ],
                          ),
                        ),
                        if (webinar.duration != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.grey100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${webinar.duration} min',
                              style: TextStyle(
                                color: AppColors.grey700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                
                // Educator
                if (webinar.educatorName != null) ...[
                  Text(
                    'Hosted by',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      if (webinar.educatorId != null) {
                        context.push('/educator/${webinar.educatorId}');
                      }
                    },
                    child: Row(
                      children: [
                        UserAvatar(
                          imageUrl: webinar.educatorImage,
                          name: webinar.educatorName,
                          size: 50,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              webinar.educatorName!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'View Profile',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Description
                if (webinar.description != null && webinar.description!.isNotEmpty) ...[
                  Text(
                    'About this webinar',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    webinar.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Stats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        Icons.people,
                        '${webinar.registeredCount ?? 0}',
                        'Registered',
                      ),
                      if (webinar.maxAttendees != null)
                        _buildStatItem(
                          Icons.chair,
                          '${webinar.maxAttendees}',
                          'Max Seats',
                        ),
                      _buildStatItem(
                        Icons.attach_money,
                        webinar.isFree == true ? 'Free' : '₹${webinar.fees?.toInt() ?? 0}',
                        'Price',
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
    );
  }
}
