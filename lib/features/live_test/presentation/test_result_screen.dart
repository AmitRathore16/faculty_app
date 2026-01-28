import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class TestResultScreen extends ConsumerWidget {
  final String resultId;

  const TestResultScreen({super.key, required this.resultId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extra = GoRouterState.of(context).extra;

    // ✅ Dynamic result received from LiveTestScreen
    final result = (extra is Map<String, dynamic>) ? extra : <String, dynamic>{};

    final score = (result['score'] is num) ? (result['score'] as num).toDouble() : 0.0;
    final totalMarks =
    (result['totalMarks'] is num) ? (result['totalMarks'] as num).toDouble() : 0.0;

    final correct = (result['correct'] is num) ? (result['correct'] as num).toInt() : 0;
    final wrong = (result['wrong'] is num) ? (result['wrong'] as num).toInt() : 0;
    final unattempted =
    (result['unattempted'] is num) ? (result['unattempted'] as num).toInt() : 0;

    final percentage =
    (result['percentage'] is num) ? (result['percentage'] as num).toDouble() : 0.0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Score circle
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        score.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'out of ${totalMarks.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Result message
              Text(
                _getResultMessage(percentage),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You scored ${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: AppColors.grey600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),

              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Correct',
                      '$correct',
                      AppColors.success,
                      Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Wrong',
                      '$wrong',
                      AppColors.error,
                      Icons.cancel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Skipped',
                      '$unattempted',
                      AppColors.grey500,
                      Icons.remove_circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Performance breakdown (calculated)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance Breakdown',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildProgressRow('Score', percentage.toInt(), AppColors.primary),
                    _buildProgressRow(
                      'Completion',
                      (correct + wrong + unattempted) == 0
                          ? 0
                          : (((correct + wrong) / (correct + wrong + unattempted)) * 100).round(),
                      AppColors.accent,
                    ),
                    _buildProgressRow(
                      'Accuracy',
                      (correct + wrong) == 0 ? 0 : ((correct / (correct + wrong)) * 100).round(),
                      AppColors.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Future: View solutions
                      },
                      icon: const Icon(Icons.visibility),
                      label: const Text('View Solutions'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.home),
                      label: const Text('Go Home'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getResultMessage(double percentage) {
    if (percentage >= 90) return 'Excellent! 🎉';
    if (percentage >= 75) return 'Great Job! 👏';
    if (percentage >= 60) return 'Good Effort! 👍';
    if (percentage >= 40) return 'Keep Practicing! 💪';
    return 'Needs Improvement 📚';
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, int percentage, Color color) {
    final safeValue = percentage < 0 ? 0 : (percentage > 100 ? 100 : percentage);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                '$safeValue%',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: safeValue / 100,
            backgroundColor: AppColors.grey200,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
