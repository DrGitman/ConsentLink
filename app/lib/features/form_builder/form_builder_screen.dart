import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toggle.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../preferences/accessibility_preferences.dart';
import '../projects/project_widgets.dart';
import 'add_question_sheet.dart';
import 'form_builder_data.dart';

/// Figma Screen Artboards 04.5 Form builder ("Participant details").
///
/// Measurements from Figma: subtitle 14 dp under the header, cards 74 dp tall
/// with 8 dp gaps and radius 24; inside each card the drag dots sit 10 dp from
/// the left, a 44 dp icon tile (radius 14) at 30 dp, title 15 semibold and
/// subtitle 12 at 86 dp, a 30 dp voice badge and the 22 dp "more" icon on the
/// right. "Add a question" is a 56 dp dashed pill (radius 28) 12 dp below.
class FormBuilderScreen extends ConsumerStatefulWidget {
  const FormBuilderScreen({super.key});
  @override
  ConsumerState<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends ConsumerState<FormBuilderScreen> {
  String? _justAdded;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _addQuestion() async {
    final type = await showAddQuestionSheet(context);
    if (type == null || !mounted) return;
    final id = ref.read(formFieldsProvider.notifier).add(type);
    setState(() => _justAdded = id);
  }

  Future<void> _edit(FormFieldDef field) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    sheetAnimationStyle: sheetMotion(context),
    builder: (context) => _FieldSheet(fieldId: field.id),
  );

