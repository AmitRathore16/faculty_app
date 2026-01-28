import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/state_widgets.dart';

final _apiProvider = Provider<ApiService>((ref) => ApiService());

class QueryMessage {
  final String id;
  final String content;
  final DateTime createdAt;
  final String senderType;

  QueryMessage({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.senderType,
  });

  factory QueryMessage.fromJson(Map<String, dynamic> json) {
    return QueryMessage(
      id: (json['_id'] ?? json['id']).toString(),
      content: (json['content'] ?? '').toString(),
      senderType: (json['sender']?['userType'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class QueryDetailData {
  final Map<String, dynamic> query;
  final List<QueryMessage> messages;

  QueryDetailData({required this.query, required this.messages});
}

final queryDetailsProvider =
FutureProvider.family.autoDispose<QueryDetailData, String>((ref, id) async {
  final api = ref.watch(_apiProvider);
  final res = await api.get('/api/queries/$id');

  dynamic raw = res.data;
  if (raw is String) raw = jsonDecode(raw);

  final data = raw?['data'];
  final query = Map<String, dynamic>.from(data?['query'] ?? {});
  final msgs = (data?['messages'] ?? []) as List;

  return QueryDetailData(
    query: query,
    messages: msgs.map((e) => QueryMessage.fromJson(Map<String, dynamic>.from(e))).toList(),
  );
});

class StudentQueryDetailsScreen extends ConsumerWidget {
  final String queryId;
  const StudentQueryDetailsScreen({super.key, required this.queryId});

  Color _statusColor(String status) {
    switch (status) {
      case "replied":
        return Colors.blue;
      case "resolved":
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(queryDetailsProvider(queryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Query Details"),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(queryDetailsProvider(queryId)),
        ),
        data: (data) {
          final q = data.query;
          final subject = q['subject']?.toString() ?? '';
          final status = q['status']?.toString() ?? 'pending';

          final educator = q['educatorId'];
          final educatorName = educator is Map ? (educator['fullName'] ?? educator['username']) : "Educator";

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.grey100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "To: $educatorName",
                            style: TextStyle(color: AppColors.grey700, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: data.messages.length,
                  itemBuilder: (_, i) {
                    final m = data.messages[i];

                    final isStudentSender = m.senderType.toLowerCase() == "student"; // ✅ FIX

                    return Align(
                      alignment: isStudentSender ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isStudentSender
                              ? AppColors.primary.withOpacity(0.12) // ✅ your message
                              : AppColors.grey100, // ✅ educator message
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          m.content,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },

                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _resolveQuery(BuildContext context, WidgetRef ref) async {
    try {
      final api = ref.read(_apiProvider);
      await api.put('/api/queries/$queryId/resolve');
      ref.invalidate(queryDetailsProvider(queryId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Query marked as resolved")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  Future<void> _deleteQuery(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Query?"),
        content: const Text("This will remove query from active list."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final api = ref.read(_apiProvider);
      await api.delete('/api/queries/$queryId');

      if (!context.mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Query deleted")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }
}
