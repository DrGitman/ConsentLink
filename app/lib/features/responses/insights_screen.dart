import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../projects/project_widgets.dart';
import 'export_sheet.dart';
import 'responses_data.dart';
import 'responses_widgets.dart';

/// Figma 07.3 Analytics (3:3440), the Insights tab. Bars grow in a stagger,
/// numbers count up and language bars fill whenever the period changes.
/// Tapping the recruitment card opens 07.1 Responses.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(insightsPreviewProvider);
    final period = ref.watch(insightsPeriodProvider);
    final responses = ref.watch(responsesProvider);
    final data = insightsFor(period);
    final reduced = MediaQuery.disableAnimationsOf(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          key: const PageStorageKey('insights-scroll'),
          padding: const EdgeInsets.fromLTRB(0, 15, 0, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Insights',
                          key: const ValueKey('page-title-insights'),
                          style: dashboardText(32, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                    ProjectCircleButton(
                      icon: 'projects/download',
                      label: 'Export responses',
                      onPressed: () => showExportSheet(
                        context,
                        subtitle:
                            'Water access & health · ${responses.length} records',
                        count: responses.length,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              PillChips<InsightsPeriod>(
                values: InsightsPeriod.values,
                selected: period,
                label: (p) => p.label,
                onSelected: (p) =>
                    ref.read(insightsPeriodProvider.notifier).state = p,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: !preview
                    ? const EmptyCard(
                        title: 'No insights yet',
                        message:
                            'Recruitment, agreement and understanding appear '
                            'here once responses sync. Sync isn\'t connected yet.',
                      )
                    : AnimatedSwitcher(
                        duration: Duration(milliseconds: reduced ? 150 : 250),
                        child: _Body(
                          key: ValueKey(period),
                          data: data,
                          total: responses.length,
                          waiting: responses.where((r) => !r.synced).length,
                          onResponses: () => context.go('/insights/responses'),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    super.key,
    required this.data,
    required this.total,
    required this.waiting,
    required this.onResponses,
  });
  final InsightsData data;
  final int total;
  final int waiting;
  final VoidCallback onResponses;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _GoalCard(data: data, onTap: onResponses),
      const SizedBox(height: 10),
      _ResponsesLink(total: total, waiting: waiting, onTap: onResponses),
      const SizedBox(height: 12),
      for (var row = 0; row < 2; row++) ...[
        if (row > 0) const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _KpiTile(kpi: data.kpis[row * 2])),
              const SizedBox(width: 8),
              Expanded(child: _KpiTile(kpi: data.kpis[row * 2 + 1])),
            ],
          ),
        ),
      ],
      const SizedBox(height: 22),
      _LanguageCard(languages: data.languages),
    ],
  );
}

