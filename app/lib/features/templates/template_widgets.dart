import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/dictation_sheet.dart';
import '../dashboard/dashboard_components.dart';
import '../institution/institution_preferences.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../preferences/accessibility_preferences.dart';
import '../projects/project_widgets.dart';
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
