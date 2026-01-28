import 'package:faculty_pedia/core/deep_link/app_links_config.dart';
import 'package:faculty_pedia/features/auth/providers/auth_provider.dart';
import 'package:faculty_pedia/shared/models/student_model.dart';
import 'package:faculty_pedia/shared/widgets/share_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/test_series_model.dart';
import '../../../shared/widgets/state_widgets.dart';

/// ==============================
/// Providers
/// ==============================

/// ✅ Fetch latest student from DB (same pattern as MyCourses + MyTestResults)
final currentStudentProvider = FutureProvider.autoDispose<Student>((ref) async {
  final authState = ref.watch(authStateProvider);
  final userId = authState.user?.id;

  if (userId == null) {
    throw Exception("Please login");
  }

  final api = ApiService();
  final res = await api.get('/api/students/$userId');

  final data = res.data;
  if (data is Map && data['data'] != null) {
    return Student.fromJson(Map<String, dynamic>.from(data['data']));
  }

  throw Exception("Invalid student response");
});

// Test Series Detail Provider
final testSeriesDetailProvider =
FutureProvider.family.autoDispose<TestSeries, String>((ref, id) async {
  final api = ApiService();
  final response = await api.get('/api/test-series/$id');
  debugPrint('RAW: ${response.data}');
  final data = response.data;

  Map<String, dynamic> seriesData = {};
  if (data is Map && data['testSeries'] != null) {
    seriesData = Map<String, dynamic>.from(data['testSeries']);
  } else if (data is Map) {
    seriesData = Map<String, dynamic>.from(data);
  }

  return TestSeries.fromJson(seriesData);
});

/// ✅ resolves tests list always
final testSeriesResolvedTestsProvider =
FutureProvider.family.autoDispose<List<Test>, String>((ref, seriesId) async {
  final api = ApiService();

  final series = await ref.watch(testSeriesDetailProvider(seriesId).future);
  final rawTests = series.tests ?? [];

  if (rawTests.isEmpty) return [];

  final resolved = <Test>[];

  for (final t in rawTests) {
    try {
      final res = await api.get('/api/tests/${t.id}');
      final data = res.data;

      final json = (data is Map && data['data'] != null) ? data['data'] : data;

      if (json is Map<String, dynamic>) {
        resolved.add(Test.fromJson(json));
      } else if (json is Map) {
        resolved.add(Test.fromJson(Map<String, dynamic>.from(json)));
      } else {
        resolved.add(t);
      }
    } catch (_) {
      resolved.add(t);
    }
  }

  return resolved;
});

/// ==============================
/// Screen
/// ==============================

class TestSeriesDetailsScreen extends ConsumerStatefulWidget {
  final String testSeriesId;

  const TestSeriesDetailsScreen({super.key, required this.testSeriesId});

  @override
  ConsumerState<TestSeriesDetailsScreen> createState() =>
      _TestSeriesDetailsScreenState();
}

