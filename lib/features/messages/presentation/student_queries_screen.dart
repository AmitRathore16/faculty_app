import 'dart:convert';

import 'package:faculty_pedia/features/messages/presentation/show_query_details_screen.dart';
import 'package:faculty_pedia/features/profile/presentation/profile_screen.dart';
import 'package:faculty_pedia/shared/models/student_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../auth/providers/auth_provider.dart';

/// -----------------
/// Model
/// -----------------
class StudentQuery {
  final String id;
  final String subject;
  final String initialMessage;
  final String status; // pending/replied/resolved

  final DateTime createdAt;
  final DateTime updatedAt;

  final QueryEducator? educator;

  const StudentQuery({
    required this.id,
    required this.subject,
    required this.initialMessage,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.educator,
  });

  static DateTime _dt(dynamic v) =>
      DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

  factory StudentQuery.fromJson(Map<String, dynamic> json) {
    return StudentQuery(
      id: (json['_id'] ?? json['id']).toString(),
      subject: (json['subject'] ?? '').toString(),
      initialMessage: (json['initialMessage'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: _dt(json['createdAt']),
      updatedAt: _dt(json['updatedAt']),
      educator: json['educatorId'] is Map<String, dynamic>
          ? QueryEducator.fromJson(
        Map<String, dynamic>.from(json['educatorId']),
      )
          : null,
    );
  }
}

class QueryEducator {
  final String id;
  final String? fullName;
  final String? username;
  final String? email;

  const QueryEducator({
    required this.id,
    this.fullName,
    this.username,
    this.email,
  });

  factory QueryEducator.fromJson(Map<String, dynamic> json) {
    return QueryEducator(
      id: (json['_id'] ?? json['id']).toString(),
      fullName: json['fullName']?.toString(),
      username: json['username']?.toString(),
      email: json['email']?.toString(),
    );
  }
}

String? _getStudentIdSync() {
  final userDataJson = StorageService.getString(AppConfig.userDataKey);
  if (userDataJson == null || userDataJson.isEmpty) return null;
  final map = jsonDecode(userDataJson);
  return (map['_id'] ?? map['id'])?.toString();
}

final _apiProvider = Provider<ApiService>((ref) => ApiService());

final studentQueriesProvider =
FutureProvider.autoDispose<List<StudentQuery>>((ref) async {
  final studentId = _getStudentIdSync();
  if (studentId == null) return [];

  final api = ref.watch(_apiProvider);

  final res = await api.get('/api/queries/student/$studentId');

  dynamic raw = res.data;
  if (raw is String) raw = jsonDecode(raw);

  final list = raw?['data']?['queries'] ?? [];
  if (list is! List) return [];

  return list
      .map((e) => StudentQuery.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

final queryFilterProvider =
StateProvider.autoDispose<String>((ref) => "all"); // all/pending/replied/resolved
final querySearchProvider = StateProvider.autoDispose<String>((ref) => "");

class StudentQueriesScreen extends ConsumerWidget {
  const StudentQueriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queriesAsync = ref.watch(studentQueriesProvider);
    final filter = ref.watch(queryFilterProvider);
    final search = ref.watch(querySearchProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateQuerySheet(context: context, ref: ref),
        icon: const Icon(Icons.add),
        label: const Text("New Query"),
      ),
      body: queriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(studentQueriesProvider),
        ),
        data: (queries) {
          // filter + search
          var filtered = queries;

          if (filter != "all") {
            filtered = filtered.where((q) => q.status == filter).toList();
          }

          if (search.trim().isNotEmpty) {
            final s = search.trim().toLowerCase();
            filtered = filtered.where((q) {
              return q.subject.toLowerCase().contains(s) ||
                  q.initialMessage.toLowerCase().contains(s) ||
                  (q.educator?.fullName?.toLowerCase().contains(s) ?? false);
            }).toList();
          }

          return Column(
            children: [
              _SearchBar(
                onChanged: (v) =>
                ref.read(querySearchProvider.notifier).state = v,
              ),
              _FilterChips(
                selected: filter,
                onChanged: (v) =>
                ref.read(queryFilterProvider.notifier).state = v,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyStateWidget(
                  icon: Icons.help_outline,
                  title: "No queries found",
                  subtitle: "Try changing filter or create a new query.",
                )
                    : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(studentQueriesProvider);
                    await ref.read(studentQueriesProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (_, i) => _QueryTile(query: filtered[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: "Search query...",
          filled: true,
          fillColor: AppColors.grey100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String v, String label) {
      final active = selected == v;
      return ChoiceChip(
        selected: active,
        label: Text(label),
        onSelected: (_) => onChanged(v),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          chip("all", "All"),
          chip("pending", "Pending"),
          chip("replied", "Replied"),
          chip("resolved", "Resolved"),
        ],
      ),
    );
  }
}

class _QueryTile extends ConsumerWidget {
  final StudentQuery query;
  const _QueryTile({required this.query});

  Color _statusColor() {
    switch (query.status) {
      case "replied":
        return Colors.blue;
      case "resolved":
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _statusText() {
    switch (query.status) {
      case "replied":
        return "REPLIED";
      case "resolved":
        return "RESOLVED";
      default:
        return "PENDING";
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final educatorName = query.educator?.fullName ?? "Educator";

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentQueryDetailsScreen(queryId: query.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    query.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _statusColor().withOpacity(0.25)),
                  ),
                  child: Text(
                    _statusText(),
                    style: TextStyle(
                      color: _statusColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "To: $educatorName",
              style: TextStyle(
                color: AppColors.grey700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              query.initialMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.grey800),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ helper: unresolved query check
bool _hasUnresolvedQuery({
  required List<StudentQuery> queries,
  required String educatorId,
}) {
  return queries.any((q) {
    final qEduId = q.educator?.id;
    if (qEduId == null) return false;

    final status = q.status.toLowerCase();
    return qEduId == educatorId && status != "resolved";
  });
}

Future<void> _showCreateQuerySheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final subjectCtrl = TextEditingController();
  final messageCtrl = TextEditingController();
  final student = await ref.read(studentProfileProvider.future);

  final studentId = student.id;

  final followingEducators =
  student.followingEducators.map((e) => e.toString().trim()).toSet();

  if (followingEducators.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You are not following any educators.")),
    );
    return;
  }


  // ✅ Fetch educator list
  final api = ref.read(_apiProvider);

  final res = await api.get("/api/educators");
  dynamic raw = res.data;
  if (raw is String) raw = jsonDecode(raw);

  final list = raw?["data"]?["educators"] ?? raw?["educators"] ?? [];
  final educators = (list is List ? list : [])
      .map((e) => Map<String, dynamic>.from(e))
      .where(
          (e) => followingEducators.contains((e["_id"] ?? e["id"]).toString()))
      .toList();

  if (educators.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No following educators found.")),
    );
    return;
  }

  String selectedEducatorId =
  (educators.first["_id"] ?? educators.first["id"]).toString();
  String selectedEducatorName =
  (educators.first["fullName"] ?? educators.first["name"] ?? "Educator")
      .toString();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Create Query",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),

                // educator dropdown
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: "Educator",
                    filled: true,
                    fillColor: AppColors.grey100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedEducatorId,
                      isExpanded: true,
                      items: educators.map((e) {
                        final id = (e["_id"] ?? e["id"]).toString();
                        final name =
                        (e["fullName"] ?? e["name"] ?? "Educator").toString();
                        return DropdownMenuItem(
                          value: id,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final edu = educators.firstWhere(
                              (e) => (e["_id"] ?? e["id"]).toString() == v,
                        );
                        setModalState(() {
                          selectedEducatorId = v;
                          selectedEducatorName =
                              (edu["fullName"] ?? edu["name"] ?? "Educator")
                                  .toString();
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: subjectCtrl,
                  decoration: InputDecoration(
                    labelText: "Subject",
                    hintText: "Eg. Doubt in Chapter 5",
                    filled: true,
                    fillColor: AppColors.grey100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: messageCtrl,
                  minLines: 4,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: "Message",
                    hintText: "Write your query clearly...",
                    filled: true,
                    fillColor: AppColors.grey100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final subject = subjectCtrl.text.trim();
                      final message = messageCtrl.text.trim();

                      if (subject.isEmpty || message.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Subject and message are required"),
                          ),
                        );
                        return;
                      }

                      // ✅ BLOCK: if previous query with same educator not resolved
                      final existingQueries =
                          ref.read(studentQueriesProvider).asData?.value ?? [];

                      final blocked = _hasUnresolvedQuery(
                        queries: existingQueries,
                        educatorId: selectedEducatorId,
                      );

                      if (blocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                            Text("Previous query is not resolved yet"),
                          ),
                        );
                        return;
                      }

                      try {
                        final api = ref.read(_apiProvider);

                        await api.post(
                          "/api/queries",
                          data: {
                            "studentId": studentId,
                            "educatorId": selectedEducatorId,
                            "subject": subject,
                            "initialMessage": message,
                            "metadata": {},
                          },
                        );

                        if (context.mounted) Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                            Text("Query sent to $selectedEducatorName ✅"),
                          ),
                        );

                        ref.invalidate(studentQueriesProvider);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to send query: $e")),
                        );
                      }
                    },
                    icon: const Icon(Icons.send),
                    label: const Text("Send Query"),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
