import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/educator_model.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';

/// =======================
/// ENUM OPTIONS (FROM YOUR MONGOOSE SCHEMA)
/// =======================

const List<String> kEducatorSpecializations = [
  "IIT-JEE",
  "NEET",
  "CBSE",
];

const List<String> kEducatorSubjects = [
  "biology",
  "physics",
  "mathematics",
  "chemistry",
  "english",
  "hindi",
];

const List<String> kEducatorClasses = [
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
  // "class-10th" -> "Class 10th"
  // "IIT-JEE" -> "IIT JEE"
  // "mathematics" -> "Mathematics"
  final v = value.trim();
  if (v.isEmpty) return value;

  final clean = v.replaceAll('-', ' ').replaceAll('_', ' ');

  return clean
      .split(' ')
      .where((e) => e.trim().isNotEmpty)
      .map((w) {
    final a = w.trim();
    if (a.toUpperCase() == a) return a; // IIT / JEE stays same
    return "${a[0].toUpperCase()}${a.substring(1).toLowerCase()}";
  })
      .join(' ');
}

/// =======================
/// FILTER MODEL
/// =======================
/// Backend accepts: specialization, subject, class, minRating, search, sortBy
///
/// IMPORTANT: backend currently supports ONE specialization/subject/class via query
/// but schema has arrays, and production filters are checkbox multi-select.
/// So we send the first selected OR join by comma (if backend supports arrays).
///
/// Your educator controller:
/// specialization: filter.specialization = {$in: ...}
/// subject: {$in: ...}
/// class: {$in: ...}
///
/// ✅ So we can safely send multiple values by query:
/// specialization=NEET&specialization=CBSE  (array style)
/// OR specialization=NEET,CBSE (comma style)
///
/// ApiService may support either. Here we use array style.
class EducatorsFilter {
  final String search;
  final List<String> specializations; // multi
  final List<String> subjects; // multi
  final List<String> classes; // multi
  final double? minRating;
  final String sortBy;
  final String sortOrder;

  const EducatorsFilter({
    this.search = "",
    this.specializations = const [],
    this.subjects = const [],
    this.classes = const [],
    this.minRating,
    this.sortBy = "createdAt",
    this.sortOrder = "desc",
  });

  EducatorsFilter copyWith({
    String? search,
    List<String>? specializations,
    List<String>? subjects,
    List<String>? classes,
    double? minRating,
    String? sortBy,
    String? sortOrder,
  }) {
    return EducatorsFilter(
      search: search ?? this.search,
      specializations: specializations ?? this.specializations,
      subjects: subjects ?? this.subjects,
      classes: classes ?? this.classes,
      minRating: minRating ?? this.minRating,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  bool get hasAnyFilter =>
      search.trim().isNotEmpty ||
          specializations.isNotEmpty ||
          subjects.isNotEmpty ||
          classes.isNotEmpty ||
          minRating != null ||
          sortBy != "createdAt" ||
          sortOrder != "desc";

  Map<String, dynamic> toQueryParams({int page = 1, int limit = 30}) {
    final q = <String, dynamic>{
      "page": page.toString(),
      "limit": limit.toString(),
      "sortBy": sortBy,
      "sortOrder": sortOrder,
    };

    // ✅ case-insensitive search:
    // frontend normalization only (backend regex already handles $options:"i")
    final s = search.trim();
    if (s.isNotEmpty) q["search"] = s;

    if (specializations.isNotEmpty) q["specialization"] = specializations;
    if (subjects.isNotEmpty) q["subject"] = subjects;
    if (classes.isNotEmpty) q["class"] = classes;
    if (minRating != null) q["minRating"] = minRating!.toString();

    return q;
  }

  EducatorsFilter clearOnlySearch() {
    return copyWith(search: "");
  }

  EducatorsFilter clearAll() {
    return const EducatorsFilter();
  }
}

/// =======================
/// FILTER CONTROLLER
/// =======================
final educatorsFilterProvider =
StateNotifierProvider.autoDispose<_EducatorsFilterController, EducatorsFilter>(
      (ref) => _EducatorsFilterController(),
);

class _EducatorsFilterController extends StateNotifier<EducatorsFilter> {
  _EducatorsFilterController() : super(const EducatorsFilter());

  Timer? _debounce;

  void setSearchDebounced(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      state = state.copyWith(search: value);
    });
  }

