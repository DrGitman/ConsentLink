import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/dictation_sheet.dart';
import '../dashboard/dashboard_components.dart';
import '../minors/minors_data.dart';
import '../new_consent/consent_widgets.dart';
import '../preferences/accessibility_preferences.dart';
import 'capture_widgets.dart';
import '../settings/settings_data.dart';
import 'field_capture_data.dart';

/// Consent saved (Figma 06.6 background, 3:3182) and the optional feedback
/// pop-up, with "Consent saved → feedback" (4:22488): the check pops with a
/// soft burst, a warm thank-you, then the pop-up scales in over the scrim and
/// the chosen face bounces. Never shown to minors.
class DoneScreen extends ConsumerStatefulWidget {
  const DoneScreen({super.key});
  @override
  ConsumerState<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends ConsumerState<DoneScreen> {
  Timer? _timer;
  bool _showThanks = false;
  bool _feedbackSent = false;
  bool _feedbackOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduced = reduceMotion(context);
      _timer = Timer(Duration(milliseconds: reduced ? 0 : 350), () {
        if (!mounted) return;
        setState(() => _showThanks = true);
        _timer = Timer(Duration(milliseconds: reduced ? 300 : 1100), () {
          if (mounted) _askFeedback();
        });
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _askFeedback() async {
    if (!shouldAskFeedback(ref.read(captureParticipantProvider))) return;
    // Never shown to participants under 18 (08.4, 10.7).
    if (ref.read(minorSessionProvider).minorCapture) return;
    // Settings 08.4: on/off and how often.
    final count = ref.read(completedFormsProvider) + 1;
    ref.read(completedFormsProvider.notifier).state = count;
    if (!feedbackDue(
      ref.read(feedbackSettingsProvider),
      count,
      random: math.Random().nextDouble(),
    )) {
      return;
    }
    setState(() => _feedbackOpen = true);
    final sent = await showFeedbackPopup(context);
    if (!mounted) return;
    setState(() {
      _feedbackOpen = false;
      if (sent == true) _feedbackSent = true;
    });
  }

  void _handBack() {
    final id = ref.read(captureSessionProvider).projectId;
    context.go(id == null ? '/home' : '/projects/$id');
  }

  @override
  Widget build(BuildContext context) {
    final participant = ref.watch(captureParticipantProvider);
    final session = ref.watch(captureSessionProvider);
    final minor = ref.watch(minorSessionProvider).minorCapture;
    final name = minor ? null : participant?.firstName;
    final message = session.declined
        ? 'Your answer is saved. You are not part of the study, and that is OK.'
        : minor
        ? 'Your choice and your guardian’s consent are saved on this phone.'
        : 'Your consent is saved on this phone.';

    return PopScope(
      canPop: false,
      child: CaptureScaffold(
        scaleFooter: false,
        padding: const EdgeInsets.fromLTRB(20, 63, 20, 24),
        footer: IgnorePointer(
          ignoring: !_showThanks || _feedbackOpen,
          child: AnimatedOpacity(
            opacity: _showThanks && !_feedbackOpen ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: ConsentPillButton(
              label: 'Hand back to researcher',
              icon: 'capture/hand',
              height: 52,
              onPressed: _handBack,
            ),
          ),
        ),
        children: [
          const Center(child: _SavedBadge()),
          const SizedBox(height: 26),
          AnimatedOpacity(
            opacity: _showThanks ? 1 : 0,
            duration: Duration(milliseconds: reduceMotion(context) ? 150 : 400),
            curve: Curves.easeOutCubic,
            child: AnimatedSlide(
              offset: Offset(0, _showThanks || reduceMotion(context) ? 0 : .3),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: Column(
                children: [
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      name == null ? 'Thank you' : 'Thank you, $name',
                      textAlign: TextAlign.center,
                      style: dashboardText(26, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: dashboardText(16, color: AppColors.muted),
                  ),
                  if (_feedbackSent) ...[
                    const SizedBox(height: 8),
                    RiseIn(
                      child: Text(
                        'Thanks for your feedback.',
                        textAlign: TextAlign.center,
                        style: dashboardText(14, color: AppColors.subtle),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Please hand the phone back to the researcher.',
                    textAlign: TextAlign.center,
                    style: dashboardText(
                      14,
                      color: AppColors.subtle,
                      weight: FontWeight.w500,
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

/// The optional feedback pop-up (06.6). [preview] (from Settings 08.4)
/// shows it without saving anything.
Future<bool?> showFeedbackPopup(BuildContext context, {bool preview = false}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close feedback',
    barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
    transitionDuration: Duration(milliseconds: reduced ? 150 : 400),
    pageBuilder: (context, _, _) => _FeedbackDialog(preview: preview),
    transitionBuilder: (context, animation, _, child) {
      final fade = FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
      if (reduced) return fade;
      return ScaleTransition(
        scale: Tween(begin: .92, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          ),
        ),
        child: fade,
      );
    },
  );
}

/// 100 dp brand-50 circle, 64 dp brand check that pops, plus a soft burst.
class _SavedBadge extends StatelessWidget {
  const _SavedBadge();
  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotion(context);
    return Semantics(
      label: 'Saved',
      child: SizedBox.square(
        dimension: 100,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (!reduced)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  size: const Size.square(100),
                  painter: _BurstPainter(t),
                ),
              ),
            PopIn(
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppColors.brand50,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const DrawnCheck(size: 64),
          ],
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..color = AppColors.brand.withValues(alpha: (1 - t) * .7);
    for (var i = 0; i < 10; i++) {
      final a = i * 2 * math.pi / 10 - math.pi / 2;
      final r = 52 + 34 * t;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r,
        4 * (1 - t) + 1,
        paint,
      );
    }
    canvas.drawCircle(
      c,
      50 + 30 * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.brand.withValues(alpha: (1 - t) * .35),
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

class _FeedbackDialog extends ConsumerStatefulWidget {
  const _FeedbackDialog({this.preview = false});
  final bool preview;
  @override
  ConsumerState<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<_FeedbackDialog> {
  final _comment = TextEditingController();
  int? _rating;
  int _bounce = 0;
  final _tags = <String>{};

  @override
  void initState() {
    super.initState();
    _comment.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  bool get _hasInput =>
      _rating != null || _tags.isNotEmpty || _comment.text.trim().isNotEmpty;

  Future<void> _speak() async {
    final text = await showDictationSheet(context, fieldLabel: 'Feedback');
    if (text == null || text.trim().isEmpty || !mounted) return;
    final joined = _comment.text.trim().isEmpty
        ? text.trim()
        : '${_comment.text.trim()} ${text.trim()}';
    _comment.text = joined;
  }

  void _send() {
    if (widget.preview) {
      Navigator.pop(context, true);
      return;
    }
    final list = ref.read(captureFeedbackProvider);
    ref.read(captureFeedbackProvider.notifier).state = [
      ...list,
      CaptureFeedback(
        rating: _rating,
        tags: {..._tags},
        comment: _comment.text.trim(),
      ),
    ];
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final large = ref.watch(largerTouchTargetsProvider);
    // Figma modal: 350 wide, radius 32, content 24 from the sides, title 30
    // from the top, close × 24 dp at 22 from the top and 20 from the right.
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 17),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 36),
                          child: Semantics(
                            header: true,
                            child: Text(
                              'How was this for you?',
                              style: dashboardText(22, weight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Optional. Helps us make consent easier.',
                          style: dashboardText(14, color: AppColors.subtle),
                        ),
                        const SizedBox(height: 25),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < feedbackFaces.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: _Face(
                                  icon: feedbackFaces[i].$1,
                                  label: feedbackFaces[i].$2,
                                  selected: _rating == i,
                                  bounce: _rating == i ? _bounce : 0,
                                  onTap: () => setState(() {
                                    _rating = i;
                                    _bounce++;
                                  }),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 19),
                        Container(
                          constraints: const BoxConstraints(minHeight: 120),
                          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TextField(
                                controller: _comment,
                                minLines: 2,
                                maxLines: 5,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: dashboardText(14),
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText:
                                      'What could be better? (type or speak)',
                                  hintStyle: dashboardText(
                                    14,
                                    color: AppColors.subtle,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (ref
                                  .watch(feedbackSettingsProvider)
                                  .voiceComments)
                                CaptureIconButton(
                                  label: 'Speak feedback',
                                  icon: 'mic',
                                  size: 36,
                                  iconSize: 20,
                                  fill: AppColors.brand50,
                                  iconColor: AppColors.brand,
                                  onPressed: _speak,
                                ),
                            ],
                          ),
                        ),
                        // Chips are 38 dp in a 48 dp tap row, so the gaps
                        // around them are 5 dp smaller than in Figma (12/20).
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 4,
                          children: [
                            for (final tag in feedbackTags)
                              _Tag(
                                label: tag,
                                selected: _tags.contains(tag),
                                large: large,
                                onTap: () => setState(
                                  () => _tags.contains(tag)
                                      ? _tags.remove(tag)
                                      : _tags.add(tag),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        ConsentPillButton(
                          label: 'Send feedback',
                          height: 54,
                          onPressed: _hasInput ? _send : null,
                        ),
                        const SizedBox(height: 2),
                        Center(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(88, 48),
                              overlayColor: Colors.transparent,
                              splashFactory: NoSplash.splashFactory,
                            ),
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Skip',
                              style: dashboardText(
                                15,
                                color: AppColors.muted,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'Not linked to your consent answers.',
                          textAlign: TextAlign.center,
                          style: dashboardText(12, color: AppColors.subtle),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 8,
                    child: SizedBox.square(
                      dimension: 48,
                      child: DashboardAction(
                        label: 'Close',
                        radius: 24,
                        color: Colors.transparent,
                        onPressed: () => Navigator.pop(context, false),
                        child: const Center(
                          child: DashboardIcon(
                            'consent/x',
                            color: AppColors.subtle,
                            size: 24,
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
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.icon,
    required this.label,
    required this.selected,
    required this.bounce,
    required this.onTap,
  });
  final String icon;
  final String label;
  final bool selected;
  final int bounce;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotion(context);
    final circle = AnimatedContainer(
      duration: Duration(milliseconds: reduced ? 0 : 200),
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF7CCB6A) : AppColors.canvas,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: DashboardIcon(
        icon,
        color: selected ? Colors.white : AppColors.muted,
        size: 30,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: reduced || bounce == 0
                  ? circle
                  : TweenAnimationBuilder<double>(
                      key: ValueKey(bounce),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 450),
                      builder: (context, t, child) => Transform.scale(
                        scale: 1 + .18 * math.sin(t * math.pi) * (1 - t * .3),
                        child: child,
                      ),
                      child: circle,
                    ),
            ),
            const SizedBox(height: 8),
            // One line like Figma; shrinks rather than wraps on big text.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: dashboardText(
                  11,
                  color: selected ? AppColors.ink : AppColors.subtle,
                  weight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.selected,
    required this.large,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool large;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      child: DashboardAction(
        label: label,
        radius: 19,
        color: Colors.transparent,
        onPressed: onTap,
        // Min height and a flexible chip, so a long label wraps on large
        // text instead of overflowing the pop-up.
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: large ? 56 : 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AnimatedContainer(
                  duration: Duration(
                    milliseconds: reduceMotion(context) ? 0 : 200,
                  ),
                  constraints: BoxConstraints(minHeight: large ? 48 : 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? primary : Colors.white,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: selected ? primary : AppColors.line,
                    ),
                  ),
                  child: Text(
                    label,
                    style: dashboardText(
                      14,
                      color: selected ? Colors.white : AppColors.muted,
                      weight: FontWeight.w500,
                    ),
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
