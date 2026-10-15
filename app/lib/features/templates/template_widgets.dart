import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toggle.dart';
import '../../core/widgets/dictation_sheet.dart';
import '../dashboard/dashboard_components.dart';
import '../institution/institution_preferences.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../preferences/accessibility_preferences.dart';
import '../projects/project_widgets.dart';
import '../responses/responses_widgets.dart' show WhiteCard;
import 'template_data.dart';

/// "NUST" (or the chosen institution's short name).
String institutionLabel(WidgetRef ref) =>
    ref.watch(selectedInstitutionProvider)?.label ?? 'NUST';

/// Figma Badge/Private, Official · NUST, Shared · NUST.
class TemplateBadge extends ConsumerWidget {
  const TemplateBadge(this.template, {super.key});
  final StudioTemplate template;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final (fill, ink) = switch (template.access) {
      TemplateAccess.private => (AppColors.canvas, AppColors.muted),
      TemplateAccess.shared => (institutionTint(ref, context), primary),
      TemplateAccess.official => (AppColors.brand50, AppColors.brandDark),
      TemplateAccess.pending => (
        const Color(0xFFFEF4E2),
        const Color(0xFF9A5B00),
      ),
    };
    return ProjectBadge(
      label: template.badge(institutionLabel(ref)),
      icon: template.access.icon,
      fill: fill,
      ink: ink,
    );
  }
}

/// 52 × 68 page thumbnail with a header bar and text lines (Figma "thumb").
class TemplateThumb extends StatelessWidget {
  const TemplateThumb({super.key});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget line(double w) => Container(
      width: w,
      height: 3,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFCBD0CE),
        borderRadius: BorderRadius.circular(2),
      ),
    );
    return Container(
      width: 52,
      height: 68,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 6,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          line(40),
          line(28),
          line(40),
          line(28),
          line(40),
        ],
      ),
    );
  }
}

/// Sheet handle (40 × 5, line colour).
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

/// Text field with a leading icon and a voice button (Figma Input + Voice
/// input): 54 dp, radius 18, line border.
class VoiceTextField extends StatelessWidget {
  const VoiceTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.fieldLabel,
    this.focusNode,
    this.onChanged,
    this.autofocus = false,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String hint;
  final String icon;
  final String fieldLabel;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextInputType? keyboardType;

