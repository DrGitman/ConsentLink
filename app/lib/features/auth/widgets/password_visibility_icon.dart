import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PasswordVisibilityIcon extends StatelessWidget {
  const PasswordVisibilityIcon({
    super.key,
    required this.obscured,
    required this.color,
  });

  final bool obscured;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 22,
      child: CustomPaint(
        foregroundPainter: obscured ? null : _EyeSlashPainter(color),
        child: SvgPicture.asset(
          'assets/icons/auth/eye.svg',
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class _EyeSlashPainter extends CustomPainter {
  const _EyeSlashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.14, size.height * 0.14),
      Offset(size.width * 0.86, size.height * 0.86),
      paint,
    );
  }

  @override
  bool shouldRepaint(_EyeSlashPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
