import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../projects/project_widgets.dart';
import 'capture_widgets.dart';
import 'field_capture_data.dart';
import 'voice_input.dart';

/// Figma 06.3 Participant answers by voice (3:2993) with "Voice listening"
/// (4:22683): the mic breathes and its halo pulses while recording, the
/// waveform follows the voice level, and it stops instantly on tap.
class AnswerScreen extends ConsumerStatefulWidget {
  const AnswerScreen({super.key});
  @override
  ConsumerState<AnswerScreen> createState() => _AnswerScreenState();
}

enum _Voice { idle, listening, unavailable }

class _AnswerScreenState extends ConsumerState<AnswerScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  _Voice _voice = _Voice.idle;
  double _level = .15;
  late final VoiceInput _input;

  @override
  void initState() {
    super.initState();
    _input = ref.read(voiceInputProvider);
    _load(ref.read(captureSessionProvider).question);
    _focus.addListener(() => setState(() {}));
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (_voice == _Voice.listening) _input.stop();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  CaptureQuestion get _question =>
      sampleQuestions[ref.read(captureSessionProvider).question];

  void _load(int index) {
    final id = sampleQuestions[index].id;
    _text.text = ref.read(captureSessionProvider).answers[id] ?? '';
  }

  Future<void> _toggleVoice() async {
    final input = _input;
    if (_voice == _Voice.listening) {
      await input.stop();
      if (mounted) setState(() => _voice = _Voice.idle);
      return;
    }
    _focus.unfocus();
    setState(() {
      _voice = _Voice.listening;
      _level = .15;
    });
    final before = _text.text;
    final ok = await input.start(
      onText: (words) {
        if (!mounted) return;
        final joined = before.isEmpty || words.isEmpty
            ? words
            : '$before $words';
        _text.value = TextEditingValue(
          text: joined,
          selection: TextSelection.collapsed(offset: joined.length),
        );
      },
      onLevel: (level) {
        if (mounted && _voice == _Voice.listening) {
          setState(() => _level = level);
        }
      },
      onStopped: () {
        if (mounted && _voice == _Voice.listening) {
          setState(() => _voice = _Voice.idle);
        }
      },
    );
    if (!ok && mounted) setState(() => _voice = _Voice.unavailable);
  }

  Future<void> _typeInstead() async {
    if (_voice == _Voice.listening) {
      await _input.stop();
      if (mounted) setState(() => _voice = _Voice.idle);
    }
    if (mounted) _focus.requestFocus();
  }

  void _save() => ref
      .read(captureSessionProvider.notifier)
      .answer(_question.id, _text.text.trim());

  Future<void> _stopVoice() async {
    if (_voice == _Voice.listening) {
      await _input.stop();
      if (mounted) setState(() => _voice = _Voice.idle);
    }
  }

  Future<void> _back() async {
    await _stopVoice();
    if (!mounted) return;
    _save();
    final index = ref.read(captureSessionProvider).question;
    if (index == 0) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/field-capture/read');
      }
      return;
    }
    ref.read(captureSessionProvider.notifier).goToQuestion(index - 1);
  }

  Future<void> _next() async {
    await _stopVoice();
    if (!mounted) return;
    _save();
    _focus.unfocus();
    final index = ref.read(captureSessionProvider).question;
    if (index < sampleQuestions.length - 1) {
      ref.read(captureSessionProvider.notifier).goToQuestion(index + 1);
    } else {
      context.push('/field-capture/choices');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      captureSessionProvider.select((s) => s.question),
      (_, next) => _load(next),
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
    final question = sampleQuestions[session.question];
    final primary = Theme.of(context).colorScheme.primary;
    final active = _focus.hasFocus || _voice == _Voice.listening;
    final reduced = reduceMotion(context);

    return CaptureScaffold(
      onBack: _back,
      footer: CaptureFooter(
        onBack: _back,
        nextLabel: 'Next',
        nextIcon: 'chevron_right',
        height: 60,
        onNext: _text.text.trim().isEmpty ? null : _next,
      ),
      children: [
        CaptureProgress(
          value: (session.question + 1) / sampleQuestions.length,
          label: 'Questions progress',
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: Duration(milliseconds: reduced ? 150 : 250),
          child: CaptureHeading(
            key: ValueKey(session.question),
            eyebrow:
                'Question ${session.question + 1} of ${sampleQuestions.length}',
            title: question.question,
            helper: question.helper,
          ),
        ),
        const SizedBox(height: 14),
        AnimatedContainer(
          duration: Duration(milliseconds: reduced ? 0 : 200),
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active || _text.text.isNotEmpty ? primary : AppColors.line,
              width: active ? 2 : 1.5,
            ),
          ),
          child: TextField(
            controller: _text,
            focusNode: _focus,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: primary,
            style: dashboardText(24, weight: FontWeight.w500),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'Your answer',
              hintStyle: dashboardText(
                24,
                color: AppColors.subtle,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _ListeningCard(
          state: _voice,
          level: _level,
          onTap: _voice == _Voice.unavailable ? _typeInstead : _toggleVoice,
        ),
        const SizedBox(height: 24),
        ConsentPillButton(
          label: 'Type instead',
          icon: 'form/type',
          filled: false,
          height: 56,
          onPressed: _typeInstead,
        ),
      ],
    );
  }
}

class _ListeningCard extends ConsumerWidget {
  const _ListeningCard({
    required this.state,
    required this.level,
    required this.onTap,
  });
  final _Voice state;
  final double level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final tint = institutionTint(ref, context);
    final listening = state == _Voice.listening;
    final status = switch (state) {
      _Voice.listening => 'Listening… tap to stop',
      _Voice.idle => 'Tap the microphone to answer',
      _Voice.unavailable => 'Voice input isn’t available. Type instead.',
    };
    return Semantics(
      button: true,
      label: listening ? 'Stop listening' : 'Answer by voice',
      liveRegion: true,
      value: status,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 19),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FC),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              SizedBox.square(
                dimension: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PulseRing(
                      size: 100,
                      color: tint,
                      active: listening,
                      period: const Duration(milliseconds: 2400),
                      grow: 1.18,
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: tint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Breathe(
                      active: listening,
                      period: const Duration(milliseconds: 1200),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: state == _Voice.unavailable
                              ? AppColors.subtle
                              : primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const DashboardIcon(
                          'mic',
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 29),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: listening ? 1 : .35,
                child: Waveform(
                  color: primary,
                  level: listening ? level.clamp(.35, 1.0) : .15,
                  animate: listening,
                ),
              ),
              const SizedBox(height: 17),
              Text(
                status,
                textAlign: TextAlign.center,
                style: dashboardText(
                  14,
                  color: primary,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
