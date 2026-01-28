import 'dart:convert';

import 'package:faculty_pedia/core/config/app_config.dart';
import 'package:faculty_pedia/core/deep_link/app_links_config.dart';
import 'package:faculty_pedia/core/services/storage_service.dart';
import 'package:faculty_pedia/shared/models/student_model.dart';
import 'package:faculty_pedia/shared/widgets/share_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ✅ Video
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/course_model.dart';
import '../../../shared/models/educator_model.dart';
import '../../../shared/models/test_series_model.dart';
import '../../../shared/models/webinar_model.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';

/// =======================
/// Providers
/// =======================

final educatorWebinarsProvider =
FutureProvider.family.autoDispose<List<Webinar>, String>((ref, educatorId) async {
  final api = ApiService();
  final response = await api.get('/api/webinars/educator/$educatorId');

  dynamic data = response.data;
  if (data is String) data = jsonDecode(data);

  List list = [];
  if (data is Map && data['data'] is Map && data['data']['webinars'] is List) {
    list = data['data']['webinars'];
  } else if (data is Map && data['webinars'] is List) {
    list = data['webinars'];
  } else if (data is List) {
    list = data;
  }

  return list.map((e) => Webinar.fromJson(Map<String, dynamic>.from(e))).toList();
});

final educatorTestSeriesProvider =
FutureProvider.family.autoDispose<List<TestSeries>, String>((ref, educatorId) async {
  final api = ApiService();
  final response = await api.get('/api/test-series/educator/$educatorId');

  dynamic data = response.data;
  if (data is String) data = jsonDecode(data);

  List list = [];
  if (data is Map && data['data'] is Map && data['data']['testSeries'] is List) {
    list = data['data']['testSeries'];
  } else if (data is Map && data['data'] is List) {
    list = data['data'];
  } else if (data is Map && data['testSeries'] is List) {
    list = data['testSeries'];
  } else if (data is List) {
    list = data;
  }

  return list.map((e) => TestSeries.fromJson(Map<String, dynamic>.from(e))).toList();
});

final educatorDetailProvider =
FutureProvider.family.autoDispose<Educator, String>((ref, id) async {
  final api = ApiService();
  final response = await api.get('/api/educators/$id');

  dynamic data = response.data;
  if (data is String) data = jsonDecode(data);

  if (data is Map && data['data'] is Map && data['data']['educator'] is Map) {
    return Educator.fromJson(Map<String, dynamic>.from(data['data']['educator']));
  }

  throw Exception("Invalid educator detail response");
});

final educatorCoursesProvider =
FutureProvider.family.autoDispose<List<Course>, String>((ref, id) async {
  final api = ApiService();
  final response = await api.get('/api/courses/educator/$id');
  dynamic data = response.data;
  if (data is String) data = jsonDecode(data);

  List<dynamic> coursesList = [];
  if (data is Map && data['courses'] != null) {
    coursesList = (data['courses'] as List);
  } else if (data is Map && data['data'] is Map && data['data']['courses'] is List) {
    coursesList = data['data']['courses'];
  } else if (data is List) {
    coursesList = data;
  }

  return coursesList.map((e) => Course.fromJson(Map<String, dynamic>.from(e))).toList();
});

/// =======================================
/// Follow controller WITHOUT AUTH PROVIDER
/// =======================================

final educatorFollowControllerProvider =
StateNotifierProvider.family<FollowController, FollowState, Educator>((ref, educator) {
  final api = ApiService();
  return FollowController(ref, api, educator);
});

class FollowState {
  final bool isFollowing;
  final bool isLoading;
  final int followerCount;

  FollowState({
    required this.isFollowing,
    required this.isLoading,
    required this.followerCount,
  });

  FollowState copyWith({
    bool? isFollowing,
    bool? isLoading,
    int? followerCount,
  }) {
    return FollowState(
      isFollowing: isFollowing ?? this.isFollowing,
      isLoading: isLoading ?? this.isLoading,
      followerCount: followerCount ?? this.followerCount,
    );
  }
}

class FollowController extends StateNotifier<FollowState> {
  final Ref ref;
  final ApiService api;
  final Educator educator;

  FollowController(this.ref, this.api, this.educator)
      : super(
    FollowState(
      isFollowing: false,
      isLoading: false,
      followerCount: educator.followerCount,
    ),
  ) {
    _bootstrap();
  }