  Future<void> _dictate(BuildContext context) async {
    final text = await showDictationSheet(context, fieldLabel: fieldLabel);
    if (text == null || text.trim().isEmpty) return;
    controller.text = text.trim();
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    onChanged?.call(controller.text);
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 54),
    padding: const EdgeInsets.only(left: 16, right: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line, width: 1.2),
    ),
    child: Row(
      children: [
        DashboardIcon(icon, color: AppColors.subtle),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            onChanged: onChanged,
            keyboardType: keyboardType,
            style: dashboardText(15),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: dashboardText(15, color: AppColors.subtle),
            ),
          ),
        ),
        SizedBox.square(
          dimension: 48,
          child: Center(
            child: DashboardAction(
              label: 'Speak $fieldLabel',
              radius: 18,
              color: AppColors.brand50,
              onPressed: () => _dictate(context),
              child: const SizedBox.square(
                dimension: 36,
                child: Center(
                  child: DashboardIcon('mic', color: AppColors.brand, size: 20),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Rule row (Figma Row/Font on 05.5): 44 tile, title, value, chevron.
class RuleRow extends StatelessWidget {
  const RuleRow({
    super.key,
    required this.rule,
    required this.tint,
    required this.onTap,
    this.trailing,
  });
  final TemplateRule rule;
  final Color tint;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DashboardAction(
      label: '${rule.title}, ${rule.value}',
      radius: 16,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DashboardIcon(rule.icon, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rule.title,
                  style: dashboardText(16, weight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  rule.value,
                  textAlign: TextAlign.right,
                  style: dashboardText(
                    14,
                    color: AppColors.subtle,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              trailing ??
                  const DashboardIcon(
                    'chevron_right',
                    color: AppColors.subtle,
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edit one rule's value. Returns the new value, or null.
Future<String?> showRuleEditor(BuildContext context, TemplateRule rule) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
      sheetAnimationStyle: sheetMotion(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _RuleEditor(rule: rule),
    );

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({required this.rule});
  final TemplateRule rule;
  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late final _text = TextEditingController(text: widget.rule.value);

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      10,
      24,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHandle(),
        const SizedBox(height: 19),
        Text(
          widget.rule.title,
          style: dashboardText(22, weight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        VoiceTextField(
          controller: _text,
          hint: widget.rule.title,
          icon: widget.rule.icon,
          fieldLabel: widget.rule.title,
          autofocus: true,
        ),
        const SizedBox(height: 16),
        ConsentPillButton(
          label: 'Save',
          icon: 'projects/check',
          height: 56,
          onPressed: _text.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _text.text.trim()),
        ),
      ],
    ),
  );
}

/// Figma 05.6 Save & share. Returns the name and who can use it.
Future<(String, TemplateAccess)?> showSaveTemplateSheet(
  BuildContext context, {
  required String suggestedName,
}) => showModalBottomSheet<(String, TemplateAccess)>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  backgroundColor: Colors.white,
  barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
  sheetAnimationStyle: sheetMotion(context),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => _SaveSheet(suggestedName: suggestedName),
);

class _SaveSheet extends ConsumerStatefulWidget {
  const _SaveSheet({required this.suggestedName});
  final String suggestedName;
  @override
  ConsumerState<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends ConsumerState<_SaveSheet> {
  late final _name = TextEditingController(text: widget.suggestedName);
  TemplateAccess _access = TemplateAccess.private;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inst = institutionLabel(ref);
    final options = [
      (
        TemplateAccess.private,
        'form/lock',
        'Only me',
        'Private — visible on your phone only',
      ),
      (
        TemplateAccess.shared,
        'capture/users',
        '$inst researchers',
        'Shared — they can use or duplicate it',
      ),
      (
        TemplateAccess.pending,
        'projects/shield',
        'Request Official status',
        'Checked with $inst ethics office; then locked',
      ),
    ];
    return SingleChildScrollView(
      primary: false,
      padding: EdgeInsets.fromLTRB(
        24,
        10,
        24,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 19),
          Semantics(
            header: true,
            child: Text(
              'Save template',
              style: dashboardText(22, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Template name',
              style: dashboardText(
                13,
                color: AppColors.muted,
                weight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 6),
          VoiceTextField(
            controller: _name,
            hint: 'Template name',
            icon: 'responses/file',
            fieldLabel: 'Template name',
          ),
          const SizedBox(height: 16),
          Text(
            'Who can use it?',
            style: dashboardText(
              13,
              color: AppColors.muted,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          for (final (access, icon, title, subtitle) in options) ...[
            if (access != options.first.$1) const SizedBox(height: 8),
            _AccessOption(
              icon: icon,
              title: title,
              subtitle: subtitle,
              selected: _access == access,
              onTap: () => setState(() => _access = access),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'You can change this later. Shared templates never include '
            'participant data.',
            style: dashboardText(12, color: AppColors.subtle),
          ),
          const SizedBox(height: 24),
          ConsentPillButton(
            label: 'Save template',
            icon: 'projects/check',
            height: 56,
            onPressed: _name.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, (_name.text.trim(), _access)),
          ),
        ],
      ),
    );
  }
}

class _AccessOption extends ConsumerWidget {
  const _AccessOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final large = ref.watch(largerTouchTargetsProvider);
    final duration = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: DashboardAction(
        label: '$title. $subtitle',
        radius: 18,
        color: Colors.transparent,
        onPressed: onTap,
        child: AnimatedContainer(
          duration: duration,
          constraints: BoxConstraints(minHeight: large ? 72 : 64),
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          decoration: BoxDecoration(
            color: selected
                ? Color.lerp(Colors.white, primary, .08)
                : AppColors.canvas,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? primary : AppColors.canvas,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DashboardIcon(icon, color: AppColors.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: dashboardText(15, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: dashboardText(12, color: AppColors.subtle),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: duration,
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? primary : const Color(0xFFB9C0BD),
                    width: selected ? 2 : 1.5,
                  ),
                ),
                child: AnimatedScale(
                  duration: duration,
                  curve: Curves.easeOutBack,
                  scale: selected ? 1 : 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
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

/// Figma 13.6 Edit a section. Returns the edited section, or null on
/// Cancel. [readOnly] shows the wording of a shared or official template
/// without letting it be changed.
Future<TemplateSection?> showSectionEditor(
  BuildContext context,
  TemplateSection section, {
  bool readOnly = false,
}) => showModalBottomSheet<TemplateSection>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  backgroundColor: Colors.white,
  barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
  sheetAnimationStyle: sheetMotion(context),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => _SectionEditor(section: section, readOnly: readOnly),
);

class _SectionEditor extends StatefulWidget {
  const _SectionEditor({required this.section, required this.readOnly});
  final TemplateSection section;
  final bool readOnly;
  @override
  State<_SectionEditor> createState() => _SectionEditorState();
}

class _SectionEditorState extends State<_SectionEditor> {
  late final _title = TextEditingController(text: widget.section.title);
  late final _text = TextEditingController(text: widget.section.text);

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  /// Rough plain-language check: the longer the sentences, the higher the
  /// grade. The on-device model (P3) replaces this.
  String get _grade {
    final words = _text.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    final sentences = _text.text
        .split(RegExp(r'[.!?]'))
        .where((s) => s.trim().isNotEmpty)
        .length;
    if (words.isEmpty || sentences == 0) return '—';
    final perSentence = words.length / sentences;
    final grade = (perSentence / 2).clamp(3, 12).round();
    return 'Grade $grade';
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.readOnly || widget.section.locked;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: dashboardText(
          13,
          color: AppColors.muted,
          weight: FontWeight.w500,
        ),
      ),
    );
    Widget field(TextEditingController c, {int maxLines = 1}) => Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: TextField(
        controller: c,
        readOnly: locked,
        maxLines: maxLines,
        minLines: maxLines == 1 ? 1 : 4,
        onChanged: (_) => setState(() {}),
        style: dashboardText(15),
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 19),
            Text(
              locked ? widget.section.title : 'Edit section',
              style: dashboardText(22, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              locked
                  ? 'Read-only. Make your own copy of the template to reword '
                        'it.'
                  : 'Plain language, short sentences. Participants read this.',
              style: dashboardText(13, color: AppColors.subtle),
            ),
            const SizedBox(height: 14),
            if (!locked) ...[
              label('Section title'),
              field(_title),
              const SizedBox(height: 14),
              label('Text'),
            ],
            field(_text, maxLines: 8),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ProjectBadge(
                  label: 'Reading level: $_grade',
                  fill: AppColors.brand50,
                  ink: AppColors.brandDark,
                ),
                if (widget.section.required)
                  const ProjectBadge(
                    label: 'Required element',
                    fill: AppColors.canvas,
                    ink: AppColors.muted,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ConsentPillButton(
                    label: locked ? 'Close' : 'Cancel',
                    filled: false,
                    height: 56,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                if (!locked) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ConsentPillButton(
                      label: 'Save section',
                      height: 56,
                      onPressed: _title.text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(
                              context,
                              widget.section.copyWith(
                                title: _title.text.trim(),
                                text: _text.text.trim(),
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma 13.2 "What's inside" / 13.3 Sections. Read-only on a template
/// that isn't yours ([onToggle] null); your own copy can switch optional
/// sections off and reword them.
class TemplateSectionsCard extends ConsumerStatefulWidget {
  const TemplateSectionsCard({
    super.key,
    required this.sections,
    required this.onOpen,
    this.onToggle,
    this.onAdd,
    this.collapseAfter = 3,
  });
  final List<TemplateSection> sections;
  final ValueChanged<TemplateSection> onOpen;
  final void Function(TemplateSection section, bool included)? onToggle;
  final VoidCallback? onAdd;

  /// Rows shown before "+ N more sections".
  final int collapseAfter;

  @override
  ConsumerState<TemplateSectionsCard> createState() =>
      _TemplateSectionsCardState();
}

class _TemplateSectionsCardState extends ConsumerState<TemplateSectionsCard> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final editable = widget.onToggle != null;
    final all = widget.sections;
    final shown = _all ? all : all.take(widget.collapseAfter).toList();
    final hidden = all.length - shown.length;
    final used = all.where((s) => s.included).length;

    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'What’s inside · $used sections',
              style: dashboardText(14, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSize(
            duration: Duration(milliseconds: reduceMotion(context) ? 0 : 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (final (i, s) in shown.indexed) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.line,
                    ),
                  _SectionRow(
                    section: s,
                    editable: editable,
                    onOpen: () => widget.onOpen(s),
                    onToggle: widget.onToggle == null
                        ? null
                        : (v) => widget.onToggle!(s, v),
                  ),
                ],
              ],
            ),
          ),
          if (hidden > 0 || _all)
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 44),
                alignment: Alignment.centerLeft,
                overlayColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
              ),
              onPressed: () => setState(() => _all = !_all),
              child: Text(
                _all ? 'Show fewer sections' : '+ $hidden more sections',
                style: dashboardText(
                  13,
                  color: primary,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          if (widget.onAdd != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 44),
                alignment: Alignment.centerLeft,
                overlayColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
              ),
              onPressed: widget.onAdd,
              child: Text(
                '+ Add a section',
                style: dashboardText(
                  14,
                  color: primary,
                  weight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.editable,
    required this.onOpen,
    required this.onToggle,
  });
  final TemplateSection section;
  final bool editable;
  final VoidCallback onOpen;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final off = !section.included;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: dashboardText(
                      15,
                      color: off ? AppColors.subtle : AppColors.ink,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    off ? 'Left out of your copy' : section.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dashboardText(12, color: AppColors.subtle),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (editable && section.required)
              const ProjectBadge(
                label: 'Required',
                fill: AppColors.canvas,
                ink: AppColors.muted,
              )
            else if (editable)
              GestureDetector(
                onTap: () => onToggle?.call(!section.included),
                child: AppToggle(value: section.included),
              )
            else if (section.locked)
              const DashboardIcon(
                'form/lock',
                color: AppColors.subtle,
                size: 18,
              )
            else
              const DashboardIcon(
                'chevron_right',
                color: AppColors.subtle,
                size: 20,
              ),
          ],
        ),
      ),
    );
    return Semantics(
      label: section.title,
      hint: editable ? 'Edit this section' : 'Read this section',
      child: ExcludeSemantics(
        child: DashboardAction(
          label: section.title,
          radius: 14,
          color: Colors.transparent,
          onPressed: onOpen,
          child: row,
        ),
      ),
    );
  }
}
