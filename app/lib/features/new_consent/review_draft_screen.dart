import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../dashboard/dashboard_components.dart';
import '../institution/researcher_details_screen.dart';
import '../preferences/accessibility_preferences.dart';
import '../projects/project_widgets.dart';
import 'consent_draft_data.dart';
import 'consent_widgets.dart';
import 'why_sheet.dart';

const _aiFill = Color(0xFFEDEEFF);
const _aiInk = Color(0xFF4B4FD8);
const _warnFill = Color(0xFFFEF4E2);
const _warnInk = Color(0xFF7A4700);

/// Name recorded with each approval (approvedBy in the Section contract).
String approverName(WidgetRef ref) {
  final preview = ref.read(newConsentPreviewProvider);
  final first = ref.read(researcherDraftProvider).first.trim();
  return first.isNotEmpty ? first : (preview ? 'Ndapewa' : 'you');
}

/// Figma Screen Artboards 04.3 Review AI draft.
class ReviewDraftScreen extends ConsumerStatefulWidget {
  const ReviewDraftScreen({super.key});
  @override
  ConsumerState<ReviewDraftScreen> createState() => _ReviewDraftScreenState();
}

class _ReviewDraftScreenState extends ConsumerState<ReviewDraftScreen> {
  bool _showAll = false;
  String? _flash;

