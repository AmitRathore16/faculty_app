import 'package:faculty_pedia/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/educator_model.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';
import '../../educators/presentation/educators_screen.dart';

/// ✅ PROVIDER: following educators
final followingEducatorsProvider =
FutureProvider.autoDispose<List<Educator>>((ref) async {
  final student = await ref.watch(studentProfileProvider.future);
  final educators = await ref.watch(educatorsProvider.future);

  final followingIds =
  student.followingEducators.map((e) => e.toString().trim()).toSet();

  return educators.where((e) => followingIds.contains(e.id.trim())).toList();
});


class FollowingEducatorsScreen extends ConsumerWidget {
  const FollowingEducatorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingEducatorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Following Educators"),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studentProfileProvider);
          ref.invalidate(educatorsProvider);
          ref.invalidate(followingEducatorsProvider);
        },
        child: followingAsync.when(
          loading: () => const ShimmerList(itemCount: 6, itemHeight: 140),
          error: (error, _) => ErrorStateWidget(
            message: error.toString(),
            onRetry: () {
              ref.invalidate(followingEducatorsProvider);
            },
          ),
          data: (educators) {
            if (educators.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.favorite_outline,
                title: "No Following Educators",
                subtitle: "You are not following anyone yet.",
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: educators.length,
              itemBuilder: (context, index) {
                return _FollowingEducatorCard(
                  educator: educators[index],
                  ref: ref,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FollowingEducatorCard extends StatelessWidget {
  final Educator educator;
  final WidgetRef ref;

  const _FollowingEducatorCard({
    required this.educator,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = educator.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          await context.push('/educator/${educator.id}');
          ref.invalidate(followingEducatorsProvider); // ✅ refresh when coming back
        },
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
                showBorder: isActive,
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
                        if (isActive)
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
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.grey600,
          ),
        ),
      ],
    );
  }
}
