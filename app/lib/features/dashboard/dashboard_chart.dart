import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Preview-only sample activity, taken from the Figma 03.1 bar heights.
/// Not real consent records.
const dashboardSampleActivity = <double>[
  26.6, 33.1, 39.4, 45.3, 50.7, 55.3, 59.1, 61.9, 63.6, 64.3, //
  63.9, 62.4, 59.9, 56.5, 52.3, 47.4, 42.1, 36.5, 36.6, 43.0, //
  49.2, 54.8, 59.9, 64.1, 67.4, 69.7, 71.0, 71.1, 70.2, 68.2,
];

/// Bar chart drawn from [values]; bars fade from a 50% tint of the
/// institution primary (shortest) to the primary itself (tallest), as in Figma.
class DashboardActivityChart extends StatelessWidget {
  const DashboardActivityChart({
    super.key,
    required this.values,
    required this.semanticsLabel,
  });
  final List<double> values;
  final String semanticsLabel;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    image: true,
    child: CustomPaint(
      size: Size.infinite,
      painter: _BarsPainter(values, Theme.of(context).colorScheme.primary),
    ),
  );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final top = values.reduce(math.max);
    final low = values.reduce(math.min);
    if (top <= 0) return;
    final light = Color.alphaBlend(color.withValues(alpha: .5), Colors.white);
    // Figma: 6.36 bar in a 10.6 pitch, tallest bar ~94% of the 76 px height.
    final pitch = size.width / values.length;
    final width = pitch * .6;
    final paint = Paint();
    for (var i = 0; i < values.length; i++) {
      final height = values[i] / top * size.height * .94;
      paint.color = Color.lerp(
        light,
        color,
        top == low ? 1 : (values[i] - low) / (top - low),
      )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * pitch + pitch * .2,
            size.height - height,
            width,
            height,
          ),
          Radius.circular(width / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.color != color || old.values != values;
}
