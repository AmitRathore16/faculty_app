import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/webinar_model.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';

// Webinars Provider
final webinarsProvider = FutureProvider.autoDispose<List<Webinar>>((ref) async {
  final api = ApiService();
  final response = await api.get('/api/webinars');
  final data = response.data;

  List<dynamic> webinarsList = [];

  // ✅ backend: { success, message, data: { webinars: [] } }
  if (data is Map &&
      data['data'] is Map &&
      data['data']['webinars'] is List) {
    webinarsList = data['data']['webinars'] as List;
  }
  // ✅ fallback: { webinars: [] }
  else if (data is Map && data['webinars'] is List) {
    webinarsList = data['webinars'] as List;
  }
  // ✅ fallback: []
  else if (data is List) {
    webinarsList = data;
  }

  debugPrint("✅ webinars found = ${webinarsList.length}");

  return webinarsList.map((e) => Webinar.fromJson(e)).toList();
});


class WebinarsScreen extends ConsumerWidget {
  const WebinarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webinarsAsync = ref.watch(webinarsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Webinars'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(webinarsProvider);
        },
        child: webinarsAsync.when(
          loading: () => const ShimmerList(itemCount: 4, itemHeight: 180),
          error: (error, stack) => ErrorStateWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(webinarsProvider),
          ),
          data: (webinars) {
            if (webinars.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.videocam_outlined,
                title: 'No Webinars Available',
                subtitle: 'Check back later for upcoming webinars',
              );
            }
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: webinars.length,
              itemBuilder: (context, index) {
                return _WebinarCard(webinar: webinars[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _WebinarCard extends StatelessWidget {
  final Webinar webinar;
  
  const _WebinarCard({required this.webinar});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/webinar/${webinar.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with status badge
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  color: AppColors.grey200,
                  child: webinar.imageUrl.isNotEmpty
                      ? Image.network(
                          webinar.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _buildStatusBadge(),
                ),
                if (webinar.isFree == true)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FREE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    webinar.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Educator info
                  if (webinar.educatorName != null)
                    Row(
                      children: [
                        UserAvatar(
                          imageUrl: webinar.educatorImage,
                          name: webinar.educatorName,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          webinar.educatorName!,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  
                  // Date and time
                  if (webinar.scheduledAt != null)
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: AppColors.grey600),
                        const SizedBox(width: 6),
                        Text(
                          DateFormatter.formatDateTime(webinar.scheduledAt!),
                          style: TextStyle(
                            color: AppColors.grey600,
                            fontSize: 13,
                          ),
                        ),
                        if (webinar.duration != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.timer, size: 14, color: AppColors.grey600),
                          const SizedBox(width: 4),
                          Text(
                            '${webinar.duration} min',
                            style: TextStyle(
                              color: AppColors.grey600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 16),
                  
                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push('/webinar/${webinar.id}'),
                      child: Text(_getButtonText()),
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
        Icons.videocam_outlined,
        size: 48,
        color: AppColors.grey400,
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;
    
    if (webinar.isLive) {
      color = AppColors.error;
      text = '● LIVE';
    } else if (webinar.isUpcoming) {
      color = AppColors.primary;
      text = 'UPCOMING';
    } else {
      color = AppColors.grey500;
      text = 'ENDED';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getButtonText() {
    if (webinar.isLive) return 'Join Now';
    if (webinar.isUpcoming) return 'Register';
    return 'View Recording';
  }
}
