import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/app_toggle.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../preferences/accessibility_preferences.dart';
import 'responses_data.dart';
import 'responses_widgets.dart';

/// Figma 07.4 Export (3:3561): rises with a slight overshoot over a 45% scrim.
/// In the preview nothing is written: the export is logged and a toast says
/// no file was created.
Future<void> showExportSheet(
  BuildContext context, {
  required String subtitle,
  required int count,
}) async {
  final log = await showModalBottomSheet<ExportLog>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    // Over the tab bar too, like Figma 07.4.
    useRootNavigator: true,
    backgroundColor: Colors.white,
    barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
    sheetAnimationStyle: sheetMotion(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => ExportSheet(subtitle: subtitle, count: count),
  );
  if (log == null || !context.mounted) return;
  showOverlayToast(
    context,
    kind: AppToastKind.success,
    title: 'Export ready · ${exportLabel(log.format, log.count)}',
    subtitle: 'Preview only: no file was saved. Logged in the audit trail.',
  );
}

String exportLabel(ExportFormat format, int count) => switch (format) {
  ExportFormat.pdf => count == 1 ? '1 PDF' : '$count PDFs (.zip)',
  ExportFormat.word => count == 1 ? '1 Word file' : '$count Word files (.zip)',
  ExportFormat.csv => count == 1 ? '1 row (.csv)' : '$count rows (.csv)',
};

class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key, required this.subtitle, required this.count});
  final String subtitle;
  final int count;
  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  ExportFormat _format = ExportFormat.pdf;
  bool _logo = true;
  bool _bothLanguages = true;
  bool _password = false;
  bool _working = false;
  double _pull = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _export() {
    setState(() => _working = true);
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final log = ExportLog(DateTime.now(), _format, widget.count);
      final logs = ref.read(exportLogProvider);
      ref.read(exportLogProvider.notifier).state = [...logs, log];
      Navigator.pop(context, log);
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(insightsPreviewProvider);
    final canExport = preview && widget.count > 0 && !_working;
    // The content scrolls on small screens, which would swallow the sheet's
    // own drag. Pulling down past the top (or flinging down) closes it.
    return NotificationListener<OverscrollNotification>(
      onNotification: (n) {
        if (n.dragDetails != null && n.overscroll < 0) {
          _pull -= n.overscroll;
          if (_pull > 48 && !_working) {
            _pull = 0;
            Navigator.maybePop(context);
          }
        }
        return false;
      },
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (_) {
          _pull = 0;
          return false;
        },
        child: _content(context, preview, canExport),
      ),
    );
  }

  Widget _content(BuildContext context, bool preview, bool canExport) {
    return SingleChildScrollView(
      // Not the primary scroller (that made it always scrollable and took
      // every drag from the sheet). Clamping, so pulling down at the top
      // reports overscroll when the content is taller than the screen.
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 19),
          Semantics(
            header: true,
            child: Text(
              'Export',
              style: dashboardText(22, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            preview ? widget.subtitle : 'No records on this phone yet',
            style: dashboardText(14, color: AppColors.subtle),
          ),
          const SizedBox(height: 17),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in ExportFormat.values) ...[
                if (f != ExportFormat.values.first) const SizedBox(width: 10),
                Expanded(
                  child: _FormatTile(
                    format: f,
                    selected: _format == f,
                    onTap: () => setState(() => _format = f),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _OptionRow(
                  icon: 'form/image',
                  title: 'Include institution logo',
                  value: _logo,
                  onChanged: (v) => setState(() => _logo = v),
                ),
                const SizedBox(height: 2),
                _OptionRow(
                  icon: 'form/globe',
                  title: 'Both languages side by side',
                  value: _bothLanguages,
                  onChanged: (v) => setState(() => _bothLanguages = v),
                ),
                const SizedBox(height: 2),
                _OptionRow(
                  icon: 'form/lock',
                  title: 'Password-protect file',
                  value: _password,
                  onChanged: (v) => setState(() => _password = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: Duration(milliseconds: reduceMotion(context) ? 150 : 250),
            child: _working
                ? _Preparing(key: const ValueKey('working'))
                : ConsentPillButton(
                    key: ValueKey(_format),
                    label: 'Export ${exportLabel(_format, widget.count)}',
                    icon: 'projects/download',
                    height: 58,
                    onPressed: canExport ? _export : null,
                  ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Text(
              'Exports are logged in the audit trail.',
              textAlign: TextAlign.center,
              style: dashboardText(12, color: AppColors.subtle),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Preparing extends StatelessWidget {
  const _Preparing({super.key});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      liveRegion: true,
      label: 'Preparing export',
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(29),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Preparing…',
              style: dashboardText(
                16,
                color: Colors.white,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatTile extends ConsumerWidget {
  const _FormatTile({
    required this.format,
    required this.selected,
    required this.onTap,
  });
  final ExportFormat format;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final large = ref.watch(largerTouchTargetsProvider);
    final (fill, ink) = switch (format) {
      ExportFormat.pdf => (const Color(0xFFFDECEC), AppColors.error),
      ExportFormat.word => (const Color(0xFFEAF1FF), AppColors.info),
      ExportFormat.csv => (AppColors.brand50, AppColors.brandDark),
    };
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: DashboardAction(
        label: '${format.label}, ${format.subtitle}',
        radius: 20,
        color: Colors.transparent,
        onPressed: onTap,
        child: AnimatedContainer(
          duration: reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          height: large ? 132 : 120,
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? primary : AppColors.canvas,
              width: 2,
            ),
          ),
          // Figma: icon 14 from the corner, label and subtitle on one line
          // each at the bottom; the border sits inside so nothing shifts.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DashboardIcon(format.icon, color: ink),
              ),
              const Spacer(),
              _OneLine(
                format.label,
                style: dashboardText(15, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              _OneLine(
                format.subtitle,
                style: dashboardText(11, color: AppColors.subtle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line that shrinks to fit instead of wrapping, so the three tiles
/// stay identical (Figma) even with bigger phone text.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text, {required this.style});
  final String text;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, style: style),
    ),
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: title,
    onTap: () => onChanged(!value),
    child: ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
                  child: Text(
                    title,
                    style: dashboardText(16, weight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 12),
                AppToggle(value: value),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
