import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../projects/project_widgets.dart';
import '../settings/settings_widgets.dart';
import 'minors_data.dart';

/// Figma 10.1 Project setting — includes minors (3:6855). Turning it on
/// adds the age check, guardian consent and child assent to field capture.
class MinorsSettingsScreen extends ConsumerWidget {
  const MinorsSettingsScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s =
        ref.watch(minorsSettingsProvider)[projectId] ?? const MinorsSettings();
    void update(MinorsSettings Function(MinorsSettings) f) =>
        ref.read(minorsSettingsProvider.notifier).update(projectId, f);
    final primary = Theme.of(context).colorScheme.primary;
    final reduced = reduceMotion(context);

    Widget dimmed(Widget child) => AnimatedOpacity(
      duration: Duration(milliseconds: reduced ? 0 : 200),
      opacity: s.includesMinors ? 1 : .45,
      child: IgnorePointer(ignoring: !s.includesMinors, child: child),
    );

    return SettingsPage(
      title: 'Participants',
      fallback: '/projects/$projectId',
      children: [
        const SizedBox(height: 2),
        SettingsCard(
          children: [
            SettingsToggleRow(
              icon: 'capture/users',
              title: 'Includes under-18s',
              subtitle: 'Turns on guardian + assent flow',
              minHeight: 60,
              value: s.includesMinors,
              onChanged: (v) => update((x) => x.copyWith(includesMinors: v)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        dimmed(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ethics approval for minors',
                  style: dashboardText(15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                if (s.ethicsNote != null)
                  ProjectBadge(
                    label: s.ethicsNote!,
                    icon: 'projects/shield',
                    fill: AppColors.brand50,
                    ink: AppColors.brandDark,
                  )
                else
                  const ProjectBadge(
                    label: 'No approval for minors on file',
                    icon: 'consent/alert',
                    fill: Color(0xFFFEF4E2),
                    ink: Color(0xFF9A5B00),
                  ),
                const SizedBox(height: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 44),
                    alignment: Alignment.centerLeft,
                    overlayColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                  ),
                  onPressed: () => showProjectNotice(
                    context,
                    'Upload approval letter',
                    'Letters are stored with the project once project '
                        'storage is connected. Nothing was uploaded.',
                  ),
                  child: Text(
                    'Upload approval letter',
                    style: dashboardText(
                      14,
                      color: primary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Required before collecting from minors',
                  style: dashboardText(12, color: AppColors.subtle),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        dimmed(const SettingsLabel('Age groups & forms')),
        const SizedBox(height: 7),
        dimmed(
          SettingsCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            children: [
              for (final band in AgeBand.values) ...[
                if (band != AgeBand.values.first)
                  const Divider(height: 1, thickness: 1, color: AppColors.line),
                _BandRow(
                  band: band,
                  on:
                      band == AgeBand.adult ||
                      (band == AgeBand.child ? s.childBand : s.teenBand),
                  onTap: band == AgeBand.adult
                      ? null
                      : () => update(
                          (x) => band == AgeBand.child
                              ? x.copyWith(childBand: !x.childBand)
                              : x.copyWith(teenBand: !x.teenBand),
                        ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        dimmed(
          SettingsCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            children: [
              SettingsToggleRow(
                icon: 'projects/shield',
                title: 'Guardian must be present',
                minHeight: 56,
                value: s.guardianPresent,
                onChanged: (v) => update((x) => x.copyWith(guardianPresent: v)),
              ),
              SettingsToggleRow(
                icon: 'researcher/file',
                title: 'School / gatekeeper permission',
                minHeight: 56,
                value: s.gatekeeper,
                onChanged: (v) => update((x) => x.copyWith(gatekeeper: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "7–11 · Picture + audio assent · On/Off". 18+ is always on.
class _BandRow extends StatelessWidget {
  const _BandRow({required this.band, required this.on, required this.onTap});
  final AgeBand band;
  final bool on;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(
                band.label,
                style: dashboardText(
                  16,
                  color: primary,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                band.form,
                style: dashboardText(14, weight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: Duration(
                milliseconds: reduceMotion(context) ? 150 : 250,
              ),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: Tween(begin: .8, end: 1.0).animate(a),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: on
                  ? const ProjectBadge(
                      key: ValueKey('on'),
                      label: 'On',
                      fill: AppColors.brand50,
                      ink: AppColors.brandDark,
                    )
                  : const ProjectBadge(
                      key: ValueKey('off'),
                      label: 'Off',
                      fill: AppColors.canvas,
                      ink: AppColors.subtle,
                    ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      toggled: on,
      label: '${band.label}, ${band.form}',
      hint: onTap == null ? 'Always on' : null,
      child: onTap == null
          ? ExcludeSemantics(child: row)
          : DashboardAction(
              label: '${band.label}, ${band.form}',
              radius: 14,
              color: Colors.transparent,
              onPressed: onTap!,
              child: row,
            ),
    );
  }
}