  void apply(EducatorsFilter filter) {
    _debounce?.cancel();
    state = filter;
  }

  void clearSearch() {
    _debounce?.cancel();
    state = state.clearOnlySearch();
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
/// EDUCATORS PROVIDER
/// =======================
final educatorsProvider = FutureProvider.autoDispose<List<Educator>>((ref) async {
  final api = ApiService();
  final filter = ref.watch(educatorsFilterProvider);

  final response = await api.get(
    '/api/educators',
    queryParameters: filter.toQueryParams(page: 1, limit: 30),
  );

  dynamic data = response.data;
  if (data is String) data = jsonDecode(data);

  List<dynamic> educatorsList = [];
  if (data is Map && data['data'] is Map && data['data']['educators'] is List) {
    educatorsList = data['data']['educators'] as List;
  }

  return educatorsList
      .map((e) => Educator.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

/// =======================
/// SCREEN
/// =======================
class EducatorsScreen extends ConsumerStatefulWidget {
  const EducatorsScreen({super.key});

  @override
  ConsumerState<EducatorsScreen> createState() => _EducatorsScreenState();
}

class _EducatorsScreenState extends ConsumerState<EducatorsScreen> {
  final _searchCtrl = TextEditingController();
  bool _searchMode = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchMode = true);
  }

  void _closeSearch({bool clearSearch = true}) {
    if (clearSearch) {
      _searchCtrl.clear();
      ref.read(educatorsFilterProvider.notifier).clearSearch();
    }
    FocusScope.of(context).unfocus();
    setState(() => _searchMode = false);
  }

  @override
  Widget build(BuildContext context) {
    final educatorsAsync = ref.watch(educatorsProvider);
    final filter = ref.watch(educatorsFilterProvider);

    return WillPopScope(
      onWillPop: () async {
        // ✅ Production-grade: Back button should close search mode first.
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
              key: const ValueKey("search"),
              controller: _searchCtrl,
              onChanged: (v) {
                ref
                    .read(educatorsFilterProvider.notifier)
                    .setSearchDebounced(v);
              },
            )
                : const Text(
              'Educators',
              key: ValueKey("title"),
            ),
          ),
          leading: _searchMode
              ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _closeSearch(clearSearch: true),
          )
              : null,
          actions: [
            // ✅ Search icon -> toggle search mode
            if (!_searchMode)
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _openSearch,
              ),

            // ✅ Close icon inside search mode
            if (_searchMode)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _closeSearch(clearSearch: true),
              ),

            // ✅ Filter
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
                final current = ref.read(educatorsFilterProvider);

                final result = await showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  builder: (_) => _EducatorsFilterSheet(initial: current),
                );

                if (result is EducatorsFilter) {
                  ref.read(educatorsFilterProvider.notifier).apply(result);
                }
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(educatorsProvider),
          child: educatorsAsync.when(
            loading: () => const ShimmerList(itemCount: 6, itemHeight: 140),
            error: (error, stack) => ErrorStateWidget(
              message: error.toString(),
              onRetry: () => ref.invalidate(educatorsProvider),
            ),
            data: (educators) {
              if (educators.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.people_outline,
                  title: 'No Educators Found',
                  subtitle: 'Try changing search/filter',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: educators.length,
                itemBuilder: (context, index) {
                  return _EducatorCard(
                    educator: educators[index],
                    ref: ref,
                  );
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
/// SEARCH FIELD WIDGET
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
        hintText: "Search educators...",
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.grey300),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }
}

/// =======================
/// EDUCATOR CARD
/// =======================
class _EducatorCard extends StatelessWidget {
  final Educator educator;
  final WidgetRef ref;

  const _EducatorCard({
    required this.educator,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = educator.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          await context.push('/educator/${educator.id}');
          ref.invalidate(educatorsProvider);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                imageUrl: educator.imageUrl,
                name: educator.displayName,
                size: 70,
                showBorder: isActive,
                borderColor: AppColors.success,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            educator.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.book, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            educator.displaySubjects,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (educator.bio != null && educator.bio!.isNotEmpty)
                      Text(
                        educator.bio!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildInfoChip(
                          Icons.people,
                          '${educator.followerCount} followers',
                        ),
                        _buildInfoChip(
                          Icons.work,
                          educator.displayExperience,
                        ),
                        if (educator.rating != null)
                          RatingWidget(
                            rating: educator.rating!.average ?? 0,
                            count: educator.rating!.count,
                            size: 14,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.grey500),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.grey600,
          ),
        ),
      ],
    );
  }
}

/// =======================
/// FILTER BOTTOM SHEET (PRODUCTION CHECKBOX UI)
/// =======================
class _EducatorsFilterSheet extends StatefulWidget {
  final EducatorsFilter initial;
  const _EducatorsFilterSheet({required this.initial});

