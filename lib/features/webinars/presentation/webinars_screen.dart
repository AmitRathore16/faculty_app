import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/webinar_model.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/user_widgets.dart';

/// =======================
/// ENUM OPTIONS (FROM WEBINAR MONGOOSE SCHEMA)
/// =======================

const List<String> kWebinarSpecializations = [
  "IIT-JEE",
  "NEET",
  "CBSE",
];

const List<String> kWebinarSubjects = [
  "biology",
  "physics",
  "mathematics",
  "chemistry",
  "english",
  "hindi",
];

const List<String> kWebinarClasses = [
  "class-6th",
  "class-7th",
  "class-8th",
  "class-9th",
  "class-10th",
  "class-11th",
  "class-12th",
  "dropper",
];

const List<String> kWebinarTypes = [
  "one-to-one",
  "one-to-all",
];

String _beautifyToken(String value) {
  final v = value.trim();
  if (v.isEmpty) return value;

  // webinar types beautify
  if (v == "one-to-one") return "One-to-One";
  if (v == "one-to-all") return "One-to-All";

  final clean = v.replaceAll('-', ' ').replaceAll('_', ' ');

  return clean
      .split(' ')
      .where((e) => e.trim().isNotEmpty)
      .map((w) {
    final a = w.trim();
    if (a.toUpperCase() == a) return a;
    return "${a[0].toUpperCase()}${a.substring(1).toLowerCase()}";
  })
      .join(' ');
}

/// =======================
/// FILTER MODEL (PRODUCTION)
/// =======================
/// Backend supports:
/// subject, specialization, class, webinarType, upcoming, search
class WebinarsFilter {
  final String search;
  final List<String> specializations;
  final List<String> subjects;
  final List<String> classes;
  final List<String> webinarTypes;

  final bool upcomingOnly; // upcoming=true
  final bool freeOnly; // handled client side: fees==0

  final String sortBy;
  final String sortOrder;

  const WebinarsFilter({
    this.search = "",
    this.specializations = const [],
    this.subjects = const [],
    this.classes = const [],
    this.webinarTypes = const [],
    this.upcomingOnly = false,
    this.freeOnly = false,
    this.sortBy = "timing",
    this.sortOrder = "asc",
  });

  WebinarsFilter copyWith({
    String? search,
    List<String>? specializations,
    List<String>? subjects,
    List<String>? classes,
    List<String>? webinarTypes,
    bool? upcomingOnly,
    bool? freeOnly,
    String? sortBy,
    String? sortOrder,
  }) {
    return WebinarsFilter(
      search: search ?? this.search,
      specializations: specializations ?? this.specializations,
      subjects: subjects ?? this.subjects,
      classes: classes ?? this.classes,
      webinarTypes: webinarTypes ?? this.webinarTypes,
      upcomingOnly: upcomingOnly ?? this.upcomingOnly,
      freeOnly: freeOnly ?? this.freeOnly,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  bool get hasAnyFilter =>
      search.trim().isNotEmpty ||
          specializations.isNotEmpty ||
          subjects.isNotEmpty ||
          classes.isNotEmpty ||
          webinarTypes.isNotEmpty ||
          upcomingOnly ||
          freeOnly ||
          sortBy != "timing" ||
          sortOrder != "asc";

  WebinarsFilter clearOnlySearch() => copyWith(search: "");

  WebinarsFilter clearAll() => const WebinarsFilter();

  Map<String, dynamic> toQueryParams({int page = 1, int limit = 50}) {
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
    if (classes.isNotEmpty) q["class"] = classes;

    // Backend supports one webinarType, but we want production multi-select.
    // We'll send list; backend uses: filter.webinarType = webinarType
    // So multi won't work unless backend changes.
    // ✅ We'll apply multi webinarType filter client-side (safe).
    // But if only one selected, send it to backend.
    if (webinarTypes.length == 1) q["webinarType"] = webinarTypes.first;

    if (upcomingOnly) q["upcoming"] = "true";

    return q;
  }
}

/// =======================
/// FILTER CONTROLLER
/// =======================
final webinarsFilterProvider =
StateNotifierProvider.autoDispose<_WebinarsFilterController, WebinarsFilter>(
      (ref) => _WebinarsFilterController(),
);

class _WebinarsFilterController extends StateNotifier<WebinarsFilter> {
  _WebinarsFilterController() : super(const WebinarsFilter());

  Timer? _debounce;

  void setSearchDebounced(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      state = state.copyWith(search: value);
    });
  }

