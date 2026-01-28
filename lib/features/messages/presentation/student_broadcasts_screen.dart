import 'dart:convert';

import 'package:faculty_pedia/features/auth/providers/auth_provider.dart';
import 'package:faculty_pedia/features/messages/presentation/messages_home_screen.dart'
    show notificationUnreadCountProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';

String? _getStudentIdSync() {
  final userDataJson = StorageService.getString(AppConfig.userDataKey);
  if (userDataJson == null || userDataJson.isEmpty) return null;

  final map = jsonDecode(userDataJson);
  return (map['_id'] ?? map['id'])?.toString();
}

final broadcastProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final studentId = _getStudentIdSync();
  if (studentId == null) return [];

  final res = await api.get(
    '/api/notifications/$studentId',
    queryParameters: {
      'type': 'broadcast_message',
      'page': 1,
      'limit': 50,
    },
  );

  dynamic data = res.data;
  if (data is String) data = jsonDecode(data);

  final list = (data['data']?['notifications'] ?? data['notifications']) as List? ?? [];
  return list.map((e) => Map<String, dynamic>.from(e)).toList();
});

class StudentBroadcastsScreen extends ConsumerWidget {
  const StudentBroadcastsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(broadcastProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(broadcastProvider);
        ref.invalidate(notificationUnreadCountProvider);
      },
      child: async.when(
        loading: () => const ShimmerList(itemCount: 8, itemHeight: 110),
        error: (e, st) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () {
            ref.invalidate(broadcastProvider);
            ref.invalidate(notificationUnreadCountProvider);
          },
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.campaign_outlined,
              title: 'No Broadcasts',
              subtitle: 'Broadcast messages from educators will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final n = items[index];

              final id = (n['_id'] ?? '').toString();
              final title = (n['title'] ?? 'Broadcast').toString();
              final message = (n['message'] ?? '').toString();
              final isRead = (n['isRead'] ?? false) == true;
              final createdAt = (n['createdAt'] ?? '').toString();

              final sender = n['sender'];
              String senderName = 'Educator';
              String? senderImage;

              if (sender is Map) {
                senderName = (sender['fullName'] ?? sender['name'] ?? sender['username'] ?? 'Educator').toString();
                senderImage = (sender['profilePicture'] ?? sender['image'] ?? '')?.toString();
              }

              return Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: () async {
                    await _markNotificationRead(id);
                    ref.invalidate(broadcastProvider);
                    ref.invalidate(notificationUnreadCountProvider);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserAvatar(
                          imageUrl: senderImage,
                          name: senderName,
                          size: 52,
                          showBorder: !isRead,
                          borderColor: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      senderName,
                                      style: Theme.of(context).textTheme.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                message,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.grey700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatDate(createdAt),
                                style: const TextStyle(fontSize: 11, color: AppColors.grey600),
                              ),
                            ],
                          ),
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

  Future<void> _markNotificationRead(String notificationId) async {
    try {
      final api = ApiService();
      final studentId = _getStudentIdSync();
      if (studentId == null) return;

      await api.put(
        '/api/notifications/$notificationId/read',
        data: {'studentId': studentId},
      );
    } catch (_) {}
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
