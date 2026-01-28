import 'dart:async';

import 'package:faculty_pedia/core/deep_link/app_links_config.dart';
import 'package:faculty_pedia/shared/widgets/share_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/webinar_model.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';
import '../../auth/providers/auth_provider.dart';

final webinarDetailProvider =
FutureProvider.family.autoDispose<Webinar, String>((ref, id) async {
  final api = ApiService();
  final response = await api.get('/api/webinars/$id');

  final raw = response.data;

  if (raw is Map && raw['data'] is Map<String, dynamic>) {
    return Webinar.fromJson(Map<String, dynamic>.from(raw['data']));
  }

  if (raw is Map<String, dynamic>) {
    return Webinar.fromJson(raw);
  }

  throw Exception("Invalid webinar response");
});

class WebinarDetailsScreen extends ConsumerStatefulWidget {
  final String webinarId;

  const WebinarDetailsScreen({super.key, required this.webinarId});

  @override
  ConsumerState<WebinarDetailsScreen> createState() =>
      _WebinarDetailsScreenState();
}

class _WebinarDetailsScreenState extends ConsumerState<WebinarDetailsScreen> {
  final ApiService _api = ApiService();
  String? _currentIntentId;
  String? _currentOrderId;

  bool _actionLoading = false;

  // ✅ Razorpay (exact like course screen)
  late Razorpay _razorpay;

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
      debugPrint("✅ Payment success: ${response.paymentId}");

      final verifyRes = await _api.post(
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registered successfully")),
      );

