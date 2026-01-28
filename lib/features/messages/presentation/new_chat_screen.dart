import 'package:faculty_pedia/features/educators/presentation/educators_screen.dart';
import 'package:faculty_pedia/features/messages/provider/chat_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/educator_model.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';
import '../../profile/presentation/profile_screen.dart';

final followingEducatorsForChatProvider = FutureProvider.autoDispose<List<Educator>>((ref) async {
  final student = await ref.watch(studentProfileProvider.future);
  final educators = await ref.watch(educatorsProvider.future);

  final followingIds = student.followingEducators.map((e) => e.toString().trim()).toSet();
  return educators.where((e) => followingIds.contains(e.id.trim())).toList();
});

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();

  String _query = '';
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Educator> _filter(List<Educator> list) {
    if (_query.isEmpty) return list;

    return list.where((e) {
      final name = e.displayName.toLowerCase();
      final subjects = e.displaySubjects.toLowerCase();
      final username = (e.username ?? '').toLowerCase();
      return name.contains(_query) || subjects.contains(_query) || username.contains(_query);
    }).toList();
  }

  Future<void> _createConversationAndOpen(Educator educator) async {
    if (_creating) return;
    setState(() => _creating = true);

    try {
      final conv = await ref.read(createConversationProvider(educator.id).future);

      if (!mounted) return;

      context.go(
        '/chat/${conv.id}',
        extra: {
          "title": educator.displayName,
          "receiverId": educator.id,
          "receiverType": "Educator",
        },
      );

      ref.invalidate(chatConversationsProvider);
      ref.invalidate(chatUnreadCountProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Widget _buildEducatorList(List<Educator> educators) {
    final filtered = _filter(educators);

    if (filtered.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off,
        title: "No Educators Found",
        subtitle: "Try a different search",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final educator = filtered[index];
        final isActive = educator.isActive;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: _creating ? null : () => _createConversationAndOpen(educator),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(
                    imageUrl: educator.imageUrl,
                    name: educator.displayName,
                    size: 66,
                    showBorder: isActive,
                    borderColor: AppColors.success,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                educator.displayName,
                                style: Theme.of(context).textTheme.titleMedium,
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
                        Text(
                          educator.displaySubjects,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.people, size: 14, color: AppColors.grey500),
                            const SizedBox(width: 4),
                            Text(
                              '${educator.followerCount} followers',
                              style: const TextStyle(fontSize: 12, color: AppColors.grey600),
                            ),
                            const SizedBox(width: 14),
                            Icon(Icons.work, size: 14, color: AppColors.grey500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                educator.displayExperience,
                                style: const TextStyle(fontSize: 12, color: AppColors.grey600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_creating) ...[
                              const SizedBox(width: 12),
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _refresh() {
    ref.invalidate(educatorsProvider);
    ref.invalidate(studentProfileProvider);
    ref.invalidate(followingEducatorsForChatProvider);
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(educatorsProvider);
    final followingAsync = ref.watch(followingEducatorsForChatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey600,
          tabs: const [
            Tab(text: 'All Educators'),
            Tab(text: 'Following'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search educator name / username / subject",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.grey100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                allAsync.when(
                  loading: () => const ShimmerList(itemCount: 8, itemHeight: 120),
                  error: (e, st) => ErrorStateWidget(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(educatorsProvider),
                  ),
                  data: (educators) {
                    if (educators.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.people_outline,
                        title: "No Educators Found",
                        subtitle: "Please try again later.",
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: _buildEducatorList(educators),
                    );
                  },
                ),
                followingAsync.when(
                  loading: () => const ShimmerList(itemCount: 8, itemHeight: 120),
                  error: (e, st) => ErrorStateWidget(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(followingEducatorsForChatProvider),
                  ),
                  data: (educators) {
                    if (educators.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.favorite_outline,
                        title: "No Following Educators",
                        subtitle: "You are not following anyone yet.",
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: _buildEducatorList(educators),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
