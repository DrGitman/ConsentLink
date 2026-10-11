import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_toggle.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../preferences/accessibility_preferences.dart';
import 'template_data.dart';

const _bg = Color(0xFF141A18);
const _panel = Color(0xFF1E2624);
const _amber = Color(0xFFF9B21B);

/// Figma 05.3 Clip logo from PDF (3:2653). Drag the box to move it, drag a
/// corner to resize. "Auto-detect edges" snaps it to the logo (animated).
/// The page is a preview: real contour detection and background removal
/// come with the file service (P4).
class ClipLogoScreen extends ConsumerStatefulWidget {
  const ClipLogoScreen({super.key});
  @override
  ConsumerState<ClipLogoScreen> createState() => _ClipLogoScreenState();
}

class _ClipLogoScreenState extends ConsumerState<ClipLogoScreen> {
  late LogoCrop _crop = ref.read(logoCropProvider) ?? detectedLogoCrop;
  bool _auto = true;
  bool _removeWhite = true;

  void _close() =>
      context.canPop() ? context.pop() : context.go('/templates/read');

  void _use() {
    ref.read(logoCropProvider.notifier).state = _crop;
    _close();
  }

  void _setAuto(bool v) {
    setState(() {
      _auto = v;
      if (v) _crop = detectedLogoCrop;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final large = ref.watch(largerTouchTargetsProvider);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 11, 20, 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _RoundButton(
                              label: 'Cancel',
                              icon: 'consent/x',
                              fill: _panel,
                              onTap: _close,
                            ),
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  'Clip logo',
                                  textAlign: TextAlign.center,
                                  style: dashboardText(
                                    17,
                                    color: Colors.white,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            _RoundButton(
                              label: 'Done',
                              icon: 'projects/check',
                              fill: primary,
                              onTap: _use,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        LayoutBuilder(
                          builder: (context, c) {
                            final w = math.min(330.0, c.maxWidth - 20);
                            return SizedBox(
                              width: w,
                              height: w * 430 / 330,
                              child: _Page(
                                crop: _crop,
                                onChanged: (crop) => setState(() {
                                  _crop = crop;
                                  _auto = false;
                                }),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          decoration: BoxDecoration(
                            color: _panel,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DarkToggle(
                                icon: 'sparkle',
                                title: 'Auto-detect edges (contour)',
                                value: _auto,
                                onChanged: _setAuto,
                              ),
                              _DarkToggle(
                                icon: 'form/image',
                                title: 'Remove white background',
                                value: _removeWhite,
                                onChanged: (v) =>
                                    setState(() => _removeWhite = v),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _removeWhite
                                    ? 'Saved as transparent PNG · used on every NUST form'
                                    : 'Saved as PNG · used on every NUST form',
                                style: dashboardText(
                                  12,
                                  color: const Color(0xFF9AA5A1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: DashboardAction(
                    label: 'Use this logo',
                    radius: 30,
                    onPressed: _use,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: large ? 72 : 60),
                      child: Center(
                        child: Text(
                          'Use this logo',
                          style: dashboardText(16, weight: FontWeight.w600),
                        ),
                      ),
                    ),
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

class _RoundButton extends ConsumerWidget {
  const _RoundButton({
    required this.label,
    required this.icon,
    required this.fill,
    required this.onTap,
  });
  final String label;
  final String icon;
  final Color fill;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    final d = large ? 64.0 : 44.0;
    return SizedBox.square(
      dimension: math.max(d, 48),
      child: Center(
        child: DashboardAction(
          label: label,
          radius: d / 2,
          color: fill,
          onPressed: onTap,
          child: SizedBox.square(
            dimension: d,
            child: Center(child: DashboardIcon(icon, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _DarkToggle extends StatelessWidget {
  const _DarkToggle({
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
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              DashboardIcon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: dashboardText(
                    14,
                    color: Colors.white,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AppToggle(value: value),
            ],
          ),
        ),
      ),
    ),
  );
}

enum _Handle { move, topLeft, topRight, bottomLeft, bottomRight }

/// The PDF page with the crop box. Positions are fractions of the page so
/// it scales with the screen.
class _Page extends StatefulWidget {
  const _Page({required this.crop, required this.onChanged});
  final LogoCrop crop;
  final ValueChanged<LogoCrop> onChanged;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  _Handle? _dragging;

  _Handle _hit(Offset p, Size s) {
    final c = widget.crop;
    final corners = {
      _Handle.topLeft: Offset(c.left * s.width, c.top * s.height),
      _Handle.topRight: Offset(c.right * s.width, c.top * s.height),
      _Handle.bottomLeft: Offset(c.left * s.width, c.bottom * s.height),
      _Handle.bottomRight: Offset(c.right * s.width, c.bottom * s.height),
    };
    for (final e in corners.entries) {
      if ((e.value - p).distance < 28) return e.key;
    }
    return _Handle.move;
  }

  void _drag(Offset delta, Size s) {
    final c = widget.crop;
    final dx = delta.dx / s.width;
    final dy = delta.dy / s.height;
    const min = .08;
    double cl(double v) => v.clamp(0.0, 1.0);
    final next = switch (_dragging) {
      _Handle.topLeft => LogoCrop(
        cl(math.min(c.left + dx, c.right - min)),
        cl(math.min(c.top + dy, c.bottom - min)),
        c.right,
        c.bottom,
      ),
      _Handle.topRight => LogoCrop(
        c.left,
        cl(math.min(c.top + dy, c.bottom - min)),
        cl(math.max(c.right + dx, c.left + min)),
        c.bottom,
      ),
      _Handle.bottomLeft => LogoCrop(
        cl(math.min(c.left + dx, c.right - min)),
        c.top,
        c.right,
        cl(math.max(c.bottom + dy, c.top + min)),
      ),
      _Handle.bottomRight => LogoCrop(
        c.left,
        c.top,
        cl(math.max(c.right + dx, c.left + min)),
        cl(math.max(c.bottom + dy, c.top + min)),
      ),
      _ => () {
        final w = c.right - c.left;
        final h = c.bottom - c.top;
        final l = (c.left + dx).clamp(0.0, 1 - w);
        final t = (c.top + dy).clamp(0.0, 1 - h);
        return LogoCrop(l, t, l + w, t + h);
      }(),
    };
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final size = c.biggest;
      return Semantics(
        label: 'PDF page 1 with the logo crop box. Drag to move or resize.',
        child: GestureDetector(
          onPanStart: (d) =>
              setState(() => _dragging = _hit(d.localPosition, size)),
          onPanUpdate: (d) => _drag(d.delta, size),
          onPanEnd: (_) => setState(() => _dragging = null),
          child: TweenAnimationBuilder<Rect?>(
            tween: RectTween(
              end: Rect.fromLTRB(
                widget.crop.left,
                widget.crop.top,
                widget.crop.right,
                widget.crop.bottom,
              ),
            ),
            // Glides when Auto-detect snaps it; follows the finger directly.
            duration: _dragging != null || reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, r, _) => CustomPaint(
              size: size,
              painter: _PagePainter(
                crop: r!,
                primary: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PagePainter extends CustomPainter {
  _PagePainter({required this.crop, required this.primary});
  final Rect crop;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 330;
    final page = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(6 * s),
    );
    canvas.drawRRect(page, Paint()..color = Colors.white);

    // Logo block and title lines (Figma 05.3).
    final logo = RRect.fromRectAndRadius(
      Rect.fromLTWH(24 * s, 22 * s, 110 * s, 64 * s),
      Radius.circular(8 * s),
    );
    canvas.drawRRect(logo, Paint()..color = primary);
    final tp = TextPainter(
      text: TextSpan(
        text: 'LOGO',
        style: dashboardText(
          14 * s,
          color: Colors.white,
          weight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, logo.center - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
    void bar(double x, double y, double w, double h, Color c) =>
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * s, y * s, w * s, h * s),
            Radius.circular(3 * s),
          ),
          Paint()..color = c,
        );
    bar(150, 30, 150, 10, const Color(0xFF2B3150));
    bar(150, 50, 110, 8, const Color(0xFFB9BEC9));
    for (var i = 0; i < 16; i++) {
      bar(24, 110 + i * 18, i % 4 == 3 ? 180 : 282, 7, const Color(0xFFD5D8DE));
    }

    // Dim everything outside the crop box.
    final box = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    final boxR = RRect.fromRectAndRadius(box, Radius.circular(4 * s));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRRect(page),
        Path()..addRRect(boxR),
      ),
      Paint()..color = Colors.black.withValues(alpha: .25),
    );
    canvas.drawRRect(
      boxR,
      Paint()
        ..color = _amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final p in [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 12, height: 12),
          const Radius.circular(3),
        ),
        Paint()..color = _amber,
      );
    }
  }

  @override
  bool shouldRepaint(_PagePainter old) =>
      old.crop != crop || old.primary != primary;
}
