import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/student_model.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../auth/providers/auth_provider.dart';

/// ✅ Provider inside screen file
final myTestResultsProvider = FutureProvider.autoDispose<Student>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.user;

  if (user == null) throw Exception("Please login");

  final api = ApiService();
  final res = await api.get('/api/students/${user.id}');

  final data = res.data['data']; // backend: {success:true, data:{student}}
  return Student.fromJson(data);
});

class MyTestResultsScreen extends ConsumerWidget {
  const MyTestResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStudent = ref.watch(myTestResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("My Test Results")),
      body: asyncStudent.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          title: "Failed to load test results",
          message: e.toString(),
          onRetry: () => ref.invalidate(myTestResultsProvider),
        ),
        data: (student) {
          final results = student.results;
          if (results.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.assignment_outlined,
              title: "No Results Yet",
              subtitle: "You haven't completed any tests yet.",
            );
          }

          final sorted = [...results]
            ..sort((a, b) {
              final da = a.completedAt ?? DateTime(1970);
              final db = b.completedAt ?? DateTime(1970);
              return db.compareTo(da);
            });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final r = sorted[index];
              final percent = r.percentage.toStringAsFixed(0);

              return InkWell(
                onTap: () => context.push('/my-test-results/details', extra: r),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          "$percent%",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Test Title: ${r.title ?? "-"}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Test ID: ${r.testId ?? "-"}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Score: ${r.score ?? 0} / ${r.totalMarks ?? 0}",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.grey700),
                            ),
                            if (r.completedAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Attempted: ${_formatDate(r.completedAt!)}",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.grey600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.grey400),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return "${d.day.toString().padLeft(2, '0')}-"
        "${d.month.toString().padLeft(2, '0')}-${d.year}";
  }
}