/// Counts up from 0 in 600 ms (number part only, keeps the suffix).
class _CountUp extends StatelessWidget {
  const _CountUp(this.text, {required this.style});
  final String text;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^([+-]?)(\d+(?:\.\d+)?)(.*)$').firstMatch(text);
    if (match == null || MediaQuery.disableAnimationsOf(context)) {
      return Text(text, style: style);
    }
    final target = double.parse(match.group(2)!);
    final decimals = match.group(2)!.contains('.')
        ? match.group(2)!.split('.').last.length
        : 0;
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text(
          '${match.group(1)}${v.toStringAsFixed(decimals)}${match.group(3)}',
          style: style,
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.data, required this.onTap});
  final InsightsData data;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => DashboardAction(
    label:
        'Recruitment goal, ${data.consented} of ${data.goal}, ${data.onTrack ? 'on track' : 'behind'}. Open responses',
    onPressed: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Recruitment goal',
                  style: dashboardText(
                    14,
                    color: AppColors.subtle,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: ProjectBadge(
                  label: data.onTrack ? 'On track' : 'Behind',
                  fill: data.onTrack
                      ? AppColors.brand50
                      : const Color(0xFFFEF4E2),
                  ink: data.onTrack
                      ? AppColors.brandDark
                      : const Color(0xFF9A5B00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Shrinks rather than overflows with very large text.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _CountUp(
                  '${data.consented}',
                  style: dashboardText(44, weight: FontWeight.w600),
                ),
                const SizedBox(width: 7),
                Text(
                  '/ ${data.goal}',
                  style: dashboardText(
                    18,
                    color: AppColors.subtle,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(height: 80, child: _BarChart(values: data.bars)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                data.from,
                style: dashboardText(
                  11,
                  color: AppColors.subtle,
                  weight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                data.to,
                style: dashboardText(
                  11,
                  color: AppColors.subtle,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Figma bar chart: 7 dp bars, radius 3.26, colour from the soft institution
/// tint (short) to the institution colour (tall). Bars grow from the bottom
/// 20 ms apart.
class _BarChart extends StatelessWidget {
  const _BarChart({required this.values});
  final List<double> values;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final total = 500 + 20 * values.length;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduced ? 1.0 : 0.0, end: 1.0),
        duration: Duration(milliseconds: total),
        builder: (context, t, _) => CustomPaint(
          size: Size.infinite,
          painter: _BarsPainter(
            values: values,
            primary: primary,
            progress: t,
            totalMs: total,
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.primary,
    required this.progress,
    required this.totalMs,
  });
  final List<double> values;
  final Color primary;
  final double progress;
  final int totalMs;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    // 7 dp bars 4 dp apart at 30 days; wider bars when there are fewer.
    final gap = n > 20 ? size.width * 4 / 337 : 8.0;
    final width = math.min((size.width - gap * (n - 1)) / n, 28.0);
    final step = n == 1 ? 0.0 : (size.width - width) / (n - 1);
    final light = Color.lerp(Colors.white, primary, .45)!;
    final dark = Color.lerp(Colors.white, primary, .92)!;
    final elapsed = progress * totalMs;
    for (var i = 0; i < n; i++) {
      final local = ((elapsed - i * 20) / 500).clamp(0.0, 1.0);
      final grow = Curves.easeOutBack.transform(local);
      final v = values[i].clamp(0.0, 1.0);
      // Tallest bar is 72 of 80 dp, as in Figma.
      final h = math.max(4.0, size.height * .9 * v * grow);
      final x = i * step;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, width, h),
          const Radius.circular(3.26),
        ),
        Paint()
          ..color = Color.lerp(light, dark, ((v - .25) / .75).clamp(0.0, 1.0))!,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.progress != progress ||
      old.values != values ||
      old.primary != primary;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.kpi});
  final Kpi kpi;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 102),
    padding: const EdgeInsets.fromLTRB(14, 16, 12, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Semantics(
      container: true,
      label: '${kpi.label}: ${kpi.value}, change ${kpi.change}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CountUp(
            kpi.value,
            style: dashboardText(24, weight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          Text(kpi.label, style: dashboardText(12, color: AppColors.subtle)),
          const SizedBox(height: 3),
          ProjectBadge(
            label: kpi.change,
            fill: kpi.warning ? const Color(0xFFFEF4E2) : AppColors.brand50,
            ink: kpi.warning ? const Color(0xFF9A5B00) : AppColors.brandDark,
          ),
        ],
      ),
    ),
  );
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.languages});
  final List<(String, double)> languages;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final fills = [
      primary,
      Color.lerp(Colors.white, primary, .75)!,
      Color.lerp(Colors.white, primary, .45)!,
    ];
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Understanding by language',
              style: dashboardText(14, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 9),
          for (final (i, (name, value)) in languages.indexed)
            Semantics(
              label: '$name: ${(value * 100).round()}% understood',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        name,
                        style: dashboardText(
                          11,
                          color: AppColors.muted,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 6,
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: ColoredBox(color: AppColors.line),
                              ),
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: reduced ? value : 0.0,
                                  end: value,
                                ),
                                duration: Duration(milliseconds: 600 + 80 * i),
                                curve: Curves.easeOutCubic,
                                builder: (context, v, _) =>
                                    FractionallySizedBox(
                                      widthFactor: v,
                                      heightFactor: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: fills[i % fills.length],
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${(value * 100).round()}%',
                        style: dashboardText(11, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Call to action under the goal card: opens 07.1 Responses.
class _ResponsesLink extends ConsumerWidget {
  const _ResponsesLink({
    required this.total,
    required this.waiting,
    required this.onTap,
  });
  final int total;
  final int waiting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final detail = waiting == 0
        ? '$total records · all synced'
        : '$total records · $waiting waiting to sync';
    return DashboardAction(
      label: 'View all responses, $detail',
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                child: DashboardIcon('capture/users', color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'View all responses',
                      style: dashboardText(15, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: dashboardText(12, color: AppColors.subtle),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DashboardIcon('chevron_right', color: primary),
            ],
          ),
        ),
      ),
    );
  }
}