      ref.invalidate(webinarDetailProvider(widget.webinarId));
    } catch (e) {
      debugPrint("❌ verify webinar payment error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment verification failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }


  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("❌ Payment cancelled: ${response.message}");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment cancelled: ${response.message}'),
        backgroundColor: AppColors.error,
      ),
    );

    setState(() => _actionLoading = false);
  }


  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet: ${response.walletName}')),
    );
  }

  /// ✅ REAL student ID from authStateProvider
  String? _getStudentId() {
    final authState = ref.read(authStateProvider);
    return authState.user?.id;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// ✅ Razorpay payment (same behaviour as your dummy dialog)
  /// returns true = payment success
  Future<void> _initiateWebinarPayment(Webinar webinar) async {
    if (_actionLoading) return;

    final authState = ref.read(authStateProvider);
    final user = authState.user;
    final userId = user?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to continue")),
      );
      return;
    }

    try {
      setState(() => _actionLoading = true);

      final response = await _api.post(
        "/api/payments/orders",
        data: {
          "studentId": userId,
          "productType": "webinar",
          "productId": webinar.id,
        },
      );

      final data = response.data["data"];

      final orderId = data["orderId"];
      final amount = data["amount"]; // already in paise
      final key = data["razorpayKey"];
      final intentId = data["intentId"];

      _currentIntentId = intentId;
      _currentOrderId = orderId;

      final options = {
        "key": key,
        "amount": amount,
        "name": "FacultyPedia",
        "description": webinar.title,
        "order_id": orderId,
        "prefill": {
          "contact": user?.mobileNumber ?? "",
          "email": user?.email,
        },
        "theme": {"color": "#2563EB"},
      };

      _razorpay.open(options);

      // ✅ do NOT set _actionLoading=false here
      // It will be reset in success/error callbacks.
    } catch (e) {
      debugPrint("❌ webinar payment init failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to start payment: $e")),
      );
      if (mounted) setState(() => _actionLoading = false);
    }
  }


  Future<void> _enroll(Webinar webinar) async {
    final studentId = _getStudentId();
    if (studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login required to register")),
      );
      return;
    }

    // frontend seat check
    if (webinar.remainingSeats <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Webinar is full")),
      );
      return;
    }

    try {
      setState(() => _actionLoading = true);

      final response = await _api.post(
        '/api/webinars/${webinar.id}/enroll',
        data: {"studentId": studentId},
      );

      final data = response.data;

      if (data is Map && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registered successfully")),
        );

        ref.invalidate(webinarDetailProvider(widget.webinarId));
        return;
      }

      throw Exception(data?['message'] ?? "Enroll failed");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _unenroll(Webinar webinar) async {
    final studentId = _getStudentId();
    if (studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login required")),
      );
      return;
    }

    try {
      setState(() => _actionLoading = true);

      final response = await _api.post(
        '/api/webinars/${webinar.id}/unenroll',
        data: {"studentId": studentId},
      );

      final data = response.data;

      if (data is Map && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registration cancelled")),
        );

        ref.invalidate(webinarDetailProvider(widget.webinarId));
        return;
      }

      throw Exception(data?['message'] ?? "Unenroll failed");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _actionLoading = false);
    }
  }
  String _formatDuration(String value) {
    final v = value.trim().toLowerCase();

    // extract first number from duration
    final match = RegExp(r'(\d+)').firstMatch(v);
    final mins = match != null ? int.tryParse(match.group(1)!) : null;

    if (mins == null) return value.trim(); // fallback

    // if already contains hours/min words -> return cleaned original
    if (v.contains('hour') || v.contains('hr') || v.contains('h')) {
      return "${mins} hr";
    }
    if (v.contains('min') || v.contains('m')) {
      return "${mins} min";
    }

    // auto format: show hr if >= 60
    if (mins >= 60) {
      final hours = mins ~/ 60;
      final rem = mins % 60;
      if (rem == 0) return "$hours hr";
      return "$hours hr $rem min";
    }

    return "$mins min";
  }

  @override
  Widget build(BuildContext context) {
    final webinarAsync = ref.watch(webinarDetailProvider(widget.webinarId));

    return Scaffold(
      body: webinarAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Scaffold(
          appBar: AppBar(),
          body: ErrorStateWidget(
            message: error.toString(),
            onRetry: () =>
                ref.invalidate(webinarDetailProvider(widget.webinarId)),
          ),
        ),
        data: (webinar) => _buildContent(context, webinar),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Webinar webinar) {
    final studentId = _getStudentId();
    final isLoggedIn = studentId != null;

    // ✅ Enrollment check (your backend returns studentEnrolled as list of IDs)
    final bool isEnrolled =
        isLoggedIn && webinar.studentEnrolled.contains(studentId);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
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
                    final link = AppLinksConfig.webinarDetails(webinar.id); // ✅ same style

                    showModalBottomSheet(
                      context: context,
                      showDragHandle: false,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      builder: (_) => ShareBottomSheet(
                        link: link,
                        title: "Check this webinar on Faculty Pedia",
                      ),
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: AppColors.grey200,
                      child: webinar.imageUrl.isNotEmpty
                          ? Image.network(
                        webinar.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.videocam,
                              size: 64, color: AppColors.grey400),
                        ),
                      )
                          : const Center(
                        child: Icon(Icons.videocam,
                            size: 64, color: AppColors.grey400),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          _statusChip(webinar),
                          const SizedBox(width: 10),
                          _priceChip(webinar),
                          const Spacer(),
                          if (isEnrolled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "REGISTERED",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      webinar.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 14),

                    // Timing
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.event, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormatter.formatDate(webinar.timing),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  DateFormatter.formatTime(webinar.timing),
                                  style: TextStyle(color: AppColors.grey700),
                                ),
                              ],
                            ),
                          ),
                          if (webinar.duration.trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.grey100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer, size: 14, color: AppColors.grey700),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDuration(webinar.duration),
                                    style: TextStyle(
                                      color: AppColors.grey700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Seats info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chair_alt_outlined,
                              color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Seats: ${webinar.registeredCount}/${webinar.seatLimit}",
                              style:
                              const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            webinar.remainingSeats <= 0
                                ? "FULL"
                                : "${webinar.remainingSeats} left",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: webinar.remainingSeats <= 0
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Educator
                    if (webinar.educatorName != null) ...[
                      Text(
                        'Hosted by',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () =>
                            context.push('/educator/${webinar.educatorId}'),
                        child: Row(
                          children: [
                            UserAvatar(
                              imageUrl: null,
                              name: webinar.educatorName,
                              size: 52,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    webinar.educatorName!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    webinar.educatorEmail ?? 'View Profile',
                                    style: TextStyle(
                                        color: AppColors.grey600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],

                    // Description
                    Text(
                      'About this webinar',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      webinar.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                    const SizedBox(height: 22),

                    // Webinar info section
                    _infoGrid(webinar),

                    const SizedBox(height: 22),

                    // Recordings (ended webinars)
                    if (webinar.hasRecordings) ...[
                      Text(
                        'Recorded Videos / Materials',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      ...webinar.assetsLink.map((link) {
                        final isVideo = link.contains(".mp4") ||
                            link.contains("youtube") ||
                            link.contains("youtu.be") ||
                            link.contains("vimeo");
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            tileColor: AppColors.grey100,
                            leading: Icon(
                                isVideo ? Icons.play_circle : Icons.link),
                            title:
                            Text(isVideo ? "Watch Recording" : "Open Material"),
                            subtitle: Text(
                              link,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () => _openUrl(link),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),

        // ✅ Bottom CTA (Blueprint EXACT)
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: _bottomActionButton(
                context: context,
                webinar: webinar,
                isEnrolled: isEnrolled,
                isLoggedIn: isLoggedIn,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomActionButton({
    required BuildContext context,
    required Webinar webinar,
    required bool isEnrolled,
    required bool isLoggedIn,
  }) {
    // ✅ ENDED
    if (webinar.isEnded) {
      if (webinar.hasRecordings) {
        return ElevatedButton.icon(
          onPressed: () => _openUrl(webinar.assetsLink.first),
          icon: const Icon(Icons.play_circle),
          label: const Text("Watch Recording"),
        );
      }
      return ElevatedButton(
        onPressed: null,
        child: const Text("Webinar Ended"),
      );
    }

    // ✅ LIVE
    if (webinar.isLive) {
      // Join only if enrolled + link exists
      if (isEnrolled && webinar.hasJoinLink) {
        return ElevatedButton.icon(
          onPressed: () => _openUrl(webinar.webinarLink!),
          icon: const Icon(Icons.videocam),
          label: const Text("Join Webinar"),
        );
      }

      // Not enrolled
      return ElevatedButton(
        onPressed: null,
        child: const Text("Not Registered"),
      );
    }

    // ✅ UPCOMING
    if (webinar.isUpcoming) {
      // seat full
      if (webinar.remainingSeats <= 0) {
        return ElevatedButton(
          onPressed: null,
          child: const Text("Webinar Full"),
        );
      }

      // login required
      if (!isLoggedIn) {
        return ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please login to register")),
            );
          },
          child: const Text("Login to Register"),
        );
      }

      // already registered -> cancel
      if (isEnrolled) {
        return OutlinedButton(
          onPressed: _actionLoading ? null : () => _unenroll(webinar),
          child: _actionLoading
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text("Cancel Registration"),
        );
      }

      // new registration:
      if (webinar.isFree) {
        return ElevatedButton(
          onPressed: _actionLoading ? null : () => _enroll(webinar),
          child: _actionLoading
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text("Register (Free)"),
        );
      }

      // ✅ paid registration -> razorpay -> enroll (THIS ENSURES ENROLL AFTER SUCCESS)
      return ElevatedButton(
        onPressed: _actionLoading ? null : () => _initiateWebinarPayment(webinar),
        child: _actionLoading
            ? const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Text("Pay ₹${webinar.fees.toInt()} & Register"),
      );

    }

    return const SizedBox.shrink();
  }

  Widget _statusChip(Webinar webinar) {
    Color color;
    String text;

    if (webinar.isLive) {
      color = AppColors.error;
      text = '● LIVE';
    } else if (webinar.isUpcoming) {
      color = AppColors.primary;
      text = 'UPCOMING';
    } else {
      color = AppColors.grey600;
      text = 'ENDED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _priceChip(Webinar webinar) {
    final isFree = webinar.isFree;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isFree ? AppColors.success : Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isFree ? "FREE" : "₹${webinar.fees.toInt()}",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoGrid(Webinar webinar) {
    Widget item(String label, String value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: AppColors.grey600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            item(
              "Type",
              webinar.webinarType == 'one-to-one'
                  ? 'One-to-One'
                  : 'One-to-All',
              Icons.category,
            ),
            const SizedBox(width: 12),
            item("Seats", "${webinar.registeredCount}/${webinar.seatLimit}",
                Icons.chair_alt),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            item("Subject", webinar.subject.join(", "), Icons.book_outlined),
            const SizedBox(width: 12),
            item("Specialization", webinar.specialization.join(", "),
                Icons.school_outlined),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            item("Class", webinar.classes.join(", "), Icons.class_),
          ],
        ),
      ],
    );
  }
}