  Student? _getStudentFromStorage() {
    final raw = StorageService.getString(AppConfig.userDataKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return Student.fromJson(map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveStudentToStorage(Student student) async {
    await StorageService.setString(AppConfig.userDataKey, jsonEncode(student.toJson()));
  }

  void _bootstrap() {
    final student = _getStudentFromStorage();
    if (student == null) return;

    final isFollowing = student.followingEducators.contains(educator.id);
    state = state.copyWith(isFollowing: isFollowing);
  }

  Future<void> toggleFollow() async {
    final student = _getStudentFromStorage();
    if (student == null) {
      throw Exception("Student not logged in");
    }

    if (state.isLoading) return;

    final wasFollowing = state.isFollowing;

    // optimistic UI
    state = state.copyWith(
      isLoading: true,
      isFollowing: !wasFollowing,
      followerCount: wasFollowing ? state.followerCount - 1 : state.followerCount + 1,
    );

    try {
      if (!wasFollowing) {
        await api.post('/api/students/${student.id}/follow', data: {
          "educatorId": educator.id,
        });

        await _updateStudentFollowLocal(student, educator.id, true);
      } else {
        await api.delete('/api/students/${student.id}/unfollow', data: {
          "educatorId": educator.id,
        });

        await _updateStudentFollowLocal(student, educator.id, false);
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      // rollback
      state = state.copyWith(
        isLoading: false,
        isFollowing: wasFollowing,
        followerCount: educator.followerCount,
      );
      rethrow;
    }
  }

  Future<void> _updateStudentFollowLocal(Student student, String educatorId, bool follow) async {
    final updatedList = [...student.followingEducators];

    if (follow) {
      if (!updatedList.contains(educatorId)) updatedList.add(educatorId);
    } else {
      updatedList.remove(educatorId);
    }

    final updatedStudent = Student(
      id: student.id,
      name: student.name,
      firstName: student.firstName,
      lastName: student.lastName,
      email: student.email,
      mobileNumber: student.mobileNumber,
      username: student.username,
      image: student.image,
      bio: student.bio,
      joinedAt: student.joinedAt,
      createdAt: student.createdAt,
      specialization: student.specialization,
      academicClass: student.academicClass,
      courses: student.courses,
      tests: student.tests,
      results: student.results,
      followingEducators: updatedList,
    );

    await _saveStudentToStorage(updatedStudent);
  }
}

/// =======================
/// Screen
/// =======================

class EducatorProfileScreen extends ConsumerWidget {
  final String educatorId;

  const EducatorProfileScreen({super.key, required this.educatorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final educatorAsync = ref.watch(educatorDetailProvider(educatorId));

    return Scaffold(
      body: educatorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Scaffold(
          appBar: AppBar(),
          body: ErrorStateWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(educatorDetailProvider(educatorId)),
          ),
        ),
        data: (educator) => _buildProfile(context, ref, educator),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, WidgetRef ref, Educator educator) {
    final coursesAsync = ref.watch(educatorCoursesProvider(educator.id));

    final coursesCountText = coursesAsync.when(
      data: (list) => list.length.toString(),
      loading: () => '--',
      error: (_, __) => '--',
    );

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildProfileHeader(context, educator),
          ),
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
              onPressed: () async {
                final link = AppLinksConfig.educatorProfile(educator.id);

                showModalBottomSheet(
                  context: context,
                  showDragHandle: false,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  builder: (_) => ShareBottomSheet(
                    link: link,
                    title: "Check this educator on Faculty Pedia",
                  ),
                );
              },
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsRow(ref, educator, coursesCountText),
                const SizedBox(height: 24),

                _buildActionButtons(context, ref, educator),
                const SizedBox(height: 20),

                // ✅ NEW: rating section
                _buildRatingSection(context, ref, educator),
                const SizedBox(height: 24),

                _buildIntroVideoSection(context, educator),

                if (educator.bio != null && educator.bio!.isNotEmpty) ...[
                  Text('About', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(educator.bio!, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                ],

                if (educator.qualifications.isNotEmpty) ...[
                  Text('Qualifications', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  ...educator.qualifications.map((q) => _buildQualificationItem(context, q)),
                  const SizedBox(height: 24),
                ],

                Text('Courses', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        _buildCoursesList(ref),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text('Webinars', style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        _buildWebinarsList(ref),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text('Test Series', style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        _buildTestSeriesList(ref),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  /// ✅ NEW: Production-grade rating section
  Widget _buildRatingSection(BuildContext context, WidgetRef ref, Educator educator) {
    final avg = educator.rating?.average ?? 0;
    final count = educator.rating?.count ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Rating",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  "${avg.toStringAsFixed(1)} (${count})",
                  style: const TextStyle(fontSize: 13, color: AppColors.grey600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () async {
                await _openRateBottomSheet(context, ref, educator);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,

                // ✅ makes content centered properly
                alignment: Alignment.center,

                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),

                // ✅ prevents text clipping + centers better
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                "Rate",
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          )

        ],
      ),
    );
  }

  Future<void> _openRateBottomSheet(BuildContext context, WidgetRef ref, Educator educator) async {
    final student = _getStudentFromStorage();
    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to rate educator")),
      );
      return;
    }

    final currentAvg = educator.rating?.average ?? 0;
    double selected = (currentAvg <= 0) ? 5 : currentAvg;
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Rate ${educator.displayName}",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Your rating helps other students choose better.",
                      style: TextStyle(fontSize: 13, color: AppColors.grey600),
                    ),
                    const SizedBox(height: 12),

                    Center(
                      child: Column(
                        children: [
                          Text(
                            selected.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),

                          // ✅ Tap-able stars
                          _InteractiveStarRating(
                            value: selected,
                            enabled: !submitting,
                            size: 38,
                            onChanged: (v) => setModalState(() => selected = v),
                          ),


                          const SizedBox(height: 6),
                          const Text(
                            "Tap a star to rate",
                            style: TextStyle(fontSize: 12, color: AppColors.grey600),
                          ),
                        ],
                      ),
                    ),


                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text("Cancel"),
                              onPressed: submitting ? null : () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: submitting
                                  ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Icon(Icons.check),
                              label: Text(submitting ? "Submitting..." : "Submit"),
                              onPressed: submitting
                                  ? null
                                  : () async {
                                if (selected <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Rating must be greater than 0")),
                                  );
                                  return;
                                }

                                setModalState(() => submitting = true);
                                try {
                                  final api = ApiService();

                                  await api.post(
                                    "/api/educators/${educator.id}/rating",
                                    data: {
                                      "rating": selected,
                                      "studentId": student.id,
                                    },
                                  );

                                  // ✅ refresh educator detail + statistics
                                  ref.invalidate(educatorDetailProvider(educator.id));

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Rating submitted successfully")),
                                    );
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setModalState(() => submitting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Failed to submit rating: $e")),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  /// ✅ Intro Video section now EMBEDDED
  Widget _buildIntroVideoSection(BuildContext context, Educator educator) {
    final link = educator.introVideoBestLink?.trim() ?? '';
    if (link.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Intro Video', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        _EducatorIntroVideoPlayer(videoUrl: link),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context, Educator educator) {
    final isActive = educator.isActive;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                UserAvatar(
                  imageUrl: educator.imageUrl,
                  name: educator.displayName,
                  size: 100,
                  showBorder: true,
                  borderColor: Colors.white,
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: AnimatedOpacity(
                    opacity: (educator.status == 'active') ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              educator.displayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              educator.displaySubjects,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            if (educator.rating != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${educator.rating!.average?.toStringAsFixed(1) ?? 'N/A'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(WidgetRef ref, Educator educator, String coursesCountText) {
    final followState = ref.watch(educatorFollowControllerProvider(educator));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Followers', '${followState.followerCount}'),
          _buildStatDivider(),
          _buildStatItem('Experience', educator.displayExperience),
          _buildStatDivider(),
          _buildStatItem('Courses', coursesCountText),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Educator educator) {
    final followState = ref.watch(educatorFollowControllerProvider(educator));
    final followCtrl = ref.read(educatorFollowControllerProvider(educator).notifier);

    return Row(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) {
              final offsetAnim = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(anim);

              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: offsetAnim,
                  child: child,
                ),
              );
            },
            child: SizedBox(
              key: ValueKey("${followState.isFollowing}_${followState.isLoading}"),
              height: 44,
              child: followState.isLoading
                  ? Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.grey200,
                ),
                child: const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
                  : GestureDetector(
                onTap: () async {
                  try {
                    await followCtrl.toggleFollow();
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to update follow status")),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: followState.isFollowing ? Colors.white : const Color(0xFF0095F6),
                    border: Border.all(
                      color: followState.isFollowing ? AppColors.grey300 : Colors.transparent,
                      width: 1,
                    ),
                    boxShadow: [
                      if (!followState.isFollowing)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: followState.isFollowing
                              ? const Icon(
                            Icons.check,
                            key: ValueKey("check"),
                            size: 18,
                            color: Colors.black,
                          )
                              : const SizedBox(
                            key: ValueKey("noIcon"),
                            width: 0,
                            height: 0,
                          ),
                        ),
                        if (followState.isFollowing) const SizedBox(width: 6),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: followState.isFollowing ? Colors.black : Colors.white,
                          ),
                          child: Text(
                            followState.isFollowing ? "Following" : "Follow",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 44,
            child: GestureDetector(
              onTap: () async {
                try {
                  final api = ApiService();

                  final res = await api.post(
                    "/api/chat/conversations",
                    data: {"otherUserId": educator.id},
                  );

                  dynamic data = res.data;
                  if (data is String) data = jsonDecode(data);

                  final conv = data?["data"]?["conversation"] ?? data?["conversation"];
                  final conversationId = (conv?["_id"] ?? conv?["id"])?.toString();

                  if (conversationId == null || conversationId.isEmpty) {
                    throw Exception("Conversation ID missing");
                  }

                  if (!context.mounted) return;

                  context.push(
                    "/chat/$conversationId",
                    extra: {
                      "title": educator.displayName,
                      "receiverId": educator.id,
                      "receiverType": "Educator",
                    },
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to open chat: $e")),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white,
                  border: Border.all(color: AppColors.grey300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.message, size: 18, color: Colors.black),
                      SizedBox(width: 8),
                      Text(
                        "Message",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.grey600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 30, color: AppColors.grey300);
  }

  Widget _buildQualificationItem(BuildContext context, Qualification qual) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.school, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  qual.title ?? qual.degree ?? 'Qualification',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (qual.institution != null)
                  Text(
                    qual.institution!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.grey600,
                    ),
                  ),
              ],
            ),
          ),
          if (qual.year != null)
            Text(
              qual.year!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.grey500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoursesList(WidgetRef ref) {
    final coursesAsync = ref.watch(educatorCoursesProvider(educatorId));

    return coursesAsync.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: List.generate(3, (_) => const ShimmerCard()),
          ),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Failed to load courses'),
        ),
      ),
      data: (courses) {
        if (courses.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('No courses available')),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) => _CourseCard(course: courses[index]),
            childCount: courses.length,
          ),
        );
      },
    );
  }

  Widget _buildWebinarsList(WidgetRef ref) {
    final webinarsAsync = ref.watch(educatorWebinarsProvider(educatorId));

    return webinarsAsync.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: List.generate(2, (_) => const ShimmerCard()),
          ),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Failed to load webinars'),
        ),
      ),
      data: (webinars) {
        if (webinars.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('No webinars available')),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) => _WebinarCard(webinar: webinars[index]),
            childCount: webinars.length,
          ),
        );
      },
    );
  }

  Widget _buildTestSeriesList(WidgetRef ref) {
    final testSeriesAsync = ref.watch(educatorTestSeriesProvider(educatorId));

    return testSeriesAsync.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: List.generate(2, (_) => const ShimmerCard()),
          ),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Failed to load test series'),
        ),
      ),
      data: (series) {
        if (series.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('No test series available')),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) => _TestSeriesCard(testSeries: series[index]),
            childCount: series.length,
          ),
        );
      },
    );
  }

  /// -----------------------
  /// Utilities
  /// -----------------------
  Student? _getStudentFromStorage() {
    final raw = StorageService.getString(AppConfig.userDataKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return Student.fromJson(map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// =======================
/// ✅ NEW: Small helpers for rating UI
/// =======================

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// EMBEDDED INTRO VIDEO PLAYER (PRODUCTION GRADE)
/// =======================

class _EducatorIntroVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _EducatorIntroVideoPlayer({required this.videoUrl});

  @override
  State<_EducatorIntroVideoPlayer> createState() => _EducatorIntroVideoPlayerState();
}

class _EducatorIntroVideoPlayerState extends State<_EducatorIntroVideoPlayer> {
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
  void didUpdateWidget(covariant _EducatorIntroVideoPlayer oldWidget) {
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

    // ✅ Direct MP4/HLS: native player
    if (!_isVimeo && _isPlayableDirect) {
      await _initNativePlayer();
      return;
    }

    // ✅ Vimeo / unknown : web embed
    await _initWebEmbed();
  }

  Future<void> _initNativePlayer() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
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
    } catch (e) {
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
              if (_loading) const Positioned.fill(child: Center(child: CircularProgressIndicator())),
              if (_error != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
          child: const Icon(Icons.play_circle_outline, size: 64, color: AppColors.grey400),
        );
      }
      return Chewie(controller: _chewieCtrl!);
    }

    if (_webCtrl == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(Icons.play_circle_outline, size: 64, color: Colors.white54),
      );
    }

    return WebViewWidget(controller: _webCtrl!);
  }

  String _toVimeoEmbedUrl(String url) {
    try {
      final input = url.trim();
      if (input.contains("player.vimeo.com/video/")) {
        return input.contains("?") ? input : "$input?autoplay=0&title=0&byline=0&portrait=0";
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

/// =======================
/// Cards (unchanged)
/// =======================

class _CourseCard extends StatelessWidget {
  final Course course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => context.push('/course/${course.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: AppColors.grey200,
                  child: course.imageUrl.isNotEmpty
                      ? Image.network(
                    course.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.play_circle,
                      size: 32,
                      color: AppColors.grey400,
                    ),
                  )
                      : const Icon(Icons.play_circle, size: 32, color: AppColors.grey400),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.subject.join(', '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PriceWidget(
                      price: course.finalPrice,
                      originalPrice: course.fees,
                      discount: course.discount,
                      fontSize: 14,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.grey400),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebinarCard extends StatelessWidget {
  final Webinar webinar;

  const _WebinarCard({required this.webinar});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => context.push('/webinar/${webinar.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: AppColors.grey200,
                  child: webinar.imageUrl.isNotEmpty
                      ? Image.network(
                    webinar.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.videocam,
                      size: 32,
                      color: AppColors.grey400,
                    ),
                  )
                      : const Icon(Icons.videocam, size: 32, color: AppColors.grey400),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      webinar.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      webinar.subject.join(', '),
                      style: const TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      webinar.isFree ? "Free" : "₹${webinar.fees.toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.grey400),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestSeriesCard extends StatelessWidget {
  final TestSeries testSeries;

  const _TestSeriesCard({required this.testSeries});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => context.push('/test-series/${testSeries.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: AppColors.grey200,
                  child: testSeries.imageUrl.isNotEmpty
                      ? Image.network(
                    testSeries.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.assignment,
                      size: 32,
                      color: AppColors.grey400,
                    ),
                  )
                      : const Icon(Icons.assignment, size: 32, color: AppColors.grey400),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testSeries.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      testSeries.subject.join(', '),
                      style: const TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      testSeries.fees == null || testSeries.fees == 0
                          ? "Free"
                          : "₹${(testSeries.fees ?? 0).toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.grey400),
            ],
          ),
        ),
      ),
    );
  }
}
class _InteractiveStarRating extends StatelessWidget {
  final double value; // 0.0 to 5.0 (half allowed)
  final bool enabled;
  final double size;
  final ValueChanged<double> onChanged;

  const _InteractiveStarRating({
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 5.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starIndex = i + 1;

        final isFull = v >= starIndex;
        final isHalf = !isFull && v >= (starIndex - 0.5);

        IconData icon;
        if (isFull) {
          icon = Icons.star_rounded;
        } else if (isHalf) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }

        return SizedBox(
          width: size + 6,
          height: size + 6,
          child: enabled
              ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final dx = details.localPosition.dx;

              // left half = 0.5, right half = full
              final halfTap = dx < (size + 6) / 2;

              final newValue = halfTap
                  ? (starIndex - 0.5).toDouble()
                  : starIndex.toDouble();

              onChanged(newValue.clamp(0.0, 5.0));
            },
            child: Icon(icon, size: size, color: Colors.amber),
          )
              : Icon(icon, size: size, color: Colors.amber),
        );
      }),
    );
  }
}
