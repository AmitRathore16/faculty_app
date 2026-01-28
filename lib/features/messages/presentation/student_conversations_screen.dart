import 'dart:async';
import 'dart:convert';

import 'package:faculty_pedia/features/auth/providers/auth_provider.dart';
import 'package:faculty_pedia/features/messages/provider/chat_providers.dart';
import 'package:faculty_pedia/features/messages/provider/chat_spcket_provider.dart';
import 'package:faculty_pedia/features/messages/services/chat_socket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/conversation_model.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';

String? _getStudentIdSync() {
  final userDataJson = StorageService.getString(AppConfig.userDataKey);
  if (userDataJson == null || userDataJson.isEmpty) return null;

  final map = jsonDecode(userDataJson);
  return (map['_id'] ?? map['id'])?.toString();
}
final queryConversationIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final api = ref.watch(apiServiceProvider); // you already have this provider in chat_providers.dart
  final studentId = _getStudentIdSync();
  if (studentId == null) return {};

  final res = await api.get('/api/queries/student/$studentId');

  dynamic raw = res.data;
  if (raw is String) raw = jsonDecode(raw);

  final list = raw?['data']?['queries'] ?? raw?['queries'] ?? [];
  if (list is! List) return {};

  return list
      .map((q) {
    final conv = q['conversationId'];
    if (conv is Map) return (conv['_id'] ?? conv['id'])?.toString();
    return conv?.toString();
  })
      .whereType<String>()
      .toSet();
});

class StudentConversationsScreen extends ConsumerStatefulWidget {
  const StudentConversationsScreen({super.key});

  @override
  ConsumerState<StudentConversationsScreen> createState() => _StudentConversationsScreenState();
}

class _StudentConversationsScreenState extends ConsumerState<StudentConversationsScreen> {
  StreamSubscription? _newMsgSub;
  StreamSubscription? _readSub;

  @override
  void initState() {
    super.initState();

    // socket listeners for list refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socket = ChatSocketService.instance;

      _newMsgSub = socket.onNewMessage.listen((_) {
        ref.invalidate(chatConversationsProvider);
        ref.invalidate(chatUnreadCountProvider);
      });

      _readSub = socket.onMessageRead.listen((_) {
        ref.invalidate(chatConversationsProvider);
        ref.invalidate(chatUnreadCountProvider);
      });
    });
  }

  @override
  void dispose() {
    _newMsgSub?.cancel();
    _readSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(chatSocketControllerProvider);

    final async = ref.watch(chatConversationsProvider);
    final studentId = _getStudentIdSync();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/chat/new'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(chatConversationsProvider);
          ref.invalidate(chatUnreadCountProvider);
        },
        child: async.when(
          loading: () => const ShimmerList(itemCount: 8, itemHeight: 90),
          error: (e, st) => ErrorStateWidget(
            message: e.toString(),
            onRetry: () {
              ref.invalidate(chatConversationsProvider);
              ref.invalidate(chatUnreadCountProvider);
            },
          ),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.chat_bubble_outline,
                title: 'No conversations yet',
                subtitle: 'Tap + to start a new chat with an educator.',
              );
            }

            // unread on top
            items.sort((a, b) => b.unreadCount.compareTo(a.unreadCount));

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ChatConversation c = items[index];

                final other = studentId == null ? null : c.otherUser(currentUserId: studentId);
                final title = other?.displayName ?? "Conversation";
                final imageUrl = other?.avatarUrl;

                final lastMessage = c.lastMessage;
                final subtitle = (lastMessage == null)
                    ? "Say hi 👋"
                    : (lastMessage.messageType == "image"
                    ? "📷 Image"
                    : lastMessage.content.trim().isEmpty
                    ? "Message"
                    : lastMessage.content);

                return _ConversationTile(
                  title: title,
                  imageUrl: imageUrl,
                  subtitle: subtitle,
                  lastAt: c.lastMessageAt?.toIso8601String(),
                  unreadCount: c.unreadCount,
                  onTap: () async {
                    if (studentId == null || studentId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Student ID not found")),
                      );
                      return;
                    }

                    final receiver = c.otherUser(currentUserId: studentId);
                    if (receiver == null || receiver.id.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Receiver not found")),
                      );
                      return;
                    }

                    await context.push(
                      '/chat/${c.id}',
                      extra: {
                        "title": title,
                        "receiverId": receiver.id,
                        "receiverType": receiver.userType, // Educator
                      },
                    );

                    ref.invalidate(chatConversationsProvider);
                    ref.invalidate(chatUnreadCountProvider);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String subtitle;
  final String? lastAt;
  final int unreadCount;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.imageUrl,
    this.lastAt,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              UserAvatar(
                imageUrl: imageUrl,
                name: title,
                size: 54,
                showBorder: true,
                borderColor: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (lastAt != null)
                    Text(
                      _formatTime(lastAt!),
                      style: const TextStyle(fontSize: 11, color: AppColors.grey600),
                    ),
                  const SizedBox(height: 8),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        unreadCount > 99 ? "99+" : unreadCount.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}
