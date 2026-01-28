import 'dart:async';
import 'dart:convert';

import 'package:faculty_pedia/core/config/app_config.dart';
import 'package:faculty_pedia/core/services/api_service.dart';
import 'package:faculty_pedia/core/services/storage_service.dart';
import 'package:faculty_pedia/features/messages/provider/chat_providers.dart';
import 'package:faculty_pedia/features/messages/provider/chat_spcket_provider.dart';
import 'package:faculty_pedia/features/messages/services/chat_socket_service.dart';
import 'package:faculty_pedia/shared/models/conversation_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// =====================================================
/// Helpers
/// =====================================================

String? _getStudentId() {
  final userDataJson = StorageService.getString(AppConfig.userDataKey);
  if (userDataJson == null || userDataJson.isEmpty) return null;

  final map = jsonDecode(userDataJson);
  return (map['_id'] ?? map['id'])?.toString();
}

/// =====================================================
/// Models (Notification Card)
/// =====================================================

class AppNotification {
  final String id;
  final String type; // broadcast_message / course / webinar ...
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  final String senderName;
  final String? senderImage;

  final Map<String, dynamic> metadata;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    required this.senderName,
    required this.senderImage,
    required this.metadata,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];

    String senderName = 'Educator';
    String? senderImage;

    if (sender is Map) {
      senderName =
          (sender['fullName'] ?? sender['name'] ?? sender['username'] ?? 'Educator')
              .toString();
      senderImage = (sender['profilePicture'] ?? sender['image'])?.toString();
      if (senderImage != null && senderImage!.trim().isEmpty) senderImage = null;
    }

    return AppNotification(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? 'Notification').toString(),
      message: (json['message'] ?? '').toString(),
      isRead: json['isRead'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      senderName: senderName,
      senderImage: senderImage,
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata']) : {},
    );
  }
}

/// =====================================================
/// Providers (REST API)
/// =====================================================

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final api = ApiService();
  final studentId = _getStudentId();
  if (studentId == null) return [];

  final res = await api.get(
    '/api/notifications/$studentId',
    queryParameters: {
      'page': 1,
      'limit': 50,
    },
  );

  dynamic data = res.data;
  if (data is String) data = jsonDecode(data);

  final rawList = (data['data']?['notifications'] ?? data['notifications']) as List? ?? [];
  return rawList.map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
});

final notificationUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final api = ApiService();
  final studentId = _getStudentId();
  if (studentId == null) return 0;

  final res = await api.get('/api/notifications/$studentId/unread-count');

  dynamic data = res.data;
  if (data is String) data = jsonDecode(data);

  final unread = data?['data']?['unreadCount'] ?? data?['unreadCount'] ?? 0;
  return int.tryParse(unread.toString()) ?? 0;
});

/// =====================================================
/// Screen: combined (Chats + Notifications)
/// =====================================================

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  StreamSubscription? _newMsgSub;
  StreamSubscription? _msgReadSub;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    // ✅ attach socket listeners ONCE (production safe)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socket = ref.read(chatSocketServiceProvider);

      _newMsgSub = socket.onNewMessage.listen((_) {
        ref.invalidate(chatConversationsProvider);
        ref.invalidate(chatUnreadCountProvider);
      });

      _msgReadSub = socket.onMessageRead.listen((_) {
        ref.invalidate(chatConversationsProvider);
        ref.invalidate(chatUnreadCountProvider);
      });
    });
  }

  @override
  void dispose() {
    _newMsgSub?.cancel();
    _msgReadSub?.cancel();
    _tab.dispose();
    super.dispose();
  }

  void _refreshAll() {
    // system notifications
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationUnreadCountProvider);

    // chats
    ref.invalidate(chatConversationsProvider);
    ref.invalidate(chatUnreadCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ensure socket connected (for realtime chat badge)
    ref.watch(chatSocketControllerProvider);

    final notifUnread = ref.watch(notificationUnreadCountProvider).asData?.value ?? 0;
    final chatUnread = ref.watch(chatUnreadCountProvider).asData?.value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey600,
          tabs: [
            _TabLabel(label: "Chats", badge: chatUnread),
            _TabLabel(label: "Updates", badge: notifUnread),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ChatNotificationsTab(onRefresh: _refreshAll),
          _SystemNotificationsTab(onRefresh: _refreshAll),
        ],
      ),
    );
  }
}