  static const _visibleCount = 4;
  DraftSection? _toast;
  int _toastKey = 0;
  Timer? _toastTimer;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void approve(DraftSection section) {
    ref
        .read(consentDraftProvider.notifier)
        .approve(section.key, approverName(ref));
    setState(() {
      _flash = section.key;
      _toast = section;
      _toastKey++;
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _undo() {
    final section = _toast;
    if (section == null) return;
    _toastTimer?.cancel();
    ref.read(consentDraftProvider.notifier).undo(section.key);
    setState(() => _toast = null);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _why(DraftSection section) => showWhySheet(
    context,
    sectionKey: section.key,
    onApprove: () => approve(section),
  );

  Future<void> _edit(DraftSection section) async {
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      sheetAnimationStyle: sheetMotion(context),
      builder: (context) => _EditSheet(section: section),
    );
    if (!mounted || saved == null || saved.isEmpty || saved == section.text) {
      return;
    }
    ref
        .read(consentDraftProvider.notifier)
        .edit(section.key, saved, approverName(ref));
    setState(() => _flash = section.key);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(consentDraftProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final large = ref.watch(largerTouchTargetsProvider);
    final sections = draft.sections;
    final added = sections.where((s) => s.key == 'contacts_ethics').toList();
    final base = sections.where((s) => s.key != 'contacts_ethics').toList();
    final shown = [
      ...base.take(_showAll ? base.length : _visibleCount),
      ...added,
    ];
    final hidden = base.length - _visibleCount;
    // Second language of the sample project (Figma 04.3).
    const otherLanguage = 'Otjiherero';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 88),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ConsentTopBar(
                                leading: AppBackButton(onPressed: _back),
                                title: 'Review draft',
                                trailing: ProjectCircleButton(
                                  icon: 'consent/preview_doc',
                                  label: 'Preview as participant',
                                  onPressed: () => showProjectNotice(
                                    context,
                                    'Preview as participant',
                                    'The participant view comes with the Form builder (04.5).',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final language in [
                                    'English',
                                    otherLanguage,
                                  ])
                                    _LanguageChip(
                                      label: language,
                                      selected: draft.language == language,
                                      large: large,
                                      onTap: () => ref
                                          .read(consentDraftProvider.notifier)
                                          .setLanguage(language),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              AnimatedSwitcher(
                                duration: Duration(
                                  milliseconds: reduceMotion(context)
                                      ? 150
                                      : 250,
                                ),
                                child: draft.missingElement
                                    ? _Checklist(
                                        key: const ValueKey('missing'),
                                        missing: draft.missingKeys,
                                        onTap: ref
                                            .read(consentDraftProvider.notifier)
                                            .addMissingElement,
                                      )
                                    : const _ChecklistDone(
                                        key: ValueKey('done'),
                                      ),
                              ),
                              if (draft.language != 'English') ...[
                                const SizedBox(height: 10),
                                _TranslationNote(language: draft.language),
                              ],
                              const SizedBox(height: 10),
                              AnimatedSize(
                                duration: reduceMotion(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: Column(
                                  children: [
                                    for (final section in shown)
                                      Padding(
                                        key: ValueKey(section.key),
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: RiseIn(
                                          child: _SectionCard(
                                            section: section,
                                            flash: _flash == section.key,
                                            onFlashDone: () =>
                                                setState(() => _flash = null),
                                            onWhy: () => _why(section),
                                            onEdit: () => _edit(section),
                                            onApprove: () => approve(section),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (hidden > 0)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(48, 48),
                                    overlayColor: Colors.transparent,
                                    splashFactory: NoSplash.splashFactory,
                                  ),
                                  onPressed: () =>
                                      setState(() => _showAll = !_showAll),
                                  child: Text(
                                    _showAll
                                        ? 'Show fewer sections'
                                        : '+ $hidden more sections',
                                    style: dashboardText(
                                      13,
                                      color: primary,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // App-styled "approved" toast with Undo (Figma Approve
                      // section: Undo for 5 s).
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 12,
                        child: AnimatedSwitcher(
                          duration: Duration(
                            milliseconds: reduceMotion(context) ? 150 : 250,
                          ),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, a) =>
                              appToastTransition(context, child, a),
                          child: _toast == null
                              ? const SizedBox(key: ValueKey('no-toast'))
                              : AppToast(
                                  key: ValueKey('toast-$_toastKey'),
                                  kind: AppToastKind.success,
                                  title: 'Section approved',
                                  subtitle: _toast!.title,
                                  actionLabel: 'Undo',
                                  onAction: _undo,
                                  countdown: const Duration(seconds: 5),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                _Footer(
                  done: draft.doneCount,
                  allApproved: draft.allApproved,
                  onContinue: () => context.push('/new-consent/form'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

AnimationStyle sheetMotion(BuildContext context) => reduceMotion(context)
    ? const AnimationStyle(duration: Duration(milliseconds: 150))
    : const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
      );

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
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
        radius: 30,
        color: Colors.transparent,
        onPressed: onTap,
        child: AnimatedContainer(
          duration: reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          constraints: BoxConstraints(minHeight: large ? 56 : 38),
          padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: selected ? primary : AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DashboardIcon(
                'consent/globe',
                size: 20,
                color: selected ? Colors.white : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: dashboardText(
                    14,
                    color: selected ? Colors.white : AppColors.muted,
                    weight: FontWeight.w500,
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

class _Checklist extends StatelessWidget {
  const _Checklist({super.key, required this.missing, required this.onTap});
  final List<String> missing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final found = requiredElementCount - missing.length;
    final names = missing.map((k) => elementLabels[k] ?? k).join(', ');
    return DashboardAction(
      label:
          '$found of $requiredElementCount required elements found. Missing: $names.',
      color: _warnFill,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DashboardIcon('consent/alert', color: _warnInk),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$found of $requiredElementCount required elements found',
                    style: dashboardText(
                      15,
                      color: _warnInk,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Missing: $names. Tap to add.',
                    style: dashboardText(12, color: _warnInk),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistDone extends StatelessWidget {
  const _ChecklistDone({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: AppColors.brand50,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        const DashboardIcon(
          'projects/check',
          color: AppColors.brandDark,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'All $requiredElementCount required elements found',
            style: dashboardText(
              15,
              color: AppColors.brandDark,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TranslationNote extends StatelessWidget {
  const _TranslationNote({required this.language});
  final String language;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _aiFill,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      'The $language version is drafted on this phone and must be checked by a fluent reviewer. Translation is not generated in this preview, so the English text is shown.',
      style: dashboardText(12, color: const Color(0xFF2E318F)),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.flash,
    required this.onFlashDone,
    required this.onWhy,
    required this.onEdit,
    required this.onApprove,
  });
  final DraftSection section;
  final bool flash;
  final VoidCallback onFlashDone;
  final VoidCallback onWhy;
  final VoidCallback onEdit;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotion(context);
    final open = section.status == SectionStatus.aiDraft;
    final badge = switch (section.status) {
      SectionStatus.approved => const ProjectBadge(
        key: ValueKey('approved'),
        icon: 'projects/check',
        label: 'Approved',
        fill: AppColors.brand50,
        ink: AppColors.brandDark,
      ),
      SectionStatus.edited => const ProjectBadge(
        key: ValueKey('edited'),
        icon: 'consent/pen',
        label: 'Edited',
        fill: AppColors.canvas,
        ink: AppColors.muted,
      ),
      SectionStatus.aiDraft => const ProjectBadge(
        key: ValueKey('ai'),
        icon: 'sparkle',
        label: 'AI draft · review',
        fill: _aiFill,
        ink: _aiInk,
      ),
    };
    // Figma "Approve section": border flashes green once (600 ms).
    return TweenAnimationBuilder<double>(
      key: ValueKey('${section.key}-${section.status}-$flash'),
      tween: Tween(begin: flash && !reduced ? 1 : 0, end: 0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeIn,
      onEnd: flash ? onFlashDone : null,
      builder: (context, glow, child) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.brand.withValues(alpha: glow),
            width: 2,
          ),
        ),
        child: child,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, open ? 6 : 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      section.title,
                      style: dashboardText(15, weight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Badge morphs AI draft → Approved. Natural width, pinned
                // to the right edge; capped so a long badge can still wrap.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * .45,
                  ),
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: reduced ? 150 : 250),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: reduced
                          ? child
                          : ScaleTransition(
                              scale: Tween(begin: .85, end: 1.0).animate(a),
                              child: child,
                            ),
                    ),
                    child: badge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              open
                  ? section.sourceLabel
                  : section.status == SectionStatus.edited
                  ? 'You edited this'
                  : 'Reading level: ${section.readingLevel}',
              style: dashboardText(12, color: AppColors.subtle),
            ),
            AnimatedSize(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: open
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          section.text,
                          style: dashboardText(
                            13,
                            color: AppColors.muted,
                          ).copyWith(height: 1.45),
                        ),
                        // Figma: 13 dp gap to the 32 dp buttons; their 48 dp
                        // touch target adds 8 dp above and below.
                        const SizedBox(height: 5),
                        _ActionRow(
                          primary: Theme.of(context).colorScheme.primary,
                          onWhy: onWhy,
                          onEdit: onEdit,
                          onApprove: onApprove,
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallAction extends ConsumerWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.fill,
    required this.ink,
    required this.onTap,
    this.wide = false,
    this.expand = false,
  });
  final String icon;
  final String label;
  final Color fill;
  final Color ink;
  final VoidCallback onTap;
  final bool wide;
  final bool expand;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    // 32 dp pill as in Figma inside a 48 dp (64 dp large) touch target.
    return SizedBox(
      height: large ? 64 : 48,
      child: Center(
        widthFactor: expand ? null : 1,
        child: DashboardAction(
          label: label,
          radius: 16,
          color: fill,
          onPressed: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: expand ? double.infinity : (wide ? 122 : 92),
              minHeight: large ? 48 : 32,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              // In the fixed 92/92/122 row a slightly larger font shrinks
              // the label a touch instead of overflowing; bigger text
              // switches the row to Wrap (see _ActionRow).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DashboardIcon(icon, color: ink, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: dashboardText(
                        13,
                        color: ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.done,
    required this.allApproved,
    required this.onContinue,
  });
  final int done;
  final bool allApproved;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        18 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .55,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    '$done of $requiredElementCount approved',
                    style: dashboardText(
                      13,
                      color: AppColors.muted,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: done / requiredElementCount),
                  duration: reduceMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      color: primary,
                      backgroundColor: AppColors.line,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConsentPillButton(
            label: allApproved
                ? 'Continue to form builder'
                : 'Approve remaining to continue',
            height: 52,
            onPressed: allApproved ? onContinue : null,
          ),
        ],
      ),
    );
  }
}

/// Owns its text controller so it is only disposed after the sheet has
/// finished its closing animation.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.section});
  final DraftSection section;
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _controller = TextEditingController(text: widget.section.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit “${widget.section.title}”',
              style: dashboardText(20, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Keep it short and plain (Grade 6). Your edit is logged.',
              style: dashboardText(13, color: AppColors.subtle),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Section text'),
            ),
            const SizedBox(height: 16),
            ConsentPillButton(
              icon: 'projects/check',
              label: 'Save',
              height: 52,
              onPressed: () => Navigator.pop(context, _controller.text.trim()),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Why? · Edit · Approve. One row split 92 : 92 : 122 like Figma 04.3; wraps
/// onto more lines only when large text would squash the labels.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.primary,
    required this.onWhy,
    required this.onEdit,
    required this.onApprove,
  });
  final Color primary;
  final VoidCallback onWhy;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  @override
  Widget build(BuildContext context) {
    final wrap = MediaQuery.textScalerOf(context).scale(13) > 15;
    final buttons = [
      (
        92,
        _SmallAction(
          icon: 'consent/info',
          label: 'Why?',
          fill: Color.lerp(Colors.white, primary, .11)!,
          ink: primary,
          onTap: onWhy,
          expand: !wrap,
        ),
      ),
      (
        92,
        _SmallAction(
          icon: 'consent/pen',
          label: 'Edit',
          fill: AppColors.canvas,
          ink: AppColors.muted,
          onTap: onEdit,
          expand: !wrap,
        ),
      ),
      (
        122,
        _SmallAction(
          icon: 'projects/check',
          label: 'Approve',
          fill: primary,
          ink: Colors.white,
          onTap: onApprove,
          wide: true,
          expand: !wrap,
        ),
      ),
    ];
    if (wrap) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [for (final (_, b) in buttons) b],
      );
    }
    return Row(
      children: [
        for (final (i, (flex, b)) in buttons.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(flex: flex, child: b),
        ],
      ],
    );
  }
}
