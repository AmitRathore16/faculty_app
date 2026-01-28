import 'dart:convert';

import 'package:faculty_pedia/features/auth/providers/auth_provider.dart';
import 'package:faculty_pedia/features/messages/provider/chat_spcket_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../provider/chat_providers.dart';
import 'student_broadcasts_screen.dart';
import 'student_conversations_screen.dart';
import 'student_queries_screen.dart'; // ✅ ADD

String? _getStudentIdSync() {
  final userDataJson = StorageService.getString(AppConfig.userDataKey);
  if (userDataJson == null || userDataJson.isEmpty) return null;

  final map = jsonDecode(userDataJson);
  return (map['_id'] ?? map['id'])?.toString();
}

final notificationUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final studentId = _getStudentIdSync();
  if (studentId == null) return 0;

  final res = await api.get('/api/notifications/$studentId/unread-count');

  dynamic data = res.data;
  if (data is String) data = jsonDecode(data);

  final unreadCount = data?['data']?['unreadCount'] ?? data?['unreadCount'] ?? 0;
  return int.tryParse(unreadCount.toString()) ?? 0;
});

// ✅ Optional (badge) – can be 0 if API not available
final queryUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  // If you have unread count API for queries later, add here.
  // For now no API change -> return 0.
  return 0;
});

class MessagesHomeScreen extends ConsumerStatefulWidget {
  const MessagesHomeScreen({super.key});

  @override
  ConsumerState<MessagesHomeScreen> createState() => _MessagesHomeScreenState();
}

class _MessagesHomeScreenState extends ConsumerState<MessagesHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // ✅ 3 tabs now
  }

  void _refreshAll() {
    ref.invalidate(chatUnreadCountProvider);
    ref.invalidate(notificationUnreadCountProvider);
    ref.invalidate(queryUnreadCountProvider);

    ref.invalidate(chatConversationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    // keep socket connected
    ref.watch(chatSocketControllerProvider);

    final chatUnreadAsync = ref.watch(chatUnreadCountProvider);
    final notifUnreadAsync = ref.watch(notificationUnreadCountProvider);
    final queryUnreadAsync = ref.watch(queryUnreadCountProvider);

    final chatBadge = chatUnreadAsync.asData?.value ?? 0;
    final notifBadge = notifUnreadAsync.asData?.value ?? 0;
    final queryBadge = queryUnreadAsync.asData?.value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.grey600,
            tabs: [
              _TabLabel(label: 'Chats', badge: chatBadge),
              _TabLabel(label: 'Broadcasts', badge: notifBadge),
              _TabLabel(label: 'Queries', badge: queryBadge), // ✅ new
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          StudentConversationsScreen(),
          StudentBroadcastsScreen(),
          StudentQueriesScreen(), // ✅ new
        ],
      ),
    );
  }
}

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
