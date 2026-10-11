import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/dictation_sheet.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../preferences/accessibility_preferences.dart';
import '../projects/project_widgets.dart';
import '../responses/responses_widgets.dart';
import 'template_data.dart';
import 'template_widgets.dart';

/// Figma 05.4 Describe a template (3:2714). Messages rise in; the assistant
/// shows typing dots, then its proposal. Every item is a checkbox: only the
/// ticked ones go into the template. The on-device model (P3) isn't
/// connected, so in the preview the replies are scripted.
class DescribeTemplateScreen extends ConsumerStatefulWidget {
  const DescribeTemplateScreen({super.key});
  @override
  ConsumerState<DescribeTemplateScreen> createState() =>
      _DescribeTemplateScreenState();
}

sealed class _Msg {
  const _Msg();
}

class _UserText extends _Msg {
  const _UserText(this.text);
  final String text;
}

class _UserVoice extends _Msg {
  const _UserVoice(this.seconds);
  final int seconds;
}

class _Proposal extends _Msg {
  _Proposal(this.items) : checked = {for (final i in items) i: true};
  final List<String> items;
  final Map<String, bool> checked;
}

const _firstRequest =
    'Our health consent forms need the ethics REC number in the footer, '
    'a witness signature line, and an Afrikaans column.';

const _firstProposal = [
  'Footer: “HREC ref: {ethics_no}” + page numbers',
  'Witness name, signature & date block',
  'Two columns: English | Afrikaans',
  'Keeps Arial 11 pt and 2.5 cm margins',
];

