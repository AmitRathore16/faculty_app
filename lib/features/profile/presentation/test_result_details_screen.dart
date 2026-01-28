import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/student_model.dart';

class TestResultDetailsScreen extends StatelessWidget {
  final TestResult result;
  const TestResultDetailsScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Result Details")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.grey200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv("Test Title", result.title ?? "-"),
                _kv("Test ID", result.testId ?? "-"),
                _kv("Test Series ID", result.seriesId ?? "-"),
                _kv("Score", "${result.score ?? 0}"),
                _kv("Total Marks", "${result.totalMarks ?? 0}"),
                _kv("Percentage", "${result.percentage.toStringAsFixed(2)}%"),
                _kv("Correct", "${result.correctAnswers ?? 0}"),
                _kv("Wrong", "${result.wrongAnswers ?? 0}"),
                _kv("Unattempted", "${result.unattempted ?? 0}"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              k,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.grey800,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(v, style: const TextStyle(color: AppColors.grey700)),
          ),
        ],
      ),
    );
  }
}
