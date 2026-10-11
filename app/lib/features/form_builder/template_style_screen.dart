import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../dashboard/dashboard_components.dart';
import '../institution/institution.dart';
import '../institution/institution_preferences.dart';
import '../new_consent/consent_draft_data.dart';
import '../new_consent/consent_widgets.dart';
import '../projects/project_widgets.dart';
import 'form_builder_data.dart';

/// Figma Screen Artboards 04.7 Template & style ("Look of your form").
///
/// Figma: label 14 semibold 14 dp under the header; template cards 110 × 150
/// (radius 24, 8 dp gaps, selected = 2 dp primary border) with an 82 × 90
/// page preview (radius 8) and a 12 semibold name; a 350 dp style card
/// (radius 24, 16 dp padding) 20 dp below with the lock line, four 56 dp rows
/// (44 dp tile radius 14, label 16 medium, value 14 medium grey, chevron) and
/// a 12 regular footnote.
class TemplateStyleScreen extends ConsumerStatefulWidget {
  const TemplateStyleScreen({super.key});
  @override
  ConsumerState<TemplateStyleScreen> createState() =>
      _TemplateStyleScreenState();
}

class _TemplateStyleScreenState extends ConsumerState<TemplateStyleScreen> {
  bool _saved = false;
  Timer? _leave;

  @override
  void dispose() {
    _leave?.cancel();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _save() {
    if (!ref.read(newConsentPreviewProvider)) {
      showProjectNotice(
        context,
        'Save form',
        'Saving forms will be connected with the project data source.',
      );
      return;
    }
    setState(() => _saved = true);
    _leave = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) context.go('/projects');
    });
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(formTemplatesProvider);
    final selectedId = ref.watch(selectedTemplateProvider);
    final selected = templates.where((t) => t.id == selectedId).firstOrNull;
    final institution =
        ref.watch(selectedInstitutionProvider) ?? Institution.nust;
    final reduced = reduceMotion(context);

    return Scaffold(
      body: SafeArea(
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
                                title: 'Look of your form',
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Your templates & ${institution.label}',
                                style: dashboardText(
                                  14,
                                  color: AppColors.muted,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 9),
                              if (templates.isEmpty)
                                _EmptyTemplates()
                              else ...[
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  clipBehavior: Clip.none,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (final (i, t)
                                          in templates.indexed) ...[
                                        if (i > 0) const SizedBox(width: 8),
                                        _TemplateCard(
                                          template: t,
                                          selected: t.id == selectedId,
                                          onTap: () =>
                                              ref
                                                      .read(
                                                        selectedTemplateProvider
                                                            .notifier,
                                                      )
                                                      .state =
                                                  t.id,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (selected != null)
                                  _StyleCard(
                                    template: selected,
                                    institution: institution,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 12,
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: reduced ? 150 : 250),
                          transitionBuilder: (child, a) =>
                              appToastTransition(context, child, a),
                          child: _saved
                              ? const AppToast(
                                  key: ValueKey('saved'),
                                  kind: AppToastKind.success,
                                  title: 'Form saved',
                                  subtitle: 'Only on this phone until you sync',
                                )
                              : const SizedBox(key: ValueKey('none')),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: ConsentPillButton(
                    label: _saved ? 'Saved' : 'Save form',
                    onPressed: _saved ? null : _save,
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

class _EmptyTemplates extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      'Templates appear here once Template Studio is connected. The form uses the default style for now.',
      style: dashboardText(14, color: AppColors.muted),
    ),
  );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });
  final FormTemplate template;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      child: DashboardAction(
        label: template.name,
        color: Colors.transparent,
        onPressed: onTap,
        child: AnimatedContainer(
          duration: reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: 110,
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? primary : Colors.white,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: _PagePreview(primary: primary),
              ),
              const SizedBox(height: 8),
              Text(
                template.name,
                style: dashboardText(12, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 82 × 90 page with a primary header bar and grey lines (Figma "page").
class _PagePreview extends StatelessWidget {
  const _PagePreview({required this.primary});
  final Color primary;
  @override
  Widget build(BuildContext context) => Container(
    width: 82,
    height: 90,
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(22, 8, primary),
        const SizedBox(height: 8),
        for (final (i, w) in <double>[64, 64, 40, 64, 64, 40].indexed) ...[
          if (i > 0) const SizedBox(height: 6),
          _bar(w, 4, const Color(0xFFCBD0CE)),
        ],
      ],
    ),
  );
  Widget _bar(double w, double h, Color c) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
  );
}

class _StyleCard extends ConsumerWidget {
  const _StyleCard({required this.template, required this.institution});
  final FormTemplate template;
  final Institution institution;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final tint = institutionTint(ref, context);
    final rows = [
      ('form/type', 'Font', template.font),
      ('form/textsize', 'Line spacing', template.lineSpacing),
      ('layers', 'Margins', template.margins),
      ('form/image', 'Logo', template.logo),
    ];
    final swap = Duration(milliseconds: reduceMotion(context) ? 0 : 250);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: swap,
            child: Row(
              key: ValueKey(template.official),
              children: [
                if (template.official) ...[
                  const DashboardIcon(
                    'form/lock',
                    size: 16,
                    color: AppColors.subtle,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    template.official
                        ? 'Official ${institution.label} template · locked fields'
                        : 'Your template · you can change every field',
                    style: dashboardText(
                      12,
                      color: AppColors.subtle,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (final (icon, label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: DashboardAction(
                label: '$label, $value',
                radius: 16,
                color: Colors.white,
                onPressed: () => showProjectNotice(
                  context,
                  label,
                  template.official
                      ? 'This is locked by the official template. Duplicate it in Templates to make your own version.'
                      : 'Editing styles comes with Template Studio (05).',
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
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
                        child: DashboardIcon(icon, color: primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: dashboardText(16, weight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: swap,
                          child: Text(
                            value,
                            key: ValueKey(value),
                            textAlign: TextAlign.end,
                            style: dashboardText(
                              14,
                              color: AppColors.subtle,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const DashboardIcon(
                        'chevron_right',
                        size: 20,
                        color: AppColors.subtle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            template.official
                ? 'You can change: text size for participants and a second language column.'
                : 'Changes apply to this form only.',
            style: dashboardText(12, color: AppColors.subtle),
          ),
        ],
      ),
    );
  }
}
