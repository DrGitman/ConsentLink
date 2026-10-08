import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/preferences/accessibility_preferences.dart';

class AppBackButton extends ConsumerStatefulWidget {
  const AppBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Back',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  ConsumerState<AppBackButton> createState() => _AppBackButtonState();
}

class _AppBackButtonState extends ConsumerState<AppBackButton> {
  static const _svg = '''
<svg width="44" height="44" viewBox="0 0 44 44" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="44" height="44" rx="22" fill="white"/>
  <path d="M24.75 27.5L19.25 22L24.75 16.5" stroke="#111614" stroke-width="1.74167" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final largerTargets = ref.watch(largerTouchTargetsProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final size = largerTargets ? 64.0 : 48.0;
    final enabled = widget.onPressed != null;

    return Tooltip(
      message: widget.tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onPressed,
          onHighlightChanged: (pressed) {
            if (_pressed != pressed) {
              setState(() => _pressed = pressed);
            }
          },
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: SizedBox.square(
            dimension: size,
            child: Semantics(
              button: true,
              enabled: enabled,
              label: widget.tooltip,
              child: Center(
                child: AnimatedScale(
                  scale: _pressed && enabled && !reduceMotion ? 0.9 : 1,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Transform.scale(
                      scaleX: rtl ? -1 : 1,
                      child: SvgPicture.string(
                        _svg,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
