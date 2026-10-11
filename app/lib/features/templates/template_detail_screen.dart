import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../dashboard/dashboard_components.dart';
import '../form_builder/form_builder_data.dart';
import '../institution/institution_preferences.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../projects/project_widgets.dart';
import '../responses/responses_widgets.dart';
import 'template_data.dart';
import 'template_widgets.dart';

/// Figma 05.5 Template detail (79:121).
class TemplateDetailScreen extends ConsumerWidget {
  const TemplateDetailScreen({super.key, required this.id});
  final String id;

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/templates');

  Future<void> _editRule(
    BuildContext context,
    WidgetRef ref,
    StudioTemplate t,
    TemplateRule rule,
  ) async {
    if (t.locked) {
      await showProjectNotice(
        context,
        rule.title,
        'Locked by the official template. Duplicate it to make your own '
        'version.',
      );
      return;
    }
    if (!t.mine) {
      await showProjectNotice(
        context,
        rule.title,
        'Shared by ${t.owner}. Duplicate it to change the rules.',
      );
      return;
    }
    final value = await showRuleEditor(context, rule);
    if (value == null) return;
    ref
        .read(templateLibraryProvider.notifier)
        .updateRule(t.id, rule.key, value);
  }

  void _duplicate(BuildContext context, WidgetRef ref, StudioTemplate t) {
    final copy = ref.read(templateLibraryProvider.notifier).duplicate(t);
    showOverlayToast(
      context,
      kind: AppToastKind.success,
      title: 'Duplicated',
      subtitle: '${copy.name} · private',
    );
    context.pushReplacement('/templates/view/${copy.id}');
  }

  void _useForForm(BuildContext context, WidgetRef ref, StudioTemplate t) {
    final formId = t.formId;
    final known =
        formId != null &&
        ref.read(formTemplatesProvider).any((f) => f.id == formId);
    if (!known) {
      showProjectNotice(
        context,
        'Use for form',
        'Your own templates reach the form builder once template storage is '
            'connected. Official templates work now.',
      );
      return;
    }
    ref.read(selectedTemplateProvider.notifier).state = formId;
    context.push('/new-consent/template');
  }

  Future<void> _more(BuildContext context, WidgetRef ref, StudioTemplate t) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        useRootNavigator: true,
        backgroundColor: Colors.white,
        barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
        sheetAnimationStyle: sheetMotion(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheet) {
          Widget item(
            String icon,
            String label,
            VoidCallback onTap, {
            Color color = AppColors.ink,
          }) => DashboardAction(
            label: label,
            radius: 16,
            onPressed: () {
              Navigator.pop(sheet);
              onTap();
            },
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  DashboardIcon(icon, color: color),
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: dashboardText(
                      16,
                      color: color,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 12),
                if (t.mine) ...[
                  item('consent/pen', 'Rename', () => _rename(context, ref, t)),
                  item('consent/x', 'Delete template', () {
                    ref.read(templateLibraryProvider.notifier).remove(t.id);
                    showOverlayToast(
                      context,
                      kind: AppToastKind.info,
                      title: 'Template deleted',
                      subtitle: t.name,
                    );
                    _back(context);
                  }, color: AppColors.error),
                ] else ...[
                  item(
                    'templates/copy',
                    'Duplicate',
                    () => _duplicate(context, ref, t),
                  ),
                  item(
                    'consent/info',
                    'About this template',
                    () => showProjectNotice(
                      context,
                      t.name,
                      t.verified ?? 'Shared by ${t.owner}.',
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    StudioTemplate t,
  ) async {
    final name = await showRuleEditor(
      context,
      TemplateRule(
        key: 'name',
        title: 'Template name',
        value: t.name,
        icon: 'responses/file',
      ),
    );
    if (name == null) return;
    ref.read(templateLibraryProvider.notifier).rename(t.id, name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref
        .watch(templateLibraryProvider)
        .where((e) => e.id == id)
        .firstOrNull;
    final tint = institutionTint(ref, context);
    final primary = Theme.of(context).colorScheme.primary;
    final initials = ref.watch(selectedInstitutionProvider)?.initials ?? 'NU';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 9, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConsentTopBar(
                          leading: AppBackButton(
                            onPressed: () => _back(context),
                          ),
                          title: 'Template',
                          trailing: t == null
                              ? null
                              : ProjectCircleButton(
                                  icon: 'projects/dots',
                                  label: 'More options',
                                  color: AppColors.subtle,
                                  onPressed: () => _more(context, ref, t),
                                ),
                        ),
                        const SizedBox(height: 10),
                        if (t == null)
                          const EmptyCard(
                            title: 'Template not found',
                            message:
                                'It may have been deleted, or template storage '
                                'isn\'t connected yet.',
                          )
                        else ...[
                          RiseIn(
                            child: WhiteCard(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: _PagePreview(
                                  initials: initials,
                                  primary: primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            header: true,
                            child: Text(
                              t.name,
                              style: dashboardText(22, weight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 7),
                          TemplateBadge(t),
                          const SizedBox(height: 8),
                          Text(
                            t.verified ?? t.meta,
                            style: dashboardText(13, color: AppColors.subtle),
                          ),
                          const SizedBox(height: 14),
                          WhiteCard(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                            child: Column(
                              children: [
                                for (final rule in t.rules)
                                  RuleRow(
                                    rule: rule,
                                    tint: tint,
                                    onTap: () =>
                                        _editRule(context, ref, t, rule),
                                  ),
                              ],
                            ),
                          ),
                          if (t.locked) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                10,
                                14,
                                10,
                              ),
                              constraints: const BoxConstraints(minHeight: 56),
                              decoration: BoxDecoration(
                                color: Color.lerp(Colors.white, primary, .08),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  DashboardIcon('form/lock', color: primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Font, footer and logo are locked. You can '
                                      'still add questions and languages.',
                                      style: dashboardText(12, color: primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                if (t != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ConsentPillButton(
                            label: 'Duplicate',
                            icon: 'templates/copy',
                            filled: false,
                            onPressed: () => _duplicate(context, ref, t),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ConsentPillButton(
                            label: 'Use for form',
                            onPressed: () => _useForForm(context, ref, t),
                          ),
                        ),
                      ],
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

/// 160 × 168 page preview (Figma "page").
class _PagePreview extends StatelessWidget {
  const _PagePreview({required this.initials, required this.primary});
  final String initials;
  final Color primary;
  @override
  Widget build(BuildContext context) {
    Widget line(double w, {double h = 5, Color c = const Color(0xFFCBD0CE)}) =>
        Container(
          width: w,
          height: h,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(2),
          ),
        );
    return ExcludeSemantics(
      child: Container(
        width: 160,
        height: 168,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    initials,
                    textScaler: TextScaler.noScaling,
                    style: dashboardText(
                      11,
                      color: Colors.white,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        width: 90,
                        height: 7,
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 60,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB9BEC9),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final w in [
              136.0,
              136.0,
              90.0,
              136.0,
              136.0,
              90.0,
              136.0,
              136.0,
              90.0,
            ])
              line(w),
            const Spacer(),
            line(136, h: 4, c: const Color(0xFFDDE1DF)),
          ],
        ),
      ),
    );
  }
}