/// =====================================================
/// TAB 1: Chat Notifications (conversation list)
/// =====================================================

class _ChatNotificationsTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _ChatNotificationsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(chatConversationsProvider);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ListView(
          children: [
            const SizedBox(height: 120),
            Center(child: Text("Failed: $e")),
          ],
        ),
        data: (conversations) {
          final studentId = _getStudentId();

          // ✅ ONLY show chats which have unread messages
          final unreadConversations =
          conversations.where((c) => (c.unreadCount) > 0).toList();

          // ✅ newest unread first
          unreadConversations.sort((a, b) {
            final da = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final db = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });

          if (unreadConversations.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 140),
                Center(
                  child: Text(
                    "No new chat notifications",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: unreadConversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final c = unreadConversations[index];

              final other =
              studentId == null ? null : c.otherUser(currentUserId: studentId);
              final title = other?.displayName ?? "New Message";

              final last = c.lastMessage;
              final subtitle = last == null
                  ? "New message"
                  : (last.messageType == "image"
                  ? "📷 Sent an image"
                  : last.content.trim().isEmpty
                  ? "New message"
                  : last.content);

              return _ChatNotifTile(
                title: title,
                subtitle: subtitle,
                unread: c.unreadCount,
                onTap: () async {
                  if (studentId == null) return;

                  final receiver = c.otherUser(currentUserId: studentId);
                  if (receiver == null) return;

                  await context.push(
                    '/chat/${c.id}',
                    extra: {
                      "title": title,
                      "receiverId": receiver.id,
                      "receiverType": receiver.userType,
                    },
                  );

                  // ✅ after opening chat it will mark read (your provider does that)
                  // ✅ so it will disappear from Notifications tab automatically
                  ref.invalidate(chatConversationsProvider);
                  ref.invalidate(chatUnreadCountProvider);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatNotifTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int unread;
  final VoidCallback onTap;

  const _ChatNotifTile({
    required this.title,
    required this.subtitle,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.grey200,
                child: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.grey600),
                    ),
                  ],
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    unread > 99 ? "99+" : unread.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

/// =====================================================
/// TAB 2: System Notifications (broadcast/course/webinar/etc.)
/// =====================================================

class _SystemNotificationsTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _SystemNotificationsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ListView(
          children: [
            const SizedBox(height: 120),
            Center(child: Text("Failed: $e")),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text("No notifications yet")),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final n = items[index];

              return _NotificationCard(
                notification: n,
                onTap: () async {
                  await _markNotificationRead(n.id);

                  // ✅ refresh badges + list
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(notificationUnreadCountProvider);

                  // ✅ navigate if backend provides route
                  final route = (n.metadata['resourceRoute'] ?? '').toString().trim();
                  if (route.isNotEmpty) {
                    context.push(route);
                  }
                },
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
      final studentId = _getStudentId();
      if (studentId == null) return;

      await api.put(
        '/api/notifications/$notificationId/read',
        data: {'studentId': studentId},
      );
    } catch (_) {}
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.grey200,
                    child: Icon(_iconForType(notification.type), color: AppColors.primary),
                  ),
                  if (!isRead)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.senderName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.grey700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(notification.createdAt),
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
  }

  IconData _iconForType(String type) {
    switch (type) {
      case "broadcast_message":
        return Icons.campaign_outlined;
      case "webinar":
        return Icons.videocam_outlined;
      case "course":
        return Icons.play_circle_outline;
      case "post":
        return Icons.article_outlined;
      case "test_series":
        return Icons.assignment_outlined;
      case "live_class":
        return Icons.live_tv_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

/// =====================================================
/// UI
/// =====================================================

class _TabLabel extends StatelessWidget {
  final String label;
  final int badge;

  const _TabLabel({required this.label, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (badge > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge > 99 ? '99+' : badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
