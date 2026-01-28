import 'dart:async';
import 'dart:convert';

import 'package:faculty_pedia/features/auth/providers/auth_provider.dart';
import 'package:faculty_pedia/shared/models/student_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/test_series_model.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';

/// =======================
/// ENUM OPTIONS (FROM TEST SERIES MONGOOSE SCHEMA)
/// =======================
const List<String> kTestSeriesSpecializations = [
  "IIT-JEE",
  "NEET",
  "CBSE",
];

const List<String> kTestSeriesSubjects = [
  "biology",
  "physics",
  "mathematics",
  "chemistry",
  "english",
  "hindi",
];

String _beautifyToken(String value) {
  final v = value.trim();
  if (v.isEmpty) return value;

  // Specialization keeps casing
  if (kTestSeriesSpecializations.contains(v)) return v;

  // subject -> Title Case
  final clean = v.replaceAll('-', ' ').replaceAll('_', ' ');
  return clean
      .split(' ')
      .where((e) => e.trim().isNotEmpty)
      .map((w) => "${w[0].toUpperCase()}${w.substring(1).toLowerCase()}")
      .join(' ');
}

/// =======================
/// FILTER MODEL (PRODUCTION)
/// =======================
/// Backend getAllTestSeries supports filters similarly (commonly):
/// search, specialization, subject, sortBy, sortOrder
///
/// We also apply some filters client-side safely:
/// freeOnly, activeOnly
class TestSeriesFilter {
  final String search;
  final List<String> specializations;
  final List<String> subjects;

  final bool freeOnly;
  final bool activeOnly;

  final String sortBy; // createdAt / rating / price
  final String sortOrder; // asc / desc

  const TestSeriesFilter({
    this.search = "",
    this.specializations = const [],
    this.subjects = const [],
    this.freeOnly = false,
    this.activeOnly = true,
    this.sortBy = "createdAt",
    this.sortOrder = "desc",
  });

