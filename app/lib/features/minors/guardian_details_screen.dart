import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../dashboard/dashboard_components.dart';
import '../field_capture/capture_widgets.dart';
import '../field_capture/field_capture_data.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../settings/settings_widgets.dart' show RadioDot;
import '../templates/template_widgets.dart' show SheetHandle, VoiceTextField;
import 'minors_data.dart';

/// Figma 10.3 Guardian details (3:6966), step 1 of 3. The researcher
/// confirms the guardian's legal authority (a human-only decision), then the
/// guardian reads the consent form in their own language.
class GuardianDetailsScreen extends ConsumerStatefulWidget {
  const GuardianDetailsScreen({super.key});
  @override
  ConsumerState<GuardianDetailsScreen> createState() =>
      _GuardianDetailsScreenState();
}

class _GuardianDetailsScreenState extends ConsumerState<GuardianDetailsScreen> {
  late final _name = TextEditingController(
    text: ref.read(minorSessionProvider).guardianName,
  );
  late final _phone = TextEditingController(
    text: ref.read(minorSessionProvider).guardianPhone,
  );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/field-capture/age');
    }
  }

  String _language() =>
      ref.read(minorSessionProvider).guardianLanguage ??
      ref.read(captureSessionProvider).language;

  /// The guardian reads the full form (06.2) with read-aloud in their
  /// language, then gives consent (10.4).
  void _guardianReads() {
    final capture = ref.read(captureSessionProvider.notifier);
    capture.setLanguage(_language());
    capture.setReadAloud(true);
    capture.goToSection(0);
    ref.read(minorSessionProvider.notifier).setGuardianReading(true);
    context.push('/field-capture/read');
  }

  Future<void> _pickLanguage() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    useRootNavigator: true,
    backgroundColor: Colors.white,
    barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
    sheetAnimationStyle: sheetMotion(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 19),
          Text(
            'Guardian’s language',
            style: dashboardText(22, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'The consent form is read aloud in this language.',
            style: dashboardText(13, color: AppColors.subtle),
          ),
          const SizedBox(height: 8),
          for (final l in captureLanguages)
            Semantics(
              selected: l == _language(),
              inMutuallyExclusiveGroup: true,
              child: DashboardAction(
                label: l,
                radius: 16,
                onPressed: () {
                  ref
                      .read(minorSessionProvider.notifier)
                      .setGuardianLanguage(l);
                  Navigator.pop(sheet);
                },
                child: SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l,
                          style: dashboardText(
                            16,
                            weight: l == _language()
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      RadioDot(selected: l == _language()),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(minorSessionProvider);
    final c = ref.read(minorSessionProvider.notifier);
    ref.watch(captureSessionProvider.select((x) => x.language));
    final primary = Theme.of(context).colorScheme.primary;

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

    return CaptureScaffold(
      participant: false,
      onBack: _back,
      background: AppColors.canvas,
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 24),
      footer: ConsentPillButton(
        label: 'Guardian reads & signs',
        onPressed: s.detailsDone ? _guardianReads : null,
      ),
      children: [
        ConsentTopBar(
          leading: AppBackButton(onPressed: _back),
          title: 'Guardian',
        ),
        const SizedBox(height: 28),
        Text(
          'Step 1 of 3 · for participant ${minorCode(ref)} (age ${s.age ?? '–'})',
          style: dashboardText(
            13,
            color: AppColors.subtle,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        label('Guardian full name'),
        VoiceTextField(
          controller: _name,
          hint: 'Full name as on their ID',
          icon: 'navigation/user',
          fieldLabel: 'Guardian full name',
          onChanged: c.setGuardianName,
        ),
        const SizedBox(height: 10),
        label('Relationship to the child'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in GuardianRelationship.values)
              _Chip(
                label: r.label,
                selected: s.relationship == r,
                onTap: () => c.setRelationship(r),
              ),
          ],
        ),
        const SizedBox(height: 14),
        label('Phone (optional)'),
        VoiceTextField(
          controller: _phone,
          hint: '+264 81 000 0000',
          icon: 'consent/info',
          fieldLabel: 'Guardian phone',
          keyboardType: TextInputType.phone,
          onChanged: c.setPhone,
        ),
        const SizedBox(height: 10),
        DashboardAction(
          label: 'Guardian’s language, ${_language()}',
          onPressed: _pickLanguage,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  DashboardIcon('form/globe', color: primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guardian’s language',
                          style: dashboardText(14, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _language(),
                          style: dashboardText(13, color: AppColors.subtle),
                        ),
                      ],
                    ),
                  ),
                  const DashboardIcon(
                    'settings/chevron_down',
                    color: AppColors.subtle,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _AuthorityCheck(value: s.authorityConfirmed, onChanged: c.setAuthority),
      ],
    );
  }
}

class _Chip extends ConsumerWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: DashboardAction(
        label: label,
        radius: 19,
        color: Colors.transparent,
        onPressed: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: reduceMotion(context) ? 0 : 150),
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: selected ? primary : AppColors.line),
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
    );
  }
}

/// Amber "Researcher confirms…" check (human-only decision, logged).
class _AuthorityCheck extends StatelessWidget {
  const _AuthorityCheck({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const text =
        'Researcher confirms this person has legal authority for the child';
    return Semantics(
      checked: value,
      label: text,
      hint: 'Human-only decision, logged',
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E0),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AnimatedContainer(
                    duration: Duration(
                      milliseconds: reduceMotion(context) ? 0 : 150,
                    ),
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value ? primary : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: value ? primary : const Color(0xFFE0C9A0),
                        width: 1.5,
                      ),
                    ),
                    child: value
                        ? const PopIn(
                            child: DashboardIcon(
                              'projects/check',
                              color: Colors.white,
                              size: 20,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: dashboardText(
                          14,
                          color: const Color(0xFF7A4700),
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Human-only decision · logged',
                        style: dashboardText(
                          12,
                          color: const Color(0xFF9A5B00),
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
