import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/educator_model.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';

// Educators Provider
import 'dart:convert';

final educatorsProvider = FutureProvider.autoDispose<List<Educator>>((ref) async {
  final api = ApiService();
  final response = await api.get('/api/educators');

  dynamic data = response.data;

  // ✅ IMPORTANT FIX: decode if backend response is a JSON string
  if (data is String) {
    data = jsonDecode(data);
  }

  List<dynamic> educatorsList = [];

  if (data is Map &&
      data['data'] is Map &&
      data['data']['educators'] is List) {
    educatorsList = data['data']['educators'] as List;
  }

  return educatorsList.map((e) => Educator.fromJson(e)).toList();
});


class EducatorsScreen extends ConsumerWidget {
  const EducatorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final educatorsAsync = ref.watch(educatorsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Educators'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Implement filters
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(educatorsProvider);
        },
        child: educatorsAsync.when(
          loading: () => const ShimmerList(itemCount: 6, itemHeight: 140),
          error: (error, stack) => ErrorStateWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(educatorsProvider),
          ),
          data: (educators) {
            if (educators.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.people_outline,
                title: 'No Educators Found',
                subtitle: 'Check back later for new educators',
              );
            }
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: educators.length,
              itemBuilder: (context, index) {
                return _EducatorCard(educator: educators[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

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
                        Icon(Icons.book, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            educator.displaySubjects,
                            style: TextStyle(
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
                        _buildInfoChip(
                          Icons.people,
                          '${educator.followerCount} followers',
                        ),
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          Icons.work,
                          educator.displayExperience,
                        ),
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
          style: TextStyle(
            fontSize: 12,
            color: AppColors.grey600,
          ),
        ),
      ],
    );
  }
}
