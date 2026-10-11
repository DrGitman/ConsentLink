import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../institution/institution_preferences.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../projects/project_widgets.dart';
import 'capture_widgets.dart';
import 'field_capture_data.dart';

/// Figma 06.2 Participant reads consent (3:2948) with the "Read-aloud
/// highlight" animation (4:18979): the sentence being spoken is highlighted,
/// the rest dim, the highlight glides to the next sentence; tap any sentence
/// to replay it.
///
/// The recorded voice packs aren't connected yet, so playback is timed but
/// silent (about 0.42 s a word).
class ReadConsentScreen extends ConsumerStatefulWidget {
  const ReadConsentScreen({super.key});
  @override
  ConsumerState<ReadConsentScreen> createState() => _ReadConsentScreenState();
}

class _ReadConsentScreenState extends ConsumerState<ReadConsentScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _player = AnimationController(vsync: this)
    ..addListener(_tick)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) setState(() => _finished = true);
    });

  final _stackKey = GlobalKey();
  List<GlobalKey> _keys = [];
  List<Rect> _rects = [];
  List<double> _starts = [];
  int _current = 0;
  bool _finished = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load(ref.read(captureSessionProvider).section);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  ConsentReadSection get _section =>
      sampleReadSections[ref.read(captureSessionProvider).section];

  Duration get _total => _player.duration ?? Duration.zero;

  void _load(int index) {
    final section = sampleReadSections[index];
    _keys = [for (final _ in section.sentences) GlobalKey()];
    _rects = [];
    // Timing per sentence: words × 0.42 s + 0.6 s pause.
    var t = 0.0;
    _starts = [];
    for (final s in section.sentences) {
      _starts.add(t);
      t += s.split(' ').length * .42 + .6;
    }
    _starts = [for (final s in _starts) s / t];
    _ready = false;
    _player
      ..stop()
      ..duration = Duration(milliseconds: (t * 1000).round())
      ..value = 0;
    _current = 0;
    _finished = false;
    _ready = true;
    if (ref.read(captureSessionProvider).readAloud &&
        ref.read(fieldCapturePreviewProvider)) {
      _player.forward();
    }
  }

  void _tick() {
    if (!_ready || !mounted) return;
    var i = 0;
    for (var k = 0; k < _starts.length; k++) {
      if (_player.value >= _starts[k]) i = k;
    }
    if (i != _current) {
      setState(() => _current = i);
    } else {
      setState(() {});
    }
  }

  void _togglePlay() {
    if (_player.isAnimating) {
      _player.stop();
      setState(() {});
      return;
    }
    if (_finished) {
      _player.value = 0;
      _finished = false;
    }
    _player.forward();
    setState(() {});
  }

  void _replay(int index) {
    _finished = false;
    _player.value = _starts[index];
    _current = index;
    _player.forward();
    setState(() {});
  }

  void _back() {
    final session = ref.read(captureSessionProvider);
    if (session.section == 0) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/field-capture');
      }
      return;
    }
    ref.read(captureSessionProvider.notifier).goToSection(session.section - 1);
  }

  void _next() {
    final session = ref.read(captureSessionProvider);
    if (session.section < sampleReadSections.length - 1) {
      ref
          .read(captureSessionProvider.notifier)
          .goToSection(session.section + 1);
    } else {
      _player.stop();
      context.push('/field-capture/answer');
    }
  }

  void _measure() {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || !stack.hasSize) return;
    final rects = <Rect>[];
    for (final key in _keys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final offset = box.localToGlobal(Offset.zero, ancestor: stack);
      rects.add(offset & box.size);
    }
    if (!_sameRects(rects, _rects)) setState(() => _rects = rects);
  }

  static bool _sameRects(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i].top - b[i].top).abs() > .5 ||
          (a[i].height - b[i].height).abs() > .5) {
        return false;
      }
    }
    return true;
  }

  Future<void> _chooseLanguage() async {
    final controller = ref.read(captureSessionProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      sheetAnimationStyle: sheetMotion(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(captureSessionProvider).language;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language',
                  style: dashboardText(20, weight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (final language in captureLanguages)
                  DashboardAction(
                    label: language,
                    color: Colors.transparent,
                    radius: 16,
                    onPressed: () {
                      controller.setLanguage(language);
                      Navigator.pop(context);
                    },
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          DashboardIcon('form/globe', color: AppColors.muted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              language,
                              style: dashboardText(
                                16,
                                weight: language == current
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (language == current)
                            DashboardIcon(
                              'projects/check',
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      captureSessionProvider.select((s) => s.section),
      (_, next) => setState(() => _load(next)),
    );
    final session = ref.watch(captureSessionProvider);
    final preview = ref.watch(fieldCapturePreviewProvider);
    if (!preview) {
      return CaptureScaffold(
        onBack: () => context.pop(),
        footer: ConsentPillButton(
          label: 'Back',
          filled: false,
          onPressed: () => context.pop(),
        ),
        children: const [CaptureNotConnected()],
      );
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });

    final section = _section;
    final primary = Theme.of(context).colorScheme.primary;
    final initials = ref.watch(selectedInstitutionProvider)?.initials ?? 'NU';
    final playing = _player.isAnimating;
    final speaking = playing || (!_finished && _player.value > 0);
    final elapsed = _total * _player.value;
    final reduced = reduceMotion(context);
    final highlight = speaking && _rects.length == section.sentences.length
        ? _rects[_current]
        : null;

    return CaptureScaffold(
      onBack: _back,
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 24),
      footer: CaptureFooter(
        onBack: _back,
        nextLabel: 'Next',
        nextIcon: 'chevron_right',
        height: 60,
        onNext: _next,
      ),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                initials,
                style: dashboardText(
                  14,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Section ${session.section + 1} of ${sampleReadSections.length}',
                    style: dashboardText(
                      13,
                      color: AppColors.subtle,
                      weight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    section.title,
                    style: dashboardText(17, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            CaptureIconButton(
              label: session.largeText ? 'Large text, on' : 'Large text, off',
              onPressed: () => ref
                  .read(captureSessionProvider.notifier)
                  .setLargeText(!session.largeText),
              child: Text(
                'Aa',
                textScaler: TextScaler.noScaling,
                style: dashboardText(15, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            CaptureIconButton(
              label: 'Language, ${session.language}',
              icon: 'form/globe',
              onPressed: _chooseLanguage,
            ),
          ],
        ),
        const SizedBox(height: 8),
        CaptureProgress(
          value: (session.section + 1) / sampleReadSections.length,
          label: 'Consent progress',
        ),
        const SizedBox(height: 30),
        AnimatedSwitcher(
          duration: Duration(milliseconds: reduced ? 150 : 250),
          child: Semantics(
            key: ValueKey(session.section),
            header: true,
            child: Text(
              section.question,
              style: dashboardText(30, weight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 43),
        Stack(
          key: _stackKey,
          clipBehavior: Clip.none,
          children: [
            if (highlight != null)
              AnimatedPositioned(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                left: -8,
                right: -4,
                top: highlight.top - 7,
                height: highlight.height + 14,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1C2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < section.sentences.length; i++)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                      child: _Sentence(
                        key: _keys[i],
                        text: section.sentences[i],
                        active: speaking && i == _current,
                        dim: speaking && i != _current,
                        onTap: () => _replay(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _ListenCard(
          language: session.language,
          playing: playing,
          progress: _player.value,
          elapsed: elapsed,
          total: _total,
          onToggle: _togglePlay,
        ),
        const SizedBox(height: 20),
        ConsentPillButton(
          label: 'I have a question',
          icon: 'consent/info',
          filled: false,
          height: 56,
          onPressed: () {
            _player.stop();
            setState(() {});
            showProjectNotice(
              context,
              'Ask the researcher',
              'Show this screen to the researcher or ask your question now. '
                  'Your place is kept.',
            );
          },
        ),
      ],
    );
  }
}

class _Sentence extends StatelessWidget {
  const _Sentence({
    super.key,
    required this.text,
    required this.active,
    required this.dim,
    required this.onTap,
  });
  final String text;
  final bool active;
  final bool dim;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: text,
    hint: 'Replay this sentence',
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        opacity: dim ? .45 : 1,
        child: Text(
          text,
          style: dashboardText(
            20,
            weight: active ? FontWeight.w600 : FontWeight.w400,
          ).copyWith(height: 1.5),
        ),
      ),
    ),
  );
}

class _ListenCard extends ConsumerWidget {
  const _ListenCard({
    required this.language,
    required this.playing,
    required this.progress,
    required this.elapsed,
    required this.total,
    required this.onToggle,
  });
  final String language;
  final bool playing;
  final double progress;
  final Duration elapsed;
  final Duration total;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: institutionTint(ref, context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CaptureIconButton(
            label: playing ? 'Pause reading' : 'Read aloud',
            size: 60,
            fill: primary,
            onPressed: onToggle,
            child: DashboardIcon(
              playing ? 'capture/pause' : 'capture/play',
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playing
                      ? 'Reading aloud · $language'
                      : 'Read aloud · $language',
                  style: dashboardText(
                    16,
                    color: primary,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: primary.withValues(alpha: .12),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          heightFactor: 1,
                          child: ColoredBox(color: primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatClock(elapsed)} / ${formatClock(total)} · tap a sentence to replay',
                  style: dashboardText(
                    12,
                    color: primary,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