  TestSeriesFilter copyWith({
    String? search,
    List<String>? specializations,
    List<String>? subjects,
    bool? freeOnly,
    bool? activeOnly,
    String? sortBy,
    String? sortOrder,
  }) {
    return TestSeriesFilter(
      search: search ?? this.search,
      specializations: specializations ?? this.specializations,
      subjects: subjects ?? this.subjects,
      freeOnly: freeOnly ?? this.freeOnly,
      activeOnly: activeOnly ?? this.activeOnly,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  bool get hasAnyFilter =>
      search.trim().isNotEmpty ||
          specializations.isNotEmpty ||
          subjects.isNotEmpty ||
          freeOnly ||
          !activeOnly ||
          sortBy != "createdAt" ||
          sortOrder != "desc";

  TestSeriesFilter clearOnlySearch() => copyWith(search: "");

  TestSeriesFilter clearAll() => const TestSeriesFilter();

  Map<String, dynamic> toQueryParams({int page = 1, int limit = 100}) {
    final q = <String, dynamic>{
      "page": page.toString(),
      "limit": limit.toString(),
      "sortBy": sortBy,
      "sortOrder": sortOrder,
    };

    final s = search.trim();
    if (s.isNotEmpty) q["search"] = s;

    if (specializations.isNotEmpty) q["specialization"] = specializations;
    if (subjects.isNotEmpty) q["subject"] = subjects;

    return q;
  }
}

/// =======================
/// FILTER CONTROLLER
/// =======================
final testSeriesFilterProvider = StateNotifierProvider.autoDispose<
    _TestSeriesFilterController, TestSeriesFilter>(
      (ref) => _TestSeriesFilterController(),
);

class _TestSeriesFilterController extends StateNotifier<TestSeriesFilter> {
  _TestSeriesFilterController() : super(const TestSeriesFilter());

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

  void apply(TestSeriesFilter filter) {
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
/// Providers
/// =======================

/// ✅ Fetch latest student from DB (same pattern as MyCourses + MyTestResults)
final currentStudentProvider = FutureProvider.autoDispose<Student>((ref) async {
  final authState = ref.watch(authStateProvider);
  final userId = authState.user?.id;

  if (userId == null) throw Exception("Please login");

  final api = ApiService();
  final res = await api.get('/api/students/$userId');

  final data = res.data;
  if (data is Map && data['data'] != null) {
    return Student.fromJson(Map<String, dynamic>.from(data['data']));
  }

  throw Exception("Invalid student response");
});

/// ✅ Test series provider with filter support
final testSeriesProvider = FutureProvider.autoDispose<List<TestSeries>>((ref) async {
  final api = ApiService();
  final filter = ref.watch(testSeriesFilterProvider);

  final response = await api.get(
    '/api/test-series',
    queryParameters: filter.toQueryParams(page: 1, limit: 100),
  );

  dynamic data = response.data;
  if (data is String) data = jsonDecode(data);

  List<dynamic> seriesList = [];

  // You currently use: { testSeries: [] }
  if (data is Map && data['testSeries'] is List) {
    seriesList = data['testSeries'] as List;
  } else if (data is Map && data['data'] is Map && data['data']['testSeries'] is List) {
    seriesList = data['data']['testSeries'] as List;
  } else if (data is List) {
    seriesList = data;
  }

  final all = seriesList
      .map((e) => TestSeries.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  // ✅ additional client-side filters for production safety
  var filtered = all;

  // activeOnly
  if (filter.activeOnly) {
    filtered = filtered.where((s) => s.isActive != false).toList();
  }

  // freeOnly
  if (filter.freeOnly) {
    filtered = filtered.where((s) => (s.fees ?? 0) == 0).toList();
  }

  return filtered;
});

/// ==============================
/// Screen
/// ==============================
class TestSeriesScreen extends ConsumerStatefulWidget {
  const TestSeriesScreen({super.key});

  @override
  ConsumerState<TestSeriesScreen> createState() => _TestSeriesScreenState();
}

class _TestSeriesScreenState extends ConsumerState<TestSeriesScreen> {
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
      ref.read(testSeriesFilterProvider.notifier).clearSearch();
    }
    FocusScope.of(context).unfocus();
    setState(() => _searchMode = false);
  }

  @override
  Widget build(BuildContext context) {
    final testSeriesAsync = ref.watch(testSeriesProvider);
    final studentAsync = ref.watch(currentStudentProvider);
    final filter = ref.watch(testSeriesFilterProvider);

    return WillPopScope(
      onWillPop: () async {
        // ✅ production-grade: back closes search first
        if (_searchMode) {
          _closeSearch(clearSearch: true);
          return false;
        }
        return true;
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _searchMode
                  ? _SearchAppBarField(
                key: const ValueKey("search"),
                controller: _searchCtrl,
                onChanged: (v) => ref
                    .read(testSeriesFilterProvider.notifier)
                    .setSearchDebounced(v),
              )
                  : const Text("Test Series", key: ValueKey("title")),
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
                  final current = ref.read(testSeriesFilterProvider);

                  final result = await showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    builder: (_) => _TestSeriesFilterSheet(initial: current),
                  );

                  if (result is TestSeriesFilter) {
                    ref.read(testSeriesFilterProvider.notifier).apply(result);
                  }
                },
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: "All"),
                Tab(text: "Enrolled"),
              ],
            ),
          ),

          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(testSeriesProvider);
              ref.invalidate(currentStudentProvider);
            },
            child: testSeriesAsync.when(
              loading: () => const ShimmerList(itemCount: 5, itemHeight: 140),
              error: (error, stack) => ErrorStateWidget(
                message: error.toString(),
                onRetry: () => ref.invalidate(testSeriesProvider),
              ),
              data: (series) {
                if (series.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.assignment_outlined,
                    title: 'No Test Series Available',
                    subtitle: 'Check back later for new test series',
                  );
                }

                // ✅ enrolled ids from fresh student only
                final enrolledIds = <String>{};
                studentAsync.whenData((student) {
                  enrolledIds.addAll(student.testSeries.map((e) => e.id));
                });

                final allSeries = series;

                final enrolledSeries =
                series.where((s) => enrolledIds.contains(s.id)).toList();

                return TabBarView(
                  children: [
                    // ====== TAB 1: ALL ======
                    ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: allSeries.length,
                      itemBuilder: (context, index) {
                        return _TestSeriesCard(
                          series: allSeries[index],
                          isEnrolled: enrolledIds.contains(allSeries[index].id),
                        );
                      },
                    ),

                    // ====== TAB 2: ENROLLED ======
                    enrolledSeries.isEmpty
                        ? const SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: EmptyStateWidget(
                          icon: Icons.lock_outline,
                          title: "No Enrolled Test Series",
                          subtitle: "Enroll in a test series to see it here.",
                        ),
                      ),
                    )
                        : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: enrolledSeries.length,
                      itemBuilder: (context, index) {
                        return _TestSeriesCard(
                          series: enrolledSeries[index],
                          isEnrolled: true,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================
/// SEARCH FIELD
/// =======================
class _SearchAppBarField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchAppBarField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: "Search test series...",
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.grey300),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }
}

