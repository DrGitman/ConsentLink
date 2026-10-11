import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import 'form_builder_data.dart';

/// Figma Screen Artboards 04.6 Add question (bottom sheet).
///
/// Figma: title 22 semibold, 3 × 4 grid of 106 × 90 tiles (radius 20, canvas
/// fill, 10 dp gaps, 24 dp side padding); each tile has a 38 dp white icon
/// circle at (14, 12) and a 13 semibold label below; a 13 regular tip at the
/// end. The sheet rises with a slight overshoot (Animations: sheet & dialog).
Future<FieldType?> showAddQuestionSheet(BuildContext context) =>
    showModalBottomSheet<FieldType>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      sheetAnimationStyle: sheetMotion(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _AddQuestionSheet(),
    );

class _AddQuestionSheet extends StatelessWidget {
  const _AddQuestionSheet();
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const types = FieldType.pickable;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Add a question',
                  style: dashboardText(22, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 23),
              for (var row = 0; row < types.length; row += 3) ...[
                if (row > 0) const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = row; i < row + 3; i++) ...[
                        if (i > row) const SizedBox(width: 10),
                        Expanded(
                          child: RiseIn(
                            child: _TypeTile(
                              type: types[i],
                              primary: primary,
                              onTap: () => Navigator.pop(context, types[i]),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 26),
              Text(
                'Tip: keep participant questions to the minimum your ethics approval allows.',
                style: dashboardText(13, color: AppColors.subtle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.primary,
    required this.onTap,
  });
  final FieldType type;
  final Color primary;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => DashboardAction(
    label: 'Add ${type.pickerLabel}',
    radius: 20,
    color: AppColors.canvas,
    onPressed: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 90),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: DashboardIcon(type.icon, color: primary, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              type.pickerLabel,
              style: dashboardText(13, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}
