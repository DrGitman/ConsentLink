import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_theme.dart';
import 'dashboard_components.dart';

/// States of the dashboard sync bar (Figma Screen Artboards 03.1 and the
/// "Offline / back online banner" frame on the Animations page).
enum SyncBannerPhase { hidden, offline, syncing, synced }

const _offlineFill = Color(0xFFFEF4E2);
const _offlineInk = Color(0xFF9A5B00);

/// The sync bar itself. It only draws a phase; whoever owns real sync state
/// (later the data layer, for now [DashboardSyncPreview]) decides the phase.
///
/// Motion follows the Figma motion tokens:
/// * drop in / fold away: 300 ms easeOutCubic, content below eases with it
/// * colour to green: slow, 400 ms easeInOutCubic
/// * icon and text swaps: base, 250 ms easeOutCubic
/// * spinner: 1 s linear loop while syncing
/// * check: emphasis, 500 ms easeOutBack pop
/// With Reduce motion everything becomes a 150 ms fade and nothing loops.
class SyncBanner extends StatefulWidget {
  const SyncBanner({
    super.key,
    required this.phase,
    required this.pending,
    required this.large,
    this.onPressed,
  });
  final SyncBannerPhase phase;
  final int pending;
  final bool large;
  final VoidCallback? onPressed;

  @override
  State<SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends State<SyncBanner>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSpinner();
  }

  @override
  void didUpdateWidget(SyncBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateSpinner();
  }

  void _updateSpinner() {
    final spin =
        widget.phase == SyncBannerPhase.syncing &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.of(context);
    if (spin && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!spin && _spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    const reducedFade = Duration(milliseconds: 150);
    final layout = reduced ? reducedFade : const Duration(milliseconds: 300);
    final swap = reduced ? reducedFade : const Duration(milliseconds: 250);
    final tint = reduced ? reducedFade : const Duration(milliseconds: 400);
    final visible = widget.phase != SyncBannerPhase.hidden;

    return AnimatedSwitcher(
      duration: layout,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final fade = FadeTransition(opacity: animation, child: child);
        if (reduced) return fade;
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -.35),
              end: Offset.zero,
            ).animate(animation),
            child: fade,
          ),
        );
      },
      child: visible
          ? Padding(
              key: const ValueKey('sync-banner'),
              padding: const EdgeInsets.only(bottom: 14),
              child: _bar(context, swap, tint, reduced),
            )
          : const SizedBox(
              key: ValueKey('sync-banner-hidden'),
              width: double.infinity,
            ),
    );
  }

  Widget _bar(
    BuildContext context,
    Duration swap,
    Duration tint,
    bool reduced,
  ) {
    final phase = widget.phase;
    final offline = phase == SyncBannerPhase.offline;
    final ink = offline ? _offlineInk : AppColors.brandDark;
    final text = switch (phase) {
      SyncBannerPhase.syncing => 'Back online · syncing ${widget.pending}…',
      SyncBannerPhase.synced => 'All synced · just now',
      _ =>
        'Offline · ${widget.pending} '
            '${widget.pending == 1 ? 'consent' : 'consents'} waiting to sync',
    };
    final Widget icon = switch (phase) {
      SyncBannerPhase.syncing => RotationTransition(
        key: const ValueKey('sync-icon-syncing'),
        turns: _spin,
        child: const DashboardIcon('sync', color: AppColors.brandDark),
      ),
      SyncBannerPhase.synced => TweenAnimationBuilder<double>(
        key: const ValueKey('sync-icon-done'),
        tween: Tween(begin: reduced ? 1 : .6, end: 1),
        duration: reduced ? Duration.zero : const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: SvgPicture.asset(
          'assets/icons/dashboard/sync_done.svg',
          width: 22,
          height: 22,
          excludeFromSemantics: true,
        ),
      ),
      _ => const DashboardIcon(
        'wifi_off',
        key: ValueKey('sync-icon-offline'),
        color: _offlineInk,
      ),
    };

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: offline ? _offlineFill : AppColors.brand50),
      duration: tint,
      curve: Curves.easeInOutCubic,
      builder: (context, fill, child) => DashboardAction(
        onPressed: widget.onPressed ?? () {},
        label: text,
        radius: 22,
        color: fill ?? _offlineFill,
        child: child!,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: widget.large ? 72 : 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 22,
                child: AnimatedSwitcher(
                  duration: swap,
                  switchInCurve: Curves.easeOutCubic,
                  child: icon,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: AnimatedSwitcher(
                    duration: swap,
                    switchInCurve: Curves.easeOutCubic,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, ?current],
                    ),
                    child: Text(
                      text,
                      key: ValueKey(phase),
                      style: dashboardText(
                        14,
                        color: ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: offline ? 1 : 0,
                duration: swap,
                child: const DashboardIcon(
                  'chevron_right',
                  size: 20,
                  color: _offlineInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview-only driver for [SyncBanner] (DASHBOARD_PREVIEW=true).
/// Replays Figma's four-second sequence with sample data. It never uploads
/// or reads real records.
///
/// * On entry the offline bar drops in after 0.3 s (Figma 0.3–0.6 s).
/// * Tap it to simulate reconnecting: green + syncing, then "All synced"
///   after 0.75 s, then it folds away 0.45 s later (Figma 1.9–3.65 s).
/// * 2 s after folding, the offline bar drops in again so it can be replayed.
class DashboardSyncPreview extends StatefulWidget {
  const DashboardSyncPreview({super.key, required this.large});
  final bool large;
  @override
  State<DashboardSyncPreview> createState() => _DashboardSyncPreviewState();
}

class _DashboardSyncPreviewState extends State<DashboardSyncPreview> {
  var _phase = SyncBannerPhase.hidden;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _after(const Duration(milliseconds: 300), SyncBannerPhase.offline);
  }

  void _after(Duration delay, SyncBannerPhase phase) {
    _timers.add(
      Timer(delay, () {
        if (mounted) setState(() => _phase = phase);
      }),
    );
  }

  void _reconnect() {
    if (_phase != SyncBannerPhase.offline) return;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    setState(() => _phase = SyncBannerPhase.syncing);
    _after(const Duration(milliseconds: 750), SyncBannerPhase.synced);
    _after(const Duration(milliseconds: 1200), SyncBannerPhase.hidden);
    _after(const Duration(milliseconds: 3200), SyncBannerPhase.offline);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SyncBanner(
    phase: _phase,
    pending: 3,
    large: widget.large,
    onPressed: _reconnect,
  );
}
