import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../dashboard/dashboard_components.dart';
import '../projects/project_widgets.dart';
import 'consent_draft_data.dart';
import 'consent_widgets.dart';

const _danger = Color(0xFFE5484D);
const _dangerFill = Color(0xFFFDECEC);
const _dangerInk = Color(0xFF8E2B2E);

/// Figma Screen Artboards 04.1 Upload proposal.
class UploadProposalScreen extends ConsumerStatefulWidget {
  const UploadProposalScreen({super.key});
  @override
  ConsumerState<UploadProposalScreen> createState() =>
      _UploadProposalScreenState();
}

class _UploadProposalScreenState extends ConsumerState<UploadProposalScreen> {
  @override
  void initState() {
    super.initState();
    // Each visit starts a fresh draft.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(consentDraftProvider.notifier).reset();
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _pick() async {
    if (!ref.read(newConsentPreviewProvider)) {
      await showProjectNotice(
        context,
        'Upload a document',
        'Choosing a file or taking a photo will be connected together with the file safety scan. Nothing has been uploaded.',
      );
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      sheetAnimationStyle: reduceMotion(context)
          ? const AnimationStyle(duration: Duration(milliseconds: 150))
          : const AnimationStyle(
              duration: Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
            ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preview: pick a sample file',
                style: dashboardText(18, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Sample files only. Nothing is read or uploaded.',
                style: dashboardText(13, color: AppColors.subtle),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Opuwo_water_proposal_v3.pdf'),
                subtitle: const Text('A safe 18-page proposal'),
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('survey_tool.exe'),
                subtitle: const Text('A program file that must be blocked'),
                onTap: () => Navigator.pop(context, 'exe'),
              ),
            ],
          ),
        ),
      ),
    );
    final notifier = ref.read(consentDraftProvider.notifier);
    if (choice == 'pdf') notifier.pickSampleProposal();
    if (choice == 'exe') notifier.pickSampleBlockedFile();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(consentDraftProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final tint = institutionTint(ref, context);

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConsentTopBar(
                          leading: AppBackButton(onPressed: _back),
                          title: 'New consent form',
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Start from your research paper or proposal',
                          style: dashboardText(20, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        _DropZone(onTap: _pick, tint: tint, primary: primary),
                        AnimatedSize(
                          duration: reduceMotion(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: Column(
                            children: [
                              if (draft.file != null) ...[
                                const SizedBox(height: 16),
                                RiseIn(child: _FileCard(file: draft.file!)),
                              ],
                              if (draft.blocked != null) ...[
                                const SizedBox(height: 12),
                                RiseIn(
                                  key: ValueKey(draft.blocked!.name),
                                  child: ShakeOnce(
                                    child: _BlockedCard(
                                      file: draft.blocked!,
                                      onDismiss: ref
                                          .read(consentDraftProvider.notifier)
                                          .dismissBlocked,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No document yet?',
                          style: dashboardText(
                            14,
                            color: AppColors.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DashboardAction(
                          label: 'Describe your study by voice or text',
                          onPressed: () => showProjectNotice(
                            context,
                            'Describe your study',
                            'The six guided questions (by voice or text) will be connected with the on-device AI.',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: tint,
                                    shape: BoxShape.circle,
                                  ),
                                  child: DashboardIcon('mic', color: primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Describe your study by voice or text',
                                        style: dashboardText(
                                          14,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'The assistant asks 6 short questions',
                                        style: dashboardText(
                                          12,
                                          color: AppColors.subtle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: ConsentPillButton(
                    icon: 'sparkle',
                    label: 'Analyse with on-device AI',
                    onPressed: draft.canAnalyse
                        ? () => context.push('/new-consent/drafting')
                        : null,
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

class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.onTap,
    required this.tint,
    required this.primary,
  });
  final VoidCallback onTap;
  final Color tint;
  final Color primary;
  @override
  Widget build(BuildContext context) => DashboardAction(
    label: 'Tap to upload or take a photo',
    color: Color.lerp(Colors.white, tint, .35)!,
    onPressed: onTap,
    child: CustomPaint(
      painter: _DashedBorder(color: Color.lerp(tint, primary, .3)!, radius: 24),
      child: Padding(
        // Figma Drop zone 350 × 170.
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 41),
        child: Column(
          children: [
            _UploadIcon(tint: tint, primary: primary),
            const SizedBox(height: 8),
            Text(
              'Tap to upload or take a photo',
              textAlign: TextAlign.center,
              style: dashboardText(15, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'PDF · DOCX · ODT · TXT · JPG/PNG scans · max 25 MB',
              textAlign: TextAlign.center,
              style: dashboardText(12, color: AppColors.subtle),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});
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
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.file});
  final UploadedFile file;
  @override
  Widget build(BuildContext context) {
    final Widget status = switch (file.status) {
      UploadStatus.uploading => Row(
        key: const ValueKey('uploading'),
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: file.progress,
                minHeight: 6,
                backgroundColor: AppColors.line,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('Uploading', style: dashboardText(12, color: AppColors.subtle)),
        ],
      ),
      UploadStatus.scanning => Row(
        key: const ValueKey('scanning'),
        children: [
          SizedBox.square(
            dimension: 14,
            child: reduceMotion(context)
                ? const Icon(Icons.more_horiz, size: 14)
                : const CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Scanning for safety…',
            style: dashboardText(12, color: AppColors.subtle),
          ),
        ],
      ),
      _ => Align(
        key: const ValueKey('safe'),
        alignment: AlignmentDirectional.centerStart,
        child: PopIn(
          child: ProjectBadge(
            icon: 'projects/shield',
            label: 'Scanned · safe · ${file.pages} pages',
            fill: AppColors.brand50,
            ink: AppColors.brandDark,
          ),
        ),
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _dangerFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                file.extension,
                textScaler: TextScaler.noScaling,
                style: dashboardText(
                  12,
                  color: _danger,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: dashboardText(14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 7),
                  AnimatedSwitcher(
                    duration: Duration(
                      milliseconds: reduceMotion(context) ? 150 : 250,
                    ),
                    child: status,
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

class _BlockedCard extends StatelessWidget {
  const _BlockedCard({required this.file, required this.onDismiss});
  final UploadedFile file;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: TweenAnimationBuilder<Color?>(
      // Arrives neutral, then turns red (Figma "turns red").
      tween: ColorTween(
        begin: reduceMotion(context) ? _dangerFill : Colors.white,
        end: _dangerFill,
      ),
      duration: const Duration(milliseconds: 250),
      builder: (context, fill, child) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(24),
        ),
        child: child,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const DashboardIcon('consent/alert', color: _danger),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${file.name} was blocked',
                  style: dashboardText(
                    14,
                    color: _danger,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Programs, scripts (.exe .apk .bat .js) and macro documents (.docm) can’t be uploaded.',
                  style: dashboardText(12, color: _dangerInk),
                ),
              ],
            ),
          ),
          // No grey press overlay: same press scale as other buttons.
          SizedBox.square(
            dimension: 48,
            child: DashboardAction(
              label: 'Dismiss',
              radius: 24,
              color: Colors.transparent,
              onPressed: onDismiss,
              child: const Center(
                child: DashboardIcon('consent/x', color: _dangerInk, size: 18),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Drop-zone icon: the arrow lifts and settles while a soft ring pulses,
/// looping while the screen is visible. Static with Reduce motion.
class _UploadIcon extends StatefulWidget {
  const _UploadIcon({required this.tint, required this.primary});
  final Color tint;
  final Color primary;
  @override
  State<_UploadIcon> createState() => _UploadIconState();
}

class _UploadIconState extends State<_UploadIcon>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context) || !TickerMode.of(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 60,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // Arrow: up 4 dp in the first half, back down in the second.
        final lift = Curves.easeInOut.transform(t < .5 ? t * 2 : 2 - t * 2);
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1 - t) * .8,
              child: Container(
                width: 48 + 12 * t,
                height: 48 + 12 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.tint, width: 2),
                ),
              ),
            ),
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.tint,
                shape: BoxShape.circle,
              ),
              child: Transform.translate(
                offset: Offset(0, -4 * lift),
                child: DashboardIcon('consent/upload', color: widget.primary),
              ),
            ),
          ],
        );
      },
    ),
  );
}
