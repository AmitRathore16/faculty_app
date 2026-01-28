// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import '../../../core/theme/app_theme.dart';
// import '../../../core/services/api_service.dart';
// import '../../../shared/models/course_model.dart';
// import '../../../shared/widgets/shimmer_widgets.dart';
// import '../../../shared/widgets/state_widgets.dart';
// import '../../../shared/widgets/user_widgets.dart';
//
// // Courses Provider
// final coursesProvider = FutureProvider.autoDispose<List<Course>>((ref) async {
//   final api = ApiService();
//   final response = await api.get('/api/courses');
//   final data = response.data;
//
//   List<dynamic> coursesList = [];
//   if (data is Map && data['courses'] != null) {
//     coursesList = data['courses'] as List;
//   } else if (data is List) {
//     coursesList = data;
//   }
//
//   return coursesList.map((e) => Course.fromJson(e)).toList();
// });
//
// class CoursesScreen extends ConsumerWidget {
//   const CoursesScreen({super.key});
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final coursesAsync = ref.watch(coursesProvider);
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Courses'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.search),
//             onPressed: () {},
//           ),
//           IconButton(
//             icon: const Icon(Icons.filter_list),
//             onPressed: () {},
//           ),
//         ],
//       ),
//       body: RefreshIndicator(
//         onRefresh: () async {
//           ref.invalidate(coursesProvider);
//         },
//         child: coursesAsync.when(
//           loading: () => const ShimmerList(itemCount: 5, itemHeight: 160),
//           error: (error, stack) => ErrorStateWidget(
//             message: error.toString(),
//             onRetry: () => ref.invalidate(coursesProvider),
//           ),
//           data: (courses) {
//             if (courses.isEmpty) {
//               return const EmptyStateWidget(
//                 icon: Icons.play_circle_outline,
//                 title: 'No Courses Available',
//                 subtitle: 'Check back later for new courses',
//               );
//             }
//
//             return ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: courses.length,
//               itemBuilder: (context, index) {
//                 return _CourseCard(course: courses[index]);
//               },
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
//
// class _CourseCard extends StatelessWidget {
//   final Course course;
//
//   const _CourseCard({required this.course});
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 16),
//       clipBehavior: Clip.antiAlias,
//       child: InkWell(
//         onTap: () => context.push('/course/${course.id}'),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Image
//             Container(
//               height: 140,
//               width: double.infinity,
//               color: AppColors.grey200,
//               child: course.imageUrl.isNotEmpty
//                   ? Image.network(
//                       course.imageUrl,
//                       fit: BoxFit.cover,
//                       errorBuilder: (_, __, ___) => _buildPlaceholder(),
//                     )
//                   : _buildPlaceholder(),
//             ),
//
//             // Content
//             Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Specialization badge
//                   if (course.specialization.isNotEmpty)
//                     Wrap(
//                       spacing: 6,
//                       children: course.specialization.take(2).map((spec) {
//                         return Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                           decoration: BoxDecoration(
//                             color: AppColors.primary.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           child: Text(
//                             spec,
//                             style: TextStyle(
//                               fontSize: 10,
//                               color: AppColors.primary,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         );
//                       }).toList(),
//                     ),
//                   const SizedBox(height: 8),
//
//                   // Title
//                   Text(
//                     course.title,
//                     style: Theme.of(context).textTheme.titleLarge,
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   const SizedBox(height: 8),
//
//                   // Educator
//                   if (course.educator != null)
//                     Row(
//                       children: [
//                         UserAvatar(
//                           imageUrl: course.educator!.profilePicture,
//                           name: course.educator!.name,
//                           size: 28,
//                         ),
//                         const SizedBox(width: 8),
//                         Text(
//                           course.educator!.name ?? 'Educator',
//                           style: TextStyle(
//                             color: AppColors.primary,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   const SizedBox(height: 12),
//
//                   // Price and action
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       PriceWidget(
//                         price: course.finalPrice,
//                         originalPrice: course.fees,
//                         discount: course.discount,
//                       ),
//                       ElevatedButton(
//                         onPressed: () => context.push('/course/${course.id}'),
//                         style: ElevatedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(horizontal: 20),
//                         ),
//                         child: const Text('View Details'),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPlaceholder() {
//     return Center(
//       child: Icon(
//         Icons.play_circle_outline,
//         size: 48,
//         color: AppColors.grey400,
//       ),
//     );
//   }
// }
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/course_model.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';

/// =======================
/// ENUM OPTIONS (FROM COURSE MONGOOSE SCHEMA)
/// =======================
const List<String> kCourseSpecializations = ["IIT-JEE", "NEET", "CBSE"];

const List<String> kCourseSubjects = [
  "biology",
  "physics",
  "mathematics",
  "chemistry",
  "english",
  "hindi",
];

const List<String> kCourseClasses = [
  "class-6th",
  "class-7th",
  "class-8th",
  "class-9th",
  "class-10th",
  "class-11th",
  "class-12th",
  "dropper",
];

String _beautifyToken(String value) {
  final v = value.trim();
  if (v.isEmpty) return value;

  // keep specialization casing as is
  if (kCourseSpecializations.contains(v)) return v;

  // class-10th -> Class 10th
  if (v.startsWith("class-")) {
    final x = v.replaceAll("class-", "Class ");
    return x.replaceAll("-", " ");
  }

  // subject -> Title Case
  final clean = v.replaceAll('-', ' ').replaceAll('_', ' ');
  return clean
      .split(' ')
      .where((e) => e.trim().isNotEmpty)
      .map((w) => "${w[0].toUpperCase()}${w.substring(1).toLowerCase()}")
      .join(' ');
}

/// =======================
/// FILTER MODEL
/// =======================
class CourseFilter {
  final String search;
  final List<String> specializations;
  final List<String> subjects;
  final List<String> classes;

  final bool freeOnly;
  final bool activeOnly;

  final bool ongoingOnly;
  final bool upcomingOnly;

  final String sortBy; // createdAt / fees / rating / startDate
  final String sortOrder; // asc / desc

  const CourseFilter({
    this.search = "",
    this.specializations = const [],
    this.subjects = const [],
    this.classes = const [],
    this.freeOnly = false,
    this.activeOnly = true,
    this.ongoingOnly = false,
    this.upcomingOnly = false,
    this.sortBy = "createdAt",
    this.sortOrder = "desc",
  });

  CourseFilter copyWith({
    String? search,
    List<String>? specializations,
    List<String>? subjects,
    List<String>? classes,
    bool? freeOnly,
    bool? activeOnly,
    bool? ongoingOnly,
    bool? upcomingOnly,
    String? sortBy,
    String? sortOrder,
  }) {
    return CourseFilter(
      search: search ?? this.search,
      specializations: specializations ?? this.specializations,
      subjects: subjects ?? this.subjects,
      classes: classes ?? this.classes,
      freeOnly: freeOnly ?? this.freeOnly,
      activeOnly: activeOnly ?? this.activeOnly,
      ongoingOnly: ongoingOnly ?? this.ongoingOnly,
      upcomingOnly: upcomingOnly ?? this.upcomingOnly,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  bool get hasAnyFilter =>
      search.trim().isNotEmpty ||
          specializations.isNotEmpty ||
          subjects.isNotEmpty ||
          classes.isNotEmpty ||
          freeOnly ||
          !activeOnly ||
          ongoingOnly ||
          upcomingOnly ||
          sortBy != "createdAt" ||
          sortOrder != "desc";

  CourseFilter clearOnlySearch() => copyWith(search: "");
  CourseFilter clearAll() => const CourseFilter();

  /// ✅ Production-grade:
  /// - We send server params if supported.
  /// - If backend doesn't support some params -> still safe
  /// because client side filtering will run too.
  Map<String, dynamic> toQueryParams({int page = 1, int limit = 100}) {
    final q = <String, dynamic>{
      "page": page.toString(),
      "limit": limit.toString(),
      "sortBy": sortBy,
      "sortOrder": sortOrder,
    };

    final s = search.trim();
    if (s.isNotEmpty) q["search"] = s; // (if backend supports)

    if (specializations.isNotEmpty) q["specialization"] = specializations;
    if (subjects.isNotEmpty) q["subject"] = subjects;
    if (classes.isNotEmpty) q["class"] = classes;

    if (ongoingOnly) q["status"] = "ongoing"; // if backend supports
    if (upcomingOnly) q["status"] = "upcoming"; // if backend supports

    return q;
  }
}

/// =======================
/// FILTER CONTROLLER
/// =======================
final courseFilterProvider =
StateNotifierProvider.autoDispose<_CourseFilterController, CourseFilter>(
      (ref) => _CourseFilterController(),
);

class _CourseFilterController extends StateNotifier<CourseFilter> {
  _CourseFilterController() : super(const CourseFilter());

  Timer? _debounce;

  void setSearchDebounced(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      state = state.copyWith(search: value);
    });
  }

  void clearSearch() {
    _debounce?.cancel();
    state = state.clearOnlySearch();
  }

  void apply(CourseFilter filter) {
    _debounce?.cancel();
    state = filter;
  }

  void clearAll() {
    _debounce?.cancel();
    state = state.clearAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// =======================
/// Courses Provider (Filtered)
/// =======================
final coursesProvider = FutureProvider.autoDispose<List<Course>>((ref) async {
  final api = ApiService();
  final filter = ref.watch(courseFilterProvider);

  final response = await api.get(
    '/api/courses',
    queryParameters: filter.toQueryParams(page: 1, limit: 100),
  );

  dynamic data = response.data;
  if (data is String) data = jsonDecode(data);

  List<dynamic> coursesList = [];
  if (data is Map && data['courses'] is List) {
    coursesList = data['courses'] as List;
  } else if (data is Map && data['data'] is Map && data['data']['courses'] is List) {
    coursesList = data['data']['courses'] as List;
  } else if (data is List) {
    coursesList = data;
  }

  final all = coursesList
      .map((e) => Course.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  // ✅ extra client-side filters (safe even if backend doesn't support queries)
  var filtered = all;

  // activeOnly
  if (filter.activeOnly) {
    filtered = filtered.where((c) => c.isActive != false && c.status != "deleted").toList();
  }

  // freeOnly
  if (filter.freeOnly) {
    filtered = filtered.where((c) => (c.fees ?? 0) == 0).toList();
  }

  // ongoing / upcoming
  final now = DateTime.now();
  if (filter.ongoingOnly) {
    filtered = filtered.where((c) {
      final s = c.startDate;
      final e = c.endDate;
      if (s == null || e == null) return false;
      return s.isBefore(now) && e.isAfter(now);
    }).toList();
  }
  if (filter.upcomingOnly) {
    filtered = filtered.where((c) {
      final s = c.startDate;
      if (s == null) return false;
      return s.isAfter(now);
    }).toList();
  }

  // search fallback (case-insensitive)
  final search = filter.search.trim().toLowerCase();
  if (search.isNotEmpty) {
    filtered = filtered.where((c) {
      final t = c.title.toLowerCase();
      final d = (c.description ?? "").toLowerCase();
      final edu = (c.educator?.name ?? "").toLowerCase();
      return t.contains(search) || d.contains(search) || edu.contains(search);
    }).toList();
  }

  // local sorting safety
  filtered.sort((a, b) {
    int dir = filter.sortOrder == "asc" ? 1 : -1;

    switch (filter.sortBy) {
      case "fees":
        final av = (a.fees ?? 0);
        final bv = (b.fees ?? 0);
        return dir * av.compareTo(bv);

      case "rating":
        final av = (a.rating ?? 0);
        final bv = (b.rating ?? 0);
        return dir * av.compareTo(bv);

      case "startDate":
        final av = a.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bv = b.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dir * av.compareTo(bv);

      case "createdAt":
      default:
        final av = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bv = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dir * av.compareTo(bv);
    }
  });

  return filtered;
});

/// =======================
/// Screen
/// =======================
class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  final _searchCtrl = TextEditingController();
  bool _searchMode = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openSearch() => setState(() => _searchMode = true);

  void _closeSearch({bool clearSearch = true}) {
    if (clearSearch) {
      _searchCtrl.clear();
      ref.read(courseFilterProvider.notifier).clearSearch();
    }
    FocusScope.of(context).unfocus();
    setState(() => _searchMode = false);
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final filter = ref.watch(courseFilterProvider);

    return WillPopScope(
      onWillPop: () async {
        if (_searchMode) {
          _closeSearch(clearSearch: true);
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _searchMode
                ? _SearchAppBarField(
              key: const ValueKey("course-search"),
              controller: _searchCtrl,
              hint: "Search courses...",
              onChanged: (v) =>
                  ref.read(courseFilterProvider.notifier).setSearchDebounced(v),
            )
                : const Text("Courses", key: ValueKey("course-title")),
          ),
          leading: _searchMode
              ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _closeSearch(clearSearch: true),
          )
              : null,
          actions: [
            if (!_searchMode)
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _openSearch,
              ),
            if (_searchMode)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _closeSearch(clearSearch: true),
              ),
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.filter_list),
                  if (filter.hasAnyFilter && !_searchMode)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () async {
                final current = ref.read(courseFilterProvider);

                final result = await showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  builder: (_) => _CourseFilterSheet(initial: current),
                );

                if (result is CourseFilter) {
                  ref.read(courseFilterProvider.notifier).apply(result);
                }
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(coursesProvider),
          child: coursesAsync.when(
            loading: () => const ShimmerList(itemCount: 5, itemHeight: 160),
            error: (error, stack) => ErrorStateWidget(
              message: error.toString(),
              onRetry: () => ref.invalidate(coursesProvider),
            ),
            data: (courses) {
              if (courses.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.play_circle_outline,
                  title: 'No Courses Available',
                  subtitle: 'Check back later for new courses',
                );
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  return _CourseCard(course: courses[index]);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// =======================
/// Search Field
/// =======================
class _SearchAppBarField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  const _SearchAppBarField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.grey300),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }
}

/// =======================
/// Filter Sheet
/// =======================
class _CourseFilterSheet extends StatefulWidget {
  final CourseFilter initial;
  const _CourseFilterSheet({required this.initial});

  @override
  State<_CourseFilterSheet> createState() => _CourseFilterSheetState();
}

class _CourseFilterSheetState extends State<_CourseFilterSheet> {
  late CourseFilter _filter;

  late List<String> _specializations;
  late List<String> _subjects;
  late List<String> _classes;

  bool _freeOnly = false;
  bool _activeOnly = true;
  bool _ongoingOnly = false;
  bool _upcomingOnly = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;

    _specializations = List<String>.from(_filter.specializations);
    _subjects = List<String>.from(_filter.subjects);
    _classes = List<String>.from(_filter.classes);

    _freeOnly = _filter.freeOnly;
    _activeOnly = _filter.activeOnly;
    _ongoingOnly = _filter.ongoingOnly;
    _upcomingOnly = _filter.upcomingOnly;
  }

  void _toggle(List<String> list, String value) {
    setState(() {
      if (list.contains(value)) {
        list.remove(value);
      } else {
        list.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  const Text("Filters",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context, const CourseFilter()),
                    child: const Text("Clear All"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _section(
                title: "Quick",
                children: [

                  SwitchListTile(
                    value: _freeOnly,
                    onChanged: (v) => setState(() => _freeOnly = v),
                    title: const Text("Free only"),
                  ),
                ],
              ),

              _section(
                title: "Specialization",
                children: kCourseSpecializations
                    .map(
                      (e) => CheckboxListTile(
                    dense: true,
                    value: _specializations.contains(e),
                    onChanged: (_) => _toggle(_specializations, e),
                    title: Text(_beautifyToken(e)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                )
                    .toList(),
              ),

              _section(
                title: "Subjects",
                children: kCourseSubjects
                    .map(
                      (e) => CheckboxListTile(
                    dense: true,
                    value: _subjects.contains(e),
                    onChanged: (_) => _toggle(_subjects, e),
                    title: Text(_beautifyToken(e)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                )
                    .toList(),
              ),

              _section(
                title: "Class",
                children: kCourseClasses
                    .map(
                      (e) => CheckboxListTile(
                    dense: true,
                    value: _classes.contains(e),
                    onChanged: (_) => _toggle(_classes, e),
                    title: Text(_beautifyToken(e)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                )
                    .toList(),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filter.sortBy,
                      decoration: const InputDecoration(labelText: "Sort By"),
                      items: const [
                        DropdownMenuItem(value: "createdAt", child: Text("Newest")),
                        DropdownMenuItem(value: "fees", child: Text("Price")),
                        DropdownMenuItem(value: "rating", child: Text("Rating")),
                        DropdownMenuItem(value: "startDate", child: Text("Start Date")),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _filter = _filter.copyWith(sortBy: v));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filter.sortOrder,
                      decoration: const InputDecoration(labelText: "Order"),
                      items: const [
                        DropdownMenuItem(value: "asc", child: Text("Increasing")),
                        DropdownMenuItem(value: "desc", child: Text("Decreasing")),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _filter = _filter.copyWith(sortOrder: v));
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context), // ✅ close only
                        icon: const Icon(Icons.close),
                        label: const Text("Close"),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final updated = _filter.copyWith(
                            specializations: _specializations,
                            subjects: _subjects,
                            classes: _classes,
                            freeOnly: _freeOnly,
                            activeOnly: _activeOnly,
                            ongoingOnly: _ongoingOnly,
                            upcomingOnly: _upcomingOnly,
                          );
                          Navigator.pop(context, updated); // ✅ apply and close
                        },
                        icon: const Icon(Icons.check),
                        label: const Text("Apply"),
                      ),
                    ),
                  ),
                ],
              )

            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

/// =======================
/// Card UI (unchanged)
/// =======================
class _CourseCard extends StatelessWidget {
  final Course course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/course/${course.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 140,
              width: double.infinity,
              color: AppColors.grey200,
              child: course.imageUrl.isNotEmpty
                  ? Image.network(
                course.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
                  : _buildPlaceholder(),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Specialization badge
                  if (course.specialization.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: course.specialization.take(2).map((spec) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _beautifyToken(spec),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    course.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Educator
                  if (course.educator != null)
                    Row(
                      children: [
                        UserAvatar(
                          imageUrl: course.educator!.profilePicture,
                          name: course.educator!.name,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            course.educator!.name ?? 'Educator',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

                  // Price and action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PriceWidget(
                        price: course.finalPrice,
                        originalPrice: course.fees,
                        discount: course.discount,
                      ),
                      ElevatedButton(
                        onPressed: () => context.push('/course/${course.id}'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: const Text('View Details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.play_circle_outline,
        size: 48,
        color: AppColors.grey400,
      ),
    );
  }
}