class _DescribeTemplateScreenState
    extends ConsumerState<DescribeTemplateScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final List<_Msg> _messages = ref.read(templatesPreviewProvider)
      ? [
          const _UserText(_firstRequest),
          const _UserVoice(8),
          _Proposal(_firstProposal),
        ]
      : [];
  bool _typing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/templates');

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: Duration(milliseconds: reduceMotion(context) ? 0 : 300),
      curve: Curves.easeOutCubic,
    );
  });

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty || _typing) return;
    if (!ref.read(templatesPreviewProvider)) {
      showProjectNotice(
        context,
        'Template assistant',
        'The on-device model isn\'t connected yet.',
      );
      return;
    }
    final last = _messages.whereType<_Proposal>().lastOrNull;
    setState(() {
      _messages.add(_UserText(text));
      _typing = true;
      _text.clear();
    });
    _toBottom();
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _messages.add(
          _Proposal([
            if (last != null)
              for (final i in last.items)
                if (last.checked[i] ?? false) i,
            'Added: $text',
          ]),
        );
      });
      _toBottom();
    });
  }

  Future<void> _speak() async {
    final text = await showDictationSheet(
      context,
      fieldLabel: 'Describe a template',
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    _text.text = text.trim();
  }

  Future<void> _create(_Proposal p) async {
    final items = [
      for (final i in p.items)
        if (p.checked[i] ?? false) i,
    ];
    final result = await showSaveTemplateSheet(
      context,
      suggestedName: 'Health consent + witness',
    );
    if (result == null || !mounted) return;
    final footer = items.where((i) => i.startsWith('Footer')).firstOrNull;
    final twoColumns = items.any((i) => i.startsWith('Two columns'));
    final t = ref
        .read(templateLibraryProvider.notifier)
        .add(
          StudioTemplate(
            id: 'described-${DateTime.now().microsecondsSinceEpoch}',
            name: result.$1,
            owner: 'You',
            meta: 'You · edited today',
            access: result.$2,
            mine: true,
            rules: [
              const TemplateRule(
                key: 'font',
                title: 'Font',
                value: 'Arial 11 pt',
                icon: 'form/type',
              ),
              const TemplateRule(
                key: 'margins',
                title: 'Margins',
                value: '2.5 cm',
                icon: 'layers',
              ),
              TemplateRule(
                key: 'footer',
                title: 'Footer',
                value: footer == null ? 'Page numbers' : 'REC no. + page',
                icon: 'responses/file',
              ),
              TemplateRule(
                key: 'languages',
                title: 'Languages',
                value: twoColumns ? 'EN | AF' : 'EN',
                icon: 'form/globe',
              ),
            ],
          ),
        );
    if (!mounted) return;
    showOverlayToast(
      context,
      kind: AppToastKind.success,
      title: 'Template created',
      subtitle: '${items.length} rules · ${t.name}',
    );
    context.go('/templates/view/${t.id}');
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(templatesPreviewProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 9, 20, 0),
                  child: ConsentTopBar(
                    leading: AppBackButton(onPressed: _back),
                    title: 'Template assistant',
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    children: [
                      Center(
                        child: ProjectBadge(
                          label: 'On-device · you approve every change',
                          icon: 'sparkle',
                          fill: const Color(0xFFEDEEFF),
                          ink: const Color(0xFF4B4FD8),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (!preview)
                        const EmptyCard(
                          title: 'Describe the template you need',
                          message:
                              'The template assistant runs on this phone. The '
                              'on-device model isn\'t connected yet.',
                        ),
                      for (final (i, m) in _messages.indexed) ...[
                        if (i > 0) const SizedBox(height: 12),
                        StaggerIn(
                          index: i,
                          child: switch (m) {
                            _UserText(:final text) => _UserBubble(text: text),
                            _UserVoice(:final seconds) => _VoiceBubble(
                              seconds: seconds,
                            ),
                            final _Proposal p => _ProposalCard(
                              proposal: p,
                              onToggle: (item) => setState(
                                () => p.checked[item] =
                                    !(p.checked[item] ?? false),
                              ),
                              onPreview: () => showProjectNotice(
                                context,
                                'Preview PDF',
                                'A PDF preview comes with export (P2). The '
                                    'template keeps the ticked rules.',
                              ),
                              onCreate: () => _create(p),
                            ),
                          },
                        ),
                      ],
                      if (_typing) ...[
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: _TypingDots(),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _Composer(
                    controller: _text,
                    enabled: preview,
                    onSend: _send,
                    onSpeak: _speak,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 290),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(6),
            bottomLeft: Radius.circular(20),
          ),
        ),
        child: Text(
          text,
          style: dashboardText(14, color: Colors.white).copyWith(height: 1.43),
        ),
      ),
    ),
  );
}

/// Voice note bubble: play, waveform that fills while playing, length.
class _VoiceBubble extends StatefulWidget {
  const _VoiceBubble({required this.seconds});
  final int seconds;
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble>
    with SingleTickerProviderStateMixin {
  static const _bars = [
    6, 12, 8, 16, 10, 18, 6, 14, 9, 12, 7, 15, 10, 6, 13, 8, 16, 9, 6, 11, //
    8, 5,
  ];
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.seconds),
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_c.isAnimating) {
      _c.stop();
    } else {
      if (_c.isCompleted) _c.value = 0;
      _c.forward();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final played = (_c.value * _bars.length).floor();
    final remaining = Duration(
      milliseconds: ((1 - _c.value) * widget.seconds * 1000).round(),
    );
    final shown = _c.isAnimating
        ? remaining
        : Duration(seconds: widget.seconds);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
          decoration: BoxDecoration(
            color: primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(6),
              bottomLeft: Radius.circular(24),
            ),
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: _c.isAnimating ? 'Pause voice note' : 'Play voice note',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color.lerp(primary, Colors.white, .08),
                      shape: BoxShape.circle,
                    ),
                    child: DashboardIcon(
                      _c.isAnimating ? 'capture/pause' : 'capture/play',
                      color: Colors.white,
                      size: _c.isAnimating ? 20 : 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 20,
                    child: Row(
                      children: [
                        for (var i = 0; i < _bars.length; i++) ...[
                          if (i > 0) const Spacer(),
                          Container(
                            width: 4,
                            height: _bars[i].toDouble(),
                            decoration: BoxDecoration(
                              color: _c.value > 0 && i < played
                                  ? Colors.white
                                  : const Color(0xFFC9D0EA),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatSeconds(shown),
                style: dashboardText(
                  12,
                  color: const Color(0xFFC9D0EA),
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatSeconds(Duration d) =>
    '${d.inSeconds ~/ 60}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.onToggle,
    required this.onPreview,
    required this.onCreate,
  });
  final _Proposal proposal;
  final ValueChanged<String> onToggle;
  final VoidCallback onPreview;
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final any = proposal.checked.values.any((v) => v);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Here’s the template I’d build:',
                style: dashboardText(14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              for (final item in proposal.items)
                _CheckItem(
                  label: item,
                  checked: proposal.checked[item] ?? false,
                  onTap: () => onToggle(item),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SmallPill(
                      label: 'Preview PDF',
                      icon: 'consent/eye',
                      fill: Color.lerp(Colors.white, primary, .11)!,
                      ink: primary,
                      onTap: onPreview,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SmallPill(
                      label: 'Create template',
                      fill: any ? primary : primary.withValues(alpha: .35),
                      ink: Colors.white,
                      onTap: any ? onCreate : null,
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

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.label,
    required this.checked,
    required this.onTap,
  });
  final String label;
  final bool checked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final duration = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Semantics(
      checked: checked,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: duration,
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: checked ? primary : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: checked ? primary : const Color(0xFFB9C0BD),
                      width: 1.5,
                    ),
                  ),
                  child: AnimatedScale(
                    duration: duration,
                    curve: Curves.easeOutBack,
                    scale: checked ? 1 : 0,
                    child: const DashboardIcon(
                      'projects/check',
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AnimatedDefaultTextStyle(
                      duration: duration,
                      style:
                          dashboardText(
                            13,
                            color: checked ? AppColors.muted : AppColors.subtle,
                          ).copyWith(
                            decoration: checked
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                      child: Text(label),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallPill extends ConsumerWidget {
  const _SmallPill({
    required this.label,
    required this.fill,
    required this.ink,
    required this.onTap,
    this.icon,
  });
  final String label;
  final String? icon;
  final Color fill;
  final Color ink;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    // 30 dp pill in a 48 dp tap area (Figma 05.4 buttons).
    final pill = Container(
      constraints: BoxConstraints(minHeight: large ? 44 : 30),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(15),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              DashboardIcon(icon!, color: ink, size: 18),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: dashboardText(13, color: ink, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(child: pill),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!reduceMotion(context) && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Assistant is writing',
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
          bottomLeft: Radius.circular(6),
        ),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Transform.translate(
                offset: Offset(
                  0,
                  -3 *
                      math.max(0, math.sin((_c.value - i * .15) * 2 * math.pi)),
                ),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.subtle,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Composer extends ConsumerWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.onSpeak,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onSpeak;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasText = controller.text.trim().isNotEmpty;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(22, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: dashboardText(15),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Type or hold to speak…',
                hintStyle: dashboardText(15, color: AppColors.subtle),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: hasText ? 'Send' : 'Speak',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: enabled ? (hasText ? onSend : onSpeak) : null,
              onLongPress: enabled ? onSpeak : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: enabled ? primary : primary.withValues(alpha: .35),
                  shape: BoxShape.circle,
                ),
                child: AnimatedSwitcher(
                  duration: Duration(
                    milliseconds: reduceMotion(context) ? 0 : 150,
                  ),
                  child: DashboardIcon(
                    hasText ? 'consent/upload' : 'mic',
                    key: ValueKey(hasText),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
