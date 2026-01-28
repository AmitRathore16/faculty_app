import 'dart:async';

import 'package:faculty_pedia/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/test_series_model.dart';
import '../../../shared/widgets/state_widgets.dart';

/// ==============================
/// Providers
/// ==============================

final testDetailProvider =
FutureProvider.family.autoDispose<Test, String>((ref, testId) async {
  final api = ApiService();
  final response = await api.get('/api/tests/$testId');
  final data = response.data;

  // backend: { success:true, data:test }
  final testJson = (data is Map && data['data'] != null) ? data['data'] : data;

  return Test.fromJson(Map<String, dynamic>.from(testJson));
});

final testQuestionsProvider =
FutureProvider.family.autoDispose<List<Question>, String>((ref, testId) async {
  final api = ApiService();
  final response = await api.get('/api/tests/$testId/questions?limit=200');

  final data = response.data;

  // backend:
  // { success:true, data:{ questions:[...], pagination:{} } }
  final list = (data is Map && data['data'] != null)
      ? (data['data']['questions'] as List? ?? [])
      : (data['questions'] as List? ?? []);

  final questions = list
      .map((e) => Question.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  /// ✅ KEEP ALL QUESTIONS (integer + mcq)
  /// But remove completely invalid ones
  final filtered = questions.where((q) {
    // must have text at least
    if ((q.text ?? '').trim().isEmpty) return false;

    final type = q.questionType ?? '';

    // integer type can have no options
    if (type == 'integer') return true;

    // single/multi select must have options
    if (type == 'single-select' || type == 'multi-select') {
      return q.options.length >= 2;
    }

    // unknown type -> ignore to avoid UI crash
    return false;
  }).toList();

  return filtered;
});

/// ==============================
/// Screen
/// ==============================

class LiveTestScreen extends ConsumerStatefulWidget {
  final String testId;

  const LiveTestScreen({super.key, required this.testId});

  @override
  ConsumerState<LiveTestScreen> createState() => _LiveTestScreenState();
}

class _LiveTestScreenState extends ConsumerState<LiveTestScreen> {
  int _currentQuestion = 0;

  /// Answers:
  /// - single-select => int optionIndex
  /// - multi-select => Set<int> selectedIndices
  /// - integer      => String
  final Map<int, dynamic> _answers = {};
  final Map<int, TextEditingController> _integerControllers = {};

  Duration _remainingTime = const Duration(minutes: 60);
  bool _testStarted = false;

  Timer? _timer;

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingTime.inSeconds <= 0) {
        _timer?.cancel();

        final test = ref.read(testDetailProvider(widget.testId)).value;
        final questions = ref.read(testQuestionsProvider(widget.testId)).value;

        if (test != null && questions != null && questions.isNotEmpty) {
          _submitTest(test, questions);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _remainingTime -= const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();

    for (final c in _integerControllers.values) {
      c.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final testAsync = ref.watch(testDetailProvider(widget.testId));
    final questionsAsync = ref.watch(testQuestionsProvider(widget.testId));

    return testAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: ErrorStateWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(testDetailProvider(widget.testId)),
        ),
      ),
      data: (test) {
        return questionsAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Scaffold(
            body: ErrorStateWidget(
              message: error.toString(),
              onRetry: () => ref.invalidate(testQuestionsProvider(widget.testId)),
            ),
          ),
          data: (questions) {
            if (questions.isEmpty) {
              return const Scaffold(
                body: EmptyStateWidget(
                  icon: Icons.quiz_outlined,
                  title: 'No Questions Available',
                  subtitle: 'This test does not contain any valid questions yet.',
                ),
              );
            }

            // timer duration from backend
            if (!_testStarted && (test.duration ?? 0) > 0) {
              _remainingTime = Duration(minutes: test.duration!);
            }

            if (!_testStarted) {
              return _buildStartScreen(test, questions);
            }

            return WillPopScope(
              onWillPop: () async => await _showExitDialog(),
              child: _buildTestScreen(test, questions),
            );
          },
        );
      },
    );
  }

  /// ==============================
  /// Test UI
  /// ==============================

  Scaffold _buildTestScreen(Test test, List<Question> questions) {
    final currentQ = questions[_currentQuestion];
    final type = currentQ.questionType ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentQuestion + 1}/${questions.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            if (await _showExitDialog()) {
              if (mounted) context.pop();
            }
          },
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _remainingTime.inMinutes < 5
                  ? AppColors.error.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: _remainingTime.inMinutes < 5
                      ? AppColors.error
                      : AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormatter.formatCountdown(_remainingTime),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _remainingTime.inMinutes < 5
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentQuestion + 1) / questions.length,
            backgroundColor: AppColors.grey200,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question number and marks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Question ${_currentQuestion + 1}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '+${currentQ.marks ?? 0}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(' / '),
                          Text(
                            '-${currentQ.negativeMarks ?? 0}',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Question type chip
                  if (type.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(fontSize: 12, color: AppColors.grey700),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Question text
                  Text(
                    currentQ.text ?? '',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  /// ✅ Render based on type
                  if (type == 'integer')
                    _buildIntegerInput(currentQ)
                  else if (type == 'single-select')
                    _buildSingleSelectOptions(currentQ)
                  else if (type == 'multi-select')
                      _buildMultiSelectOptions(currentQ)
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.grey100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Unsupported question type: $type',
                          style: TextStyle(color: AppColors.grey700),
                        ),
                      ),
                ],
              ),
            ),
          ),

          // Navigation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentQuestion > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _currentQuestion--;
                        });
                      },
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentQuestion > 0) const SizedBox(width: 12),
                Expanded(
                  flex: _currentQuestion > 0 ? 1 : 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentQuestion < questions.length - 1) {
                        setState(() {
                          _currentQuestion++;
                        });
                      } else {
                        _submitTest(test, questions);
                      }
                    },
                    child: Text(
                      _currentQuestion < questions.length - 1
                          ? 'Next'
                          : 'Submit Test',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegerInput(Question currentQ) {
    final controller = _integerControllers.putIfAbsent(
      _currentQuestion,
          () => TextEditingController(
        text: (_answers[_currentQuestion] as String?) ?? '',
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter your answer',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.grey800,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Type answer (numbers only)',
            filled: true,
            fillColor: AppColors.grey100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.grey300),
            ),
          ),
          onChanged: (val) {
            _answers[_currentQuestion] = val.trim();
          },
        ),
      ],
    );
  }

  Widget _buildSingleSelectOptions(Question currentQ) {
    final selected = _answers[_currentQuestion] as int?;

    return Column(
      children: currentQ.options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final isSelected = selected == index;

        return GestureDetector(
          onTap: () {
            setState(() {
              _answers[_currentQuestion] = index;
            });
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.grey300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.grey100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index),
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.grey600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.text ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      color: isSelected ? AppColors.primary : AppColors.grey800,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppColors.primary),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMultiSelectOptions(Question currentQ) {
    final selectedSet = (_answers[_currentQuestion] as Set<int>?) ?? <int>{};

    return Column(
      children: currentQ.options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final isSelected = selectedSet.contains(index);

        return GestureDetector(
          onTap: () {
            setState(() {
              final copy = <int>{...selectedSet};
              if (copy.contains(index)) {
                copy.remove(index);
              } else {
                copy.add(index);
              }
              _answers[_currentQuestion] = copy;
            });
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.grey300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.grey100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isSelected
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : Text(
                      String.fromCharCode(65 + index),
                      style: TextStyle(
                        color: AppColors.grey600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.text ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      color: isSelected ? AppColors.primary : AppColors.grey800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// ==============================
  /// Start Screen
  /// ==============================

  Widget _buildStartScreen(Test test, List<Question> questions) {
    final totalMarks = questions.fold<int>(0, (sum, q) => sum + (q.marks ?? 0));
    final duration = test.duration ?? _remainingTime.inMinutes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Instructions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    test.title ?? 'Practice Test',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildInfoChip(Icons.quiz, '${questions.length} Questions'),
                      _buildInfoChip(Icons.timer, '$duration Minutes'),
                      _buildInfoChip(Icons.star, '$totalMarks Marks'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Instructions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _buildInstructionItem('1', 'This test contains ${questions.length} questions.'),
            _buildInstructionItem('2', 'Total time allowed is $duration minutes.'),
            _buildInstructionItem('3', 'MCQ + Multi-select + Integer questions supported.'),
            _buildInstructionItem('4', 'You can review and change answers before submission.'),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _testStarted = true;
                    _currentQuestion = 0;
                  });
                  _startTimer();
                },
                child: const Text('Start Test'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Test?'),
        content: const Text(
          'Are you sure you want to exit? Your progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// ==============================
  /// Submit Test
  /// ==============================

  Future<void> _submitTest(Test test, List<Question> questions) async {
    _timer?.cancel();

    int correct = 0;
    int wrong = 0;
    int unattempted = 0;
    double score = 0;

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final type = q.questionType ?? '';

      final ans = _answers[i];

      if (ans == null || (ans is String && ans.trim().isEmpty) || (ans is Set && ans.isEmpty)) {
        unattempted++;
        continue;
      }

      // ✅ compare based on type
      final bool? isCorrect = _checkCorrect(q, ans);
      if (isCorrect == null) continue;

      if (isCorrect) {
        correct++;
        score += (q.marks ?? 0);
      } else {
        wrong++;
        score -= (q.negativeMarks ?? 0);
      }
    }

    if (score < 0) score = 0;

    final totalMarks = questions.fold<int>(0, (sum, q) => sum + (q.marks ?? 0));
    final percentage = totalMarks == 0 ? 0 : (score / totalMarks) * 100;
    final authState = ref.read(authStateProvider);
    final user = authState.user;
    if (user != null) {
      try {
        final api = ApiService();
        final res = await api.post('/api/tests/${widget.testId}/submit', data: {
          "studentId": user.id,
          "score": score,
          "totalMarks": totalMarks,
          "percentage": percentage,
          "correctAnswers": correct,
          "wrongAnswers": wrong,
          "unattempted": unattempted,
        });

        if (res.data == null || res.data['success'] != true) {
          throw Exception(res.data?['message'] ?? "Submit failed");
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Submit failed: $e")),
          );
        }
        return; // ✅ stop navigation if submit fails
      }
    }


    context.go(
      '/test-result/${widget.testId}',
      extra: {
        "score": score,
        "totalMarks": totalMarks,
        "correct": correct,
        "wrong": wrong,
        "unattempted": unattempted,
        "percentage": percentage,
      },
    );
  }

  /// returns:
  /// true/false => correctness
  /// null => cannot evaluate
  bool? _checkCorrect(Question q, dynamic ans) {
    final type = q.questionType ?? '';

    // integer => correctOptions is number
    if (type == 'integer') {
      final correct = q.correctIntegerAnswer;
      if (correct == null) return null;

      final user = int.tryParse((ans as String).trim());
      if (user == null) return false;

      return user == correct;
    }

    // single-select => compare index
    if (type == 'single-select') {
      final correctIndex = q.correctOption;
      if (correctIndex == null) return null;
      return (ans is int) && ans == correctIndex;
    }

    // multi-select => compare set
    if (type == 'multi-select') {
      final correctSet = q.correctOptionsSet;
      if (correctSet == null || correctSet.isEmpty) return null;
      if (ans is! Set<int>) return false;

      return ans.length == correctSet.length && ans.containsAll(correctSet);
    }

    return null;
  }
}
