import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toggle.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../projects/project_widgets.dart';
import 'responses_data.dart';
import 'responses_widgets.dart';

/// Figma 07.1 Responses (3:3274), inside the Insights tab.
class ResponsesScreen extends ConsumerStatefulWidget {
  const ResponsesScreen({super.key});
  @override
  ConsumerState<ResponsesScreen> createState() => _ResponsesScreenState();
}

class _ResponsesScreenState extends ConsumerState<ResponsesScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(responseSearchProvider);
    _searching = _search.text.isNotEmpty;
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (_searching) {
      _focus.requestFocus();
    } else {
      _search.clear();
      _focus.unfocus();
      ref.read(responseSearchProvider.notifier).state = '';
    }
  }

  Future<void> _openFilters() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.white,
    sheetAnimationStyle: sheetMotion(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _FilterSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(responsesProvider);
    final filter = ref.watch(responseFilterProvider);
    final query = ref.watch(responseSearchProvider).trim().toLowerCase();
    final sort = ref.watch(responseSortProvider);
    final unsyncedOnly = ref.watch(unsyncedOnlyProvider);
    final preview = ref.watch(insightsPreviewProvider);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final now = DateTime.now();

    final visible =
        [
          for (final r in all)
            if (filter.matches(r) &&
                (!unsyncedOnly || !r.synced) &&
                (query.isEmpty ||
                    r.name.toLowerCase().contains(query) ||
                    r.code.toLowerCase().contains(query)))
              r,
        ]..sort(
          (a, b) => sort == ResponseSort.newest
              ? b.at.compareTo(a.at)
              : a.at.compareTo(b.at),
        );
    final filtersOn = sort != ResponseSort.newest || unsyncedOnly;

    void back() => context.canPop() ? context.pop() : context.go('/insights');

    // Swipe right to go back to Insights (07.3); Figma 07.1 has no back
    // button.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 600) back();
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: CustomScrollView(
                  key: const PageStorageKey('responses-scroll'),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  'Responses',
                                  key: const ValueKey('page-title-responses'),
                                  style: dashboardText(
                                    32,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            ProjectCircleButton(
                              icon: _searching ? 'consent/x' : 'search',
                              label: _searching
                                  ? 'Close search'
                                  : 'Search responses',
                              onPressed: _toggleSearch,
                            ),
                            const SizedBox(width: 4),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ProjectCircleButton(
                                  icon: 'responses/filter',
                                  label: filtersOn
                                      ? 'Sort and filter, on'
                                      : 'Sort and filter',
                                  onPressed: _openFilters,
                                ),
                                if (filtersOn)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: AnimatedSize(
                        duration: Duration(milliseconds: reduced ? 0 : 250),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _searching
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  0,
                                ),
                                child: _SearchField(
                                  controller: _search,
                                  focusNode: _focus,
                                  onChanged: (v) =>
                                      ref
                                              .read(
                                                responseSearchProvider.notifier,
                                              )
                                              .state =
                                          v,
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 13, bottom: 18),
                        child: PillChips<ResponseFilter>(
                          values: ResponseFilter.values,
                          selected: filter,
                          label: (f) =>
                              '${f.label} ${all.where(f.matches).length}',
                          semanticLabel: (f) =>
                              '${f.label}, ${all.where(f.matches).length} responses',
                          onSelected: (f) =>
                              ref.read(responseFilterProvider.notifier).state =
                                  f,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverToBoxAdapter(
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: reduced ? 150 : 250),
                          switchInCurve: Curves.easeOutCubic,
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.topCenter,
                            children: [...previous, ?current],
                          ),
                          child: Column(
                            key: ValueKey('$filter-$sort-$unsyncedOnly-$query'),
                            children: [
                              if (!preview)
                                const EmptyCard(
                                  title: 'No responses yet',
                                  message:
                                      'Consent records appear here after field capture. '
                                      'Sync with project storage isn\'t connected yet.',
                                )
                              else if (visible.isEmpty)
                                EmptyCard(
                                  title: query.isNotEmpty
                                      ? 'No matches for “$query”'
                                      : 'No ${filter.label.toLowerCase()} responses',
                                  message: 'Try another filter or search.',
                                )
                              else
                                for (final (i, r) in visible.indexed)
                                  StaggerIn(
                                    index: i,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: ResponseCard(
                                        response: r,
                                        when: responseWhen(r.at, now),
                                        onOpen: () => context.push(
                                          '/responses/${r.code}',
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        const DashboardIcon('search', color: AppColors.subtle, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: dashboardText(15),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'Name or participant code',
              hintStyle: dashboardText(15, color: AppColors.subtle),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Figma Response/P-065: 76 dp white card, number avatar, name · code,
/// time · language · method, status badge and sync state.
class ResponseCard extends ConsumerWidget {
  const ResponseCard({
    super.key,
    required this.response,
    required this.when,
    required this.onOpen,
  });
  final ConsentResponse response;
  final String when;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final r = response;
    final method = r.status == ResponseStatus.declined ? 'declined' : r.method;
    return DashboardAction(
      label:
          '${r.name}, ${r.code}, ${r.status.label}, $when, ${r.synced ? 'synced' : 'waiting to sync'}',
      onPressed: onOpen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: institutionTint(ref, context),
                  shape: BoxShape.circle,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${r.number}',
                    style: dashboardText(
                      14,
                      color: primary,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.name}  ·  ${r.code}',
                      style: dashboardText(15, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$when · ${r.language} · $method',
                      style: dashboardText(12, color: AppColors.subtle),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(r.status),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: DashboardIcon(
                      r.synced ? 'responses/cloud' : 'responses/sync',
                      color: r.synced
                          ? AppColors.brand600
                          : const Color(0xFFC77700),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(responseSortProvider);
    final unsynced = ref.watch(unsyncedOnlyProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 19),
          Text(
            'Sort & filter',
            style: dashboardText(22, weight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            'Order',
            style: dashboardText(
              14,
              color: AppColors.muted,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          PillChips<ResponseSort>(
            padding: EdgeInsets.zero,
            values: ResponseSort.values,
            selected: sort,
            label: (s) =>
                s == ResponseSort.newest ? 'Newest first' : 'Oldest first',
            onSelected: (s) =>
                ref.read(responseSortProvider.notifier).state = s,
          ),
          const SizedBox(height: 12),
          AppToggleRow(
            title: 'Only waiting to sync',
            subtitle: 'Saved on this phone, not yet in project storage',
            value: unsynced,
            onChanged: (v) => ref.read(unsyncedOnlyProvider.notifier).state = v,
          ),
        ],
      ),
    );
  }
}
