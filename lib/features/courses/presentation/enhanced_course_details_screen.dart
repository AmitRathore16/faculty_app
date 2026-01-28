import 'package:chewie/chewie.dart';
import 'package:faculty_pedia/core/deep_link/app_links_config.dart';
import 'package:faculty_pedia/features/courses/presentation/my_courses_screen.dart';
import 'package:faculty_pedia/shared/models/student_model.dart';
import 'package:faculty_pedia/shared/widgets/share_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/course_model.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';
import '../../auth/providers/auth_provider.dart';

// Course Detail Provider
final courseDetailProvider =
FutureProvider.family.autoDispose<Course, String>((ref, id) async {
  final api = ApiService();
  final response = await api.get('/api/courses/$id');
  final data = response.data;

  Map<String, dynamic> courseData = {};
  if (data is Map && data['course'] != null) {
    courseData = data['course'];
  } else if (data is Map) {
    courseData = Map<String, dynamic>.from(data);
  }

  return Course.fromJson(courseData);
});

class EnhancedCourseDetailsScreen extends ConsumerStatefulWidget {
  final String courseId;

  const EnhancedCourseDetailsScreen({super.key, required this.courseId});

  @override
  ConsumerState<EnhancedCourseDetailsScreen> createState() =>
      _EnhancedCourseDetailsScreenState();
}

