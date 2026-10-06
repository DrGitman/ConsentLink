import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum AppIconType { home, folder, mic, chart, user }

class AppIcon extends StatelessWidget {
  const AppIcon(this.type, {this.color, this.size = 24, super.key});

  final AppIconType type;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.black;

    return ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/icons/navigation/${type.name}.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      ),
    );
  }
}