  @override
  Widget build(BuildContext context) {
    final fields = ref.watch(formFieldsProvider);
    final notifier = ref.read(formFieldsProvider.notifier);
    final reduced = reduceMotion(context);

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: ConsentTopBar(
                    leading: AppBackButton(onPressed: _back),
                    title: 'Participant details',
                    trailing: ProjectCircleButton(
                      icon: 'consent/preview_doc',
                      label: 'Preview as participant',
                      onPressed: () => showProjectNotice(
                        context,
                        'Preview as participant',
                        'The participant view comes with Field capture (06).',
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    buildDefaultDragHandles: false,
                    header: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Questions participants answer after reading the consent. Every field accepts typing or voice.',
                        style: dashboardText(
                          13,
                          color: AppColors.subtle,
                        ).copyWith(height: 1.45),
                      ),
                    ),
                    footer: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _AddQuestionButton(onTap: _addQuestion),
                    ),
                    itemCount: fields.length,
                    onReorder: notifier.reorder,
                    // Lifted card grows slightly (no shadow, per app rules).
                    proxyDecorator: (child, index, animation) =>
                        AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) => Transform.scale(
                            scale: reduced
                                ? 1
                                : 1 +
                                      .03 *
                                          Curves.easeOut.transform(
                                            animation.value,
                                          ),
                            child: Material(
                              color: Colors.transparent,
                              child: child,
                            ),
                          ),
                          child: child,
                        ),
                    itemBuilder: (context, i) {
                      final field = fields[i];
                      final card = _FieldCard(
                        index: i,
                        field: field,
                        onTap: () => _edit(field),
                        onVoice: () => notifier.update(
                          field.id,
                          (f) => f.copyWith(voiceAllowed: !f.voiceAllowed),
                        ),
                      );
                      return Padding(
                        key: ValueKey(field.id),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: field.id == _justAdded
                            ? RiseIn(child: card)
                            : card,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: ConsentPillButton(
                    label: 'Continue to template',
                    onPressed: () => context.push('/new-consent/template'),
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

class _FieldCard extends ConsumerWidget {
  const _FieldCard({
    required this.index,
    required this.field,
    required this.onTap,
    required this.onVoice,
  });
  final int index;
  final FormFieldDef field;
  final VoidCallback onTap;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final tint = institutionTint(ref, context);
    final large = ref.watch(largerTouchTargetsProvider);
    final voice = field.voiceAllowed;
    return DashboardAction(
      label: '${field.label}, ${field.subtitle}',
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 74),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Row(
            children: [
              // Drag handle: 6 dots, 10 dp from the card edge in Figma.
              ReorderableDragStartListener(
                index: index,
                child: Semantics(
                  label: 'Drag to reorder ${field.label}',
                  child: SizedBox(
                    width: large ? 40 : 26,
                    height: large ? 64 : 48,
                    child: const Center(
                      child: DashboardIcon('form/drag', size: 22),
                    ),
                  ),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DashboardIcon(field.iconName, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.label,
                      style: dashboardText(15, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      field.subtitle,
                      style: dashboardText(12, color: AppColors.subtle),
                    ),
                  ],
                ),
              ),
              // Voice badge: 30 dp, green when voice answers are allowed.
              // Figma: badge at 290–320, "more" at 322–344 (card 350 wide).
              SizedBox(
                width: large ? 64 : 32,
                height: large ? 64 : 48,
                child: Center(
                  child: Semantics(
                    toggled: voice,
                    child: DashboardAction(
                      label: voice
                          ? 'Voice answers on for ${field.label}'
                          : 'Voice answers off for ${field.label}',
                      radius: 15,
                      color: voice ? AppColors.brand50 : AppColors.canvas,
                      onPressed: onVoice,
                      child: SizedBox.square(
                        dimension: large ? 44 : 30,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: Duration(
                              milliseconds: reduceMotion(context) ? 0 : 150,
                            ),
                            child: DashboardIcon(
                              'mic',
                              key: ValueKey(voice),
                              size: 18,
                              color: voice
                                  ? AppColors.brandDark
                                  : AppColors.subtle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: large ? 48 : 26,
                height: large ? 64 : 48,
                child: DashboardAction(
                  label: 'More for ${field.label}',
                  radius: 16,
                  color: Colors.transparent,
                  onPressed: onTap,
                  child: const Center(
                    child: DashboardIcon(
                      'projects/dots',
                      color: AppColors.subtle,
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

class _AddQuestionButton extends ConsumerWidget {
  const _AddQuestionButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final tint = institutionTint(ref, context);
    return DashboardAction(
      label: 'Add a question',
      radius: 28,
      color: Colors.transparent,
      onPressed: onTap,
      child: CustomPaint(
        painter: DashedRRect(color: Color.lerp(tint, primary, .3)!, radius: 28),
        child: SizedBox(
          height: ref.watch(largerTouchTargetsProvider) ? 64 : 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DashboardIcon('projects/plus', color: primary, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Add a question',
                  style: dashboardText(
                    15,
                    color: primary,
                    weight: FontWeight.w600,
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

/// Dashed outline (Figma "Add field": 1.5 dp, dash 8 / gap 6).
class DashedRRect extends CustomPainter {
  DashedRRect({required this.color, required this.radius});
  final Color color;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(.75);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += 14) {
        canvas.drawPath(metric.extractPath(d, d + 8), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRect old) => old.color != color;
}

/// Edit one question: name, required, voice, duplicate, delete.
class _FieldSheet extends ConsumerStatefulWidget {
  const _FieldSheet({required this.fieldId});
  final String fieldId;
  @override
  ConsumerState<_FieldSheet> createState() => _FieldSheetState();
}

class _FieldSheetState extends ConsumerState<_FieldSheet> {
  late final _name = TextEditingController(
    text: ref
        .read(formFieldsProvider)
        .firstWhere((f) => f.id == widget.fieldId)
        .label,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = ref
        .watch(formFieldsProvider)
        .where((f) => f.id == widget.fieldId)
        .firstOrNull;
    if (field == null) return const SizedBox.shrink();
    final notifier = ref.read(formFieldsProvider.notifier);
    final isConsent = field.type == FieldType.consentCapture;
    return Padding(
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
                'Edit question',
                style: dashboardText(22, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                field.type.summary,
                style: dashboardText(14, color: AppColors.subtle),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Question'),
                onChanged: (v) => notifier.update(
                  field.id,
                  (f) => f.copyWith(label: v.trim().isEmpty ? f.label : v),
                ),
              ),
              const SizedBox(height: 8),
              AppToggleRow(
                title: 'Required',
                subtitle: isConsent
                    ? 'Consent capture is always required'
                    : null,
                value: field.required,
                onChanged: isConsent
                    ? null
                    : (v) => notifier.update(
                        field.id,
                        (f) => f.copyWith(required: v),
                      ),
              ),
              AppToggleRow(
                title: 'Voice answers',
                value: field.voiceAllowed,
                onChanged: (v) => notifier.update(
                  field.id,
                  (f) => f.copyWith(voiceAllowed: v),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ConsentPillButton(
                      label: 'Duplicate',
                      filled: false,
                      height: 52,
                      onPressed: () {
                        notifier.duplicate(field.id);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ConsentPillButton(
                      label: 'Delete',
                      filled: false,
                      height: 52,
                      onPressed: isConsent
                          ? null
                          : () async {
                              final ok = await _confirmDelete(context, field);
                              if (ok == true && context.mounted) {
                                Navigator.pop(context);
                                notifier.remove(field.id);
                              }
                            },
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

  Future<bool?> _confirmDelete(BuildContext context, FormFieldDef field) {
    final reduced = reduceMotion(context);
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: Duration(milliseconds: reduced ? 150 : 250),
      pageBuilder: (context, _, _) => AlertDialog(
        title: const Text('Delete question?'),
        content: Text('“${field.label}” will be removed from this form.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
      transitionBuilder: (context, a, _, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        final fade = FadeTransition(opacity: c, child: child);
        if (reduced) return fade;
        return ScaleTransition(
          scale: Tween(begin: .92, end: 1.0).animate(c),
          child: fade,
        );
      },
    );
  }
}