  @override
  State<_EducatorsFilterSheet> createState() => _EducatorsFilterSheetState();
}

class _EducatorsFilterSheetState extends State<_EducatorsFilterSheet> {
  late EducatorsFilter _filter;
  late List<String> _specializations;
  late List<String> _subjects;
  late List<String> _classes;

  double? _minRating;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;

    _specializations = List<String>.from(_filter.specializations);
    _subjects = List<String>.from(_filter.subjects);
    _classes = List<String>.from(_filter.classes);
    _minRating = _filter.minRating;
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
                    onPressed: () {
                      Navigator.pop(context, const EducatorsFilter());
                    },
                    child: const Text("Clear All"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _filterSection(
                title: "Specialization",
                children: kEducatorSpecializations
                    .map((e) => CheckboxListTile(
                  dense: true,
                  value: _specializations.contains(e),
                  onChanged: (_) => _toggle(_specializations, e),
                  title: Text(_beautifyToken(e)),
                  controlAffinity: ListTileControlAffinity.leading,
                ))
                    .toList(),
              ),

              _filterSection(
                title: "Subjects",
                children: kEducatorSubjects
                    .map((e) => CheckboxListTile(
                  dense: true,
                  value: _subjects.contains(e),
                  onChanged: (_) => _toggle(_subjects, e),
                  title: Text(_beautifyToken(e)),
                  controlAffinity: ListTileControlAffinity.leading,
                ))
                    .toList(),
              ),

              _filterSection(
                title: "Classes",
                children: kEducatorClasses
                    .map((e) => CheckboxListTile(
                  dense: true,
                  value: _classes.contains(e),
                  onChanged: (_) => _toggle(_classes, e),
                  title: Text(_beautifyToken(e)),
                  controlAffinity: ListTileControlAffinity.leading,
                ))
                    .toList(),
              ),

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Min Rating: ${_minRating == null ? "Any" : _minRating!.toStringAsFixed(0)}+",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Slider(
                value: (_minRating ?? 0).clamp(0, 5),
                min: 0,
                max: 5,
                divisions: 5,
                onChanged: (v) {
                  setState(() => _minRating = (v <= 0) ? null : v);
                },
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
                        DropdownMenuItem(value: "rating.average", child: Text("Rating")),
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
                        DropdownMenuItem(value: "desc", child: Text("Decreasing")),
                        DropdownMenuItem(value: "asc", child: Text("Increasing")),
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
                            minRating: _minRating,
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