/// =======================
/// FILTER SHEET
/// =======================
class _TestSeriesFilterSheet extends StatefulWidget {
  final TestSeriesFilter initial;

  const _TestSeriesFilterSheet({required this.initial});

  @override
  State<_TestSeriesFilterSheet> createState() => _TestSeriesFilterSheetState();
}

class _TestSeriesFilterSheetState extends State<_TestSeriesFilterSheet> {
  late TestSeriesFilter _filter;

  late List<String> _specializations;
  late List<String> _subjects;

  bool _freeOnly = false;
  bool _activeOnly = true;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;

    _specializations = List<String>.from(_filter.specializations);
    _subjects = List<String>.from(_filter.subjects);

    _freeOnly = _filter.freeOnly;
    _activeOnly = _filter.activeOnly;
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    "Filters",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context, const TestSeriesFilter()),
                    child: const Text("Clear All"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _filterSection(
                title: "Quick",
                children: [

                  SwitchListTile(
                    value: _freeOnly,
                    onChanged: (v) => setState(() => _freeOnly = v),
                    title: const Text("Free only"),
                  ),
                ],
              ),

              _filterSection(
                title: "Specialization",
                children: kTestSeriesSpecializations
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

              _filterSection(
                title: "Subjects",
                children: kTestSeriesSubjects
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

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filter.sortBy,
                      decoration: const InputDecoration(labelText: "Sort By"),
                      items: const [
                        DropdownMenuItem(value: "createdAt", child: Text("Newest")),
                        DropdownMenuItem(value: "rating", child: Text("Rating")),
                        DropdownMenuItem(value: "price", child: Text("Price")),
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
                                freeOnly: _freeOnly,
                                activeOnly: _activeOnly,
                              );
                              Navigator.pop(context, updated);
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

  Widget _filterSection({required String title, required List<Widget> children}) {
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

/// ==============================
/// Card
/// ==============================
class _TestSeriesCard extends StatelessWidget {
  final TestSeries series;
  final bool isEnrolled;

  const _TestSeriesCard({
    required this.series,
    required this.isEnrolled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => context.push('/test-series/${series.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEnrolled ? Icons.check_circle : Icons.assignment,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          series.title,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (series.educatorName != null)
                          Text(
                            'By ${series.educatorName}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        if (isEnrolled) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.25),
                              ),
                            ),
                            child: const Text(
                              "Enrolled",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stats
              Row(
                children: [
                  _buildStatChip(Icons.quiz, '${series.totalTests ?? 0} Tests'),
                  const SizedBox(width: 12),
                  _buildStatChip(Icons.people, '${series.enrolledCount ?? 0} Enrolled'),
                ],
              ),
              const SizedBox(height: 12),

              // Subjects
              if (series.subject.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: series.subject.take(3).map((subject) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _beautifyToken(subject),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.grey700,
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // Price and Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PriceWidget(
                    price: series.fees ?? 0,
                    discount: series.discount,
                    originalPrice: series.fees,
                  ),
                  ElevatedButton(
                    onPressed: () => context.push('/test-series/${series.id}'),
                    child: const Text('View Tests'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.grey600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.grey600,
          ),
        ),
      ],
    );
  }
}