class _TestSeriesDetailsScreenState
    extends ConsumerState<TestSeriesDetailsScreen> {
  late Razorpay _razorpay;

  bool _isProcessing = false;
  String? _currentIntentId;
  String? _currentOrderId;

  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  /// ✅ NEW: FREE enrollment for price 0
  Future<void> _enrollFreeTestSeries(TestSeries series) async {
    if (_isProcessing) return;

    final authState = ref.read(authStateProvider);
    final userId = authState.user?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to continue")),
      );
      return;
    }

    try {
      if (mounted) setState(() => _isProcessing = true);

      final api = ApiService();

      /// ✅ TestSeries enroll route (expected to enroll student)
      await api.post(
        "/api/test-series/${widget.testSeriesId}/enroll",
        data: {"studentId": userId},
      );

      if (!mounted) return;

      // refresh series + tests + student
      ref.invalidate(testSeriesDetailProvider(widget.testSeriesId));
      ref.invalidate(testSeriesResolvedTestsProvider(widget.testSeriesId));
      ref.invalidate(currentStudentProvider);

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
          title: const Text('Enrollment Successful!'),
          content:
          const Text('You have been successfully enrolled in this test series.'),
          actions: [
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("Free enroll test series failed: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Enrollment failed: $e"),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _initiateRealPayment(TestSeries series) async {
    if (_isProcessing) return;

    final authState = ref.read(authStateProvider);
    final user = authState.user;
    final userId = user?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to continue')),
      );
      return;
    }

    try {
      if (mounted) setState(() => _isProcessing = true);

      final api = ApiService();

      final response = await api.post(
        "/api/payments/orders",
        data: {
          "studentId": userId,
          "productType": "testSeries",
          "productId": widget.testSeriesId,
        },
      );

      final data = response.data["data"];

      final orderId = data["orderId"];
      final amount = data["amount"];
      final key = data["razorpayKey"];
      final intentId = data["intentId"];

      _currentIntentId = intentId;
      _currentOrderId = orderId;

      final options = {
        'key': key,
        'amount': amount,
        'name': 'FacultyPedia',
        'description': series.title,
        'order_id': orderId,
        'prefill': {
          'contact': user?.mobileNumber ?? '',
          'email': user?.email,
        },
        'theme': {'color': '#2563EB'},
      };

      _razorpay.open(options);
    } catch (e) {
      debugPrint("Create order failed: $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to start payment: $e"),
          backgroundColor: AppColors.error,
        ),
      );

      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      debugPrint("Payment success: ${response.paymentId}");

      if (mounted) setState(() => _isProcessing = true);

      final api = ApiService();

      final verifyRes = await api.post(
        "/api/payments/verify",
        data: {
          "orderId": response.orderId,
          "paymentId": response.paymentId,
          "signature": response.signature,
          "intentId": _currentIntentId,
        },
      );

      final status = verifyRes.data?["data"]?["status"];

      if (status != "succeeded") {
        throw Exception("Payment verification failed. Status=$status");
      }

      if (!mounted) return;

      // ✅ refresh series + tests + student (fresh student enroll list)
      ref.invalidate(testSeriesDetailProvider(widget.testSeriesId));
      ref.invalidate(testSeriesResolvedTestsProvider(widget.testSeriesId));
      ref.invalidate(currentStudentProvider);

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
          title: const Text('Payment Successful!'),
          content:
          const Text('You have been successfully enrolled in this test series.'),
          actions: [
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("Verify payment error: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Payment verification failed: $e"),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment cancelled: ${response.message}'),
        backgroundColor: AppColors.error,
      ),
    );
    setState(() => _isProcessing = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet: ${response.walletName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(testSeriesDetailProvider(widget.testSeriesId));
    final testsAsync =
    ref.watch(testSeriesResolvedTestsProvider(widget.testSeriesId));

    // ✅ always use fresh student from DB
    final studentAsync = ref.watch(currentStudentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Series'),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go("/home");
            }
          },
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share, color: Colors.white),
            ),
            onPressed: () {
              final link =
              AppLinksConfig.testSeriesDetails(widget.testSeriesId);

              showModalBottomSheet(
                context: context,
                showDragHandle: false,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                builder: (_) => ShareBottomSheet(
                  link: link,
                  title: "Check this test series on Faculty Pedia",
                ),
              );
            },
          ),
        ],
      ),
      body: seriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorStateWidget(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(testSeriesDetailProvider(widget.testSeriesId)),
        ),
        data: (series) {
          final enrolled = studentAsync.maybeWhen(
            data: (student) {
              return student.testSeries.any((t) => t.id == series.id);
            },
            orElse: () => false,
          );

          return Stack(
            children: [
              _buildContent(context, series, testsAsync, enrolled),
              if (!enrolled && !_isProcessing)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildEnrollBar(context, series),
                ),
              if (_isProcessing)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Processing...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, TestSeries series,
      AsyncValue<List<Test>> testsAsync, bool isEnrolled) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: isEnrolled ? 16 : 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    series.specialization.isNotEmpty
                        ? series.specialization.first
                        : 'Test Series',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  series.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (series.educatorName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        series.educatorName!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                      'Tests', '${series.totalTests ?? 0}', Icons.quiz),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('Enrolled',
                      '${series.enrolledCount ?? 0}', Icons.people),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Price',
                    (series.fees?.toInt() ?? 0) == 0
                        ? "FREE"
                        : '₹${series.fees?.toInt() ?? 0}',
                    Icons.money,
                  ),
                ),
              ],
            ),
          ),

          // Description
          if (series.description != null && series.description!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    series.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Tests List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Available Tests',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 12),

          testsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorStateWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(
                    testSeriesResolvedTestsProvider(widget.testSeriesId)),
              ),
            ),
            data: (tests) {
              if (tests.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 48, color: AppColors.grey400),
                        const SizedBox(height: 12),
                        Text(
                          'No tests available yet',
                          style: TextStyle(color: AppColors.grey600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: tests
                    .map((test) => _buildTestItem(context, test, isEnrolled))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollBar(BuildContext context, TestSeries series) {
    final price = series.fees?.toInt() ?? 0;
    final bool isFree = price == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Text(
                isFree ? "FREE" : '₹$price',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (isFree) {
                    _enrollFreeTestSeries(series);
                  } else {
                    _initiateRealPayment(series);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  isFree ? "Enroll (Free)" : "Enroll Now",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
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

  Widget _buildTestItem(BuildContext context, Test test, bool isEnrolled) {
    final totalMarks = test.displayMarks;
    final totalQuestions = test.totalQuestions ?? 0;
    final duration = test.duration ?? 0;

    final locked = !isEnrolled;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: locked ? null : () => context.push('/live-test/${test.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  locked ? Icons.lock_outline : Icons.edit_document,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      test.title ?? 'Test',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildTestInfo(Icons.quiz, '$totalQuestions Q'),
                        const SizedBox(width: 12),
                        _buildTestInfo(Icons.timer, '$duration min'),
                        const SizedBox(width: 12),
                        _buildTestInfo(Icons.star, '$totalMarks marks'),
                      ],
                    ),
                  ],
                ),
              ),
              if (locked)
                Icon(Icons.lock_outline, size: 22, color: AppColors.grey600)
              else
                ElevatedButton(
                  onPressed: () => context.push('/live-test/${test.id}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Start'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.grey500),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: AppColors.grey600),
        ),
      ],
    );
  }
}