class _EnhancedCourseDetailsScreenState
    extends ConsumerState<EnhancedCourseDetailsScreen> {
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

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      debugPrint("Payment success: ${response.paymentId}");

      if (mounted) setState(() => _isProcessing = true);

      final api = ApiService();

      // ✅ Verify payment on backend (backend will enroll student)
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

      // refresh UI
      ref.invalidate(courseDetailProvider(widget.courseId));
      ref.invalidate(myCoursesProvider);

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
          title: const Text('Payment Successful!'),
          content:
          const Text('You have been successfully enrolled in this course.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                context.pop();
                context.push('/course-content/${widget.courseId}');
              },
              child: const Text('Start Learning'),
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

  /// ✅ NEW: FREE enrollment for price 0
  Future<void> _enrollFreeCourse(Course course) async {
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

      /// ✅ Course enroll route (should update enrollment in backend)
      await api.post(
        "/api/courses/${widget.courseId}/enroll",
        data: {"studentId": userId},
      );

      if (!mounted) return;

      // refresh UI
      ref.invalidate(courseDetailProvider(widget.courseId));
      ref.invalidate(myCoursesProvider);

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
          title: const Text('Enrollment Successful!'),
          content:
          const Text('You have been successfully enrolled in this course.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                context.pop();
                context.push('/course-content/${widget.courseId}');
              },
              child: const Text('Start Learning'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("Free enroll course failed: $e");
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

  Future<void> _initiateRealPayment(Course course) async {
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
          "productType": "course",
          "productId": widget.courseId,
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
        'description': course.title,
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

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseDetailProvider(widget.courseId));
    final authState = ref.watch(authStateProvider);
    final userId = authState.user?.id;

    return Scaffold(
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Scaffold(
          appBar: AppBar(),
          body: ErrorStateWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(courseDetailProvider(widget.courseId)),
          ),
        ),
        data: (course) {
          final user = authState.user;
          final student = user is Student ? user : null;
          final isEnrolled = userId != null &&
              ((course.enrolledStudents?.contains(userId) ?? false) ||
                  (student?.courses
                      .any((c) => c.courseId == widget.courseId) ??
                      false));

          return _buildContent(context, course, isEnrolled);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, Course course, bool isEnrolled) {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // App Bar with Image
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppColors.grey200,
                  child: course.imageUrl.isNotEmpty
                      ? Image.network(
                    course.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                      : _buildPlaceholder(),
                ),
              ),
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black38,
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
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share, color: Colors.white),
                  ),
                  onPressed: () async {
                    final link = AppLinksConfig.courseDetails(widget.courseId);

                    showModalBottomSheet(
                      context: context,
                      showDragHandle: false,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      builder: (_) => ShareBottomSheet(
                        link: link,
                        title: "Check this course on Faculty Pedia",
                      ),
                    );
                  },
                ),
              ],
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...course.specialization
                            .map((spec) => _buildTag(spec, AppColors.primary)),
                        ...course.classList.map(
                                (cls) => _buildTag(cls, AppColors.secondary)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      course.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),

                    if (course.rating != null && course.rating! > 0)
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${course.rating!.toStringAsFixed(1)} (${course.ratingCount ?? 0} reviews)',
                            style: TextStyle(
                              color: AppColors.grey600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    if (course.educator != null)
                      GestureDetector(
                        onTap: () =>
                            context.push('/educator/${course.educator!.id}'),
                        child: Row(
                          children: [
                            UserAvatar(
                              imageUrl: course.educator!.profilePicture,
                              name: course.educator!.name,
                              size: 48,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course.educator!.name ?? 'Educator',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'View Profile',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: AppColors.grey400),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    _buildStatsSection(course),
                    const SizedBox(height: 24),

                    if ((course.introVideoBestLink ?? '').trim().isNotEmpty)
                      _buildIntroVideoSection(course),

                    Text(
                      'About this Course',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.description ?? 'No description available.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),

                    if (course.courseObjectives != null &&
                        course.courseObjectives!.isNotEmpty)
                      _buildListSection(
                        context,
                        'Course Objectives',
                        course.courseObjectives!,
                        Icons.check_circle_outline,
                      ),

                    if (course.prerequisites != null &&
                        course.prerequisites!.isNotEmpty)
                      _buildListSection(
                        context,
                        'Prerequisites',
                        course.prerequisites!,
                        Icons.info_outline,
                      ),

                    if (course.subject.isNotEmpty) ...[
                      Text(
                        'Subjects Covered',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: course.subject.map((subject) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.grey100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.grey300),
                            ),
                            child: Text(
                              subject,
                              style:
                              const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    _buildInfoSection(course),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),

        if (!_isProcessing)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(context, course, isEnrolled),
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
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.play_circle_outline,
        size: 64,
        color: AppColors.grey400,
      ),
    );
  }

  Widget _buildStatsSection(Course course) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.calendar_today,
                  'Duration',
                  course.courseDuration ?? 'N/A',
                ),
              ),
              _buildStatDivider(),
              Expanded(
                child: _buildStatItem(
                  Icons.people,
                  'Max Students',
                  '${course.maxStudents ?? 'Unlimited'}',
                ),
              ),
              _buildStatDivider(),
              Expanded(
                child: _buildStatItem(
                  Icons.person,
                  'Enrolled',
                  '${course.enrolledCount ?? 0}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.video_library,
                  'Videos',
                  '${course.videoCount ?? 0}',
                ),
              ),
              _buildStatDivider(),
              Expanded(
                child: _buildStatItem(
                  Icons.live_tv,
                  'Live Classes',
                  '${course.liveClassCount ?? 0}',
                ),
              ),
              _buildStatDivider(),
              Expanded(
                child: _buildStatItem(
                  Icons.quiz,
                  'Tests',
                  '${course.testSeriesCount ?? 0}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.grey600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 60,
      color: AppColors.grey300,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildIntroVideoSection(Course course) {
    final link = (course.introVideoBestLink ?? '').trim();
    if (link.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Course Introduction',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _CourseIntroVideoPlayer(videoUrl: link),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildListSection(BuildContext context, String title, List<String> items,
      IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoSection(Course course) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Information',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Language', course.language ?? 'English'),
        _buildInfoRow('Certificate',
            course.certificateAvailable == true ? 'Available' : 'Not Available'),
        if (course.startDate != null)
          _buildInfoRow(
              'Start Date', DateFormatter.formatDate(course.startDate!)),
        if (course.endDate != null)
          _buildInfoRow('End Date', DateFormatter.formatDate(course.endDate!)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.grey700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, Course course, bool isEnrolled) {
    final isFull = course.isFull == true;

    /// ✅ decide price
    final int finalPrice = course.finalPrice.toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (!isEnrolled) ...[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (course.hasDiscount) ...[
                      Text(
                        '₹${course.fees!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.grey500,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Row(
                      children: [
                        Text(
                          finalPrice == 0
                              ? "FREE"
                              : '₹${course.finalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        if (course.hasDiscount) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${course.discount!.toInt()}% OFF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              flex: isEnrolled ? 1 : 0,
              child: ElevatedButton(
                onPressed: isFull && !isEnrolled
                    ? null
                    : () {
                  if (isEnrolled) {
                    context.push('/course-content/${course.id}');
                    return;
                  }

                  // ✅ FREE COURSE
                  if (finalPrice == 0) {
                    _enrollFreeCourse(course);
                    return;
                  }

                  // ✅ PAID COURSE
                  _initiateRealPayment(course);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 32),
                  backgroundColor: isEnrolled ? Colors.green : null,
                ),
                child: Text(
                  isEnrolled
                      ? 'Go to Course'
                      : isFull
                      ? 'Course Full'
                      : finalPrice == 0
                      ? 'Enroll (Free)'
                      : 'Enroll Now',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPrice(Course course) {
    final hasDiscount = course.hasDiscount == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDiscount && course.fees != null && course.discount != null)
          Row(
            children: [
              Text(
                '₹${course.fees!.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                  color: AppColors.grey500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.green.withOpacity(0.25)),
                ),
                child: Text(
                  '${course.discount!.toInt()}% OFF',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '₹${course.finalPrice.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.grey900,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Total Price',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.grey600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CourseIntroVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _CourseIntroVideoPlayer({required this.videoUrl});

  @override
  State<_CourseIntroVideoPlayer> createState() => _CourseIntroVideoPlayerState();
}

class _CourseIntroVideoPlayerState extends State<_CourseIntroVideoPlayer> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  WebViewController? _webCtrl;

  bool _loading = true;
  String? _error;

  bool get _isVimeo {
    final url = widget.videoUrl.toLowerCase();
    return url.contains("vimeo.com") || url.contains("player.vimeo.com");
  }

  bool get _isPlayableDirect {
    final url = widget.videoUrl.toLowerCase();
    return url.endsWith(".mp4") || url.contains(".m3u8");
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _CourseIntroVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeControllers();
      _init();
    }
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (!_isVimeo && _isPlayableDirect) {
      await _initNativePlayer();
      return;
    }

    await _initWebEmbed();
  }

  Future<void> _initNativePlayer() async {
    try {
      final ctrl =
      VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await ctrl.initialize();

      final chewie = ChewieController(
        videoPlayerController: ctrl,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          bufferedColor: AppColors.grey300,
          backgroundColor: AppColors.grey200,
        ),
      );

      _videoCtrl = ctrl;
      _chewieCtrl = chewie;

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Unable to load video";
      });
    }
  }

  Future<void> _initWebEmbed() async {
    try {
      final embedUrl = _toVimeoEmbedUrl(widget.videoUrl);

      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..loadHtmlString(_vimeoHtml(embedUrl));

      _webCtrl = ctrl;

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Unable to load video";
      });
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    _chewieCtrl = null;
    _videoCtrl = null;
    _webCtrl = null;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              Positioned.fill(child: _buildPlayerBody()),
              if (_loading)
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerBody() {
    if (!_isVimeo && _isPlayableDirect) {
      if (_chewieCtrl == null) {
        return Container(
          color: AppColors.grey200,
          alignment: Alignment.center,
          child: const Icon(
            Icons.play_circle_outline,
            size: 64,
            color: AppColors.grey400,
          ),
        );
      }
      return Chewie(controller: _chewieCtrl!);
    }

    if (_webCtrl == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(
          Icons.play_circle_outline,
          size: 64,
          color: Colors.white54,
        ),
      );
    }

    return WebViewWidget(controller: _webCtrl!);
  }

  String _toVimeoEmbedUrl(String url) {
    try {
      final input = url.trim();

      if (input.contains("player.vimeo.com/video/")) {
        return input.contains("?")
            ? input
            : "$input?autoplay=0&title=0&byline=0&portrait=0";
      }

      final match = RegExp(r'(\d{6,})').firstMatch(input);
      final id = match?.group(1);

      if (id == null) return input;

      return "https://player.vimeo.com/video/$id?autoplay=0&title=0&byline=0&portrait=0";
    } catch (_) {
      return url;
    }
  }

  String _vimeoHtml(String embedUrl) {
    return """
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background: #000;
      height: 100%;
      width: 100%;
      overflow: hidden;
    }
    iframe {
      position: absolute;
      top: 0; left: 0;
      width: 100%;
      height: 100%;
      border: 0;
    }
  </style>
</head>
<body>
  <iframe
    src="$embedUrl"
    allow="autoplay; fullscreen; picture-in-picture"
    allowfullscreen>
  </iframe>
</body>
</html>
""";
  }
}