  void apply(WebinarsFilter filter) {
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
/// DATA PROVIDER
/// =======================
/// ✅ one provider for all webinars (then UI separates live/upcoming with tabs)
final webinarsProvider = FutureProvider.autoDispose<List<Webinar>>((ref) async {
  final api = ApiService();
  final filter = ref.watch(webinarsFilterProvider);

  final res = await api.get(
    "/api/webinars",
    queryParameters: filter.toQueryParams(page: 1, limit: 100),
  );

  dynamic data = res.data;
  if (data is String) data = jsonDecode(data);

  List<dynamic> list = [];
  if (data is Map && data['data'] is Map && data['data']['webinars'] is List) {
    list = data['data']['webinars'] as List;
  } else if (data is Map && data['webinars'] is List) {
    list = data['webinars'] as List;
  } else if (data is List) {
    list = data;
  }

  final webinars =
  list.map((e) => Webinar.fromJson(Map<String, dynamic>.from(e))).toList();

  // ✅ additional client-side filters (production safe)
  var filtered = webinars;

  // Free only filter
  if (filter.freeOnly) {
    filtered = filtered.where((w) => w.isFree).toList();
  }

  // Multi webinarTypes filter client-side
  if (filter.webinarTypes.isNotEmpty) {
    filtered = filtered.where((w) => filter.webinarTypes.contains(w.webinarType)).toList();
  }

  return filtered;
});

/// =======================
/// SCREEN
/// =======================
class WebinarsScreen extends ConsumerStatefulWidget {
  const WebinarsScreen({super.key});

  @override
  ConsumerState<WebinarsScreen> createState() => _WebinarsScreenState();
}

class _WebinarsScreenState extends ConsumerState<WebinarsScreen> {
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
      ref.read(webinarsFilterProvider.notifier).clearSearch();
    }
    FocusScope.of(context).unfocus();
    setState(() => _searchMode = false);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(webinarsFilterProvider);
    final webinarsAsync = ref.watch(webinarsProvider);

    return WillPopScope(
      onWillPop: () async {
        // ✅ production-grade: back closes search mode first
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
                    .read(webinarsFilterProvider.notifier)
                    .setSearchDebounced(v),
              )
                  : const Text(
                "Webinars",
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
                  final current = ref.read(webinarsFilterProvider);

                  final result = await showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    builder: (_) => _WebinarsFilterSheet(initial: current),
                  );

                  if (result is WebinarsFilter) {
                    ref.read(webinarsFilterProvider.notifier).apply(result);
                  }
                },
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: "Live"),
                Tab(text: "Upcoming"),
              ],
            ),
          ),
          body: webinarsAsync.when(
            loading: () => const ShimmerList(itemCount: 5, itemHeight: 210),
            error: (e, s) => ErrorStateWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(webinarsProvider),
            ),
            data: (all) {
              // ✅ Separate tabs based on Webinar model computed properties
              final live = all.where((w) => w.isLive).toList();
              final upcoming = all.where((w) => w.isUpcoming).toList();

              return TabBarView(
                children: [
                  _webinarList(
                    webinars: live,
                    emptyIcon: Icons.wifi_tethering_outlined,
                    emptyTitle: "No Live Webinars",
                    emptySubtitle: "Live webinars will appear here",
                  ),
                  _webinarList(
                    webinars: upcoming,
                    emptyIcon: Icons.event_available_outlined,
                    emptyTitle: "No Upcoming Webinars",
                    emptySubtitle: "New webinars will appear here",
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _webinarList({
    required List<Webinar> webinars,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (webinars.isEmpty) {
      return EmptyStateWidget(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(webinarsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: webinars.length,
        itemBuilder: (context, index) => _WebinarCard(webinar: webinars[index]),
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
        hintText: "Search webinars...",
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.grey300),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }
}

/// =======================
/// WEBINAR CARD (YOUR UI KEPT SAME)
/// =======================
class _WebinarCard extends StatelessWidget {
  final Webinar webinar;

  const _WebinarCard({required this.webinar});

  String _formatDuration(String value) {
    final v = value.trim().toLowerCase();

    final match = RegExp(r'(\d+)').firstMatch(v);
    final mins = match != null ? int.tryParse(match.group(1)!) : null;

    if (mins == null) return value.trim();

    if (v.contains('hour') || v.contains('hr') || v.contains('h')) {
      return "${mins} hr";
    }
    if (v.contains('min') || v.contains('m')) {
      return "${mins} min";
    }

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
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/webinar/${webinar.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  color: AppColors.grey200,
                  child: webinar.imageUrl.isNotEmpty
                      ? Image.network(
                    webinar.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                      : _buildPlaceholder(),
                ),
                Positioned(top: 12, left: 12, child: _buildStatusBadge()),
                Positioned(top: 12, right: 12, child: _buildPriceBadge()),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    webinar.title,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  if (webinar.educatorName != null)
                    Row(
                      children: [
                        UserAvatar(
                          imageUrl: null,
                          name: webinar.educatorName,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            webinar.educatorName!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: AppColors.grey600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          DateFormatter.formatDateTime(webinar.timing),
                          style: TextStyle(
                              color: AppColors.grey600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (webinar.duration.trim().isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.timer,
                            size: 14, color: AppColors.grey600),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(webinar.duration),
                          style: TextStyle(
                            color: AppColors.grey700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.chair_alt_outlined,
                          size: 16, color: AppColors.grey600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          webinar.remainingSeats <= 0
                              ? 'No seats available'
                              : '${webinar.remainingSeats} seats available',
                          style: TextStyle(
                              color: AppColors.grey700, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.grey100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          webinar.webinarType == 'one-to-one'
                              ? 'One-to-One'
                              : 'One-to-All',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.grey800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push('/webinar/${webinar.id}'),
                      child: Text(_getButtonText()),
                    ),
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
        Icons.videocam_outlined,
        size: 48,
        color: AppColors.grey400,
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;

    if (webinar.isLive) {
      color = AppColors.error;
      text = '● LIVE';
    } else if (webinar.isUpcoming) {
      color = AppColors.primary;
      text = 'UPCOMING';
    } else {
      color = AppColors.grey500;
      text = 'ENDED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPriceBadge() {
    final isFree = webinar.isFree;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isFree ? AppColors.success : Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isFree ? 'FREE' : '₹${webinar.fees.toInt()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getButtonText() {
    if (webinar.isLive && webinar.hasJoinLink) return 'Join Webinar';
    if (webinar.isEnded && webinar.hasRecordings) return 'Watch Recording';
    return 'View Details';
  }
}

/// =======================
/// FILTER BOTTOM SHEET
/// =======================
class _WebinarsFilterSheet extends StatefulWidget {
  final WebinarsFilter initial;

  const _WebinarsFilterSheet({required this.initial});

  @override
  State<_WebinarsFilterSheet> createState() => _WebinarsFilterSheetState();
}

class _WebinarsFilterSheetState extends State<_WebinarsFilterSheet> {
  late WebinarsFilter _filter;

  late List<String> _specializations;
  late List<String> _subjects;
  late List<String> _classes;
  late List<String> _types;

  bool _upcomingOnly = false;
  bool _freeOnly = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;

    _specializations = List<String>.from(_filter.specializations);
    _subjects = List<String>.from(_filter.subjects);
    _classes = List<String>.from(_filter.classes);
    _types = List<String>.from(_filter.webinarTypes);

    _upcomingOnly = _filter.upcomingOnly;
    _freeOnly = _filter.freeOnly;
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
                    onPressed: () => Navigator.pop(context, const WebinarsFilter()),
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
                title: "Webinar Type",
                children: kWebinarTypes
                    .map(
                      (e) => CheckboxListTile(
                    dense: true,
                    value: _types.contains(e),
                    onChanged: (_) => _toggle(_types, e),
                    title: Text(_beautifyToken(e)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                )
                    .toList(),
              ),

              _filterSection(
                title: "Specialization",
                children: kWebinarSpecializations
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
                children: kWebinarSubjects
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

              _filterSection(
                title: "Classes",
                children: kWebinarClasses
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
                        DropdownMenuItem(value: "timing", child: Text("Timing")),
                        DropdownMenuItem(value: "createdAt", child: Text("Newest")),
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
                            webinarTypes: _types,
                            upcomingOnly: _upcomingOnly,
                            freeOnly: _freeOnly,
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
