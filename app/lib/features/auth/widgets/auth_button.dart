import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthButton extends ConsumerStatefulWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool outlined;
  final bool busy;

  @override
  ConsumerState<AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends ConsumerState<AuthButton> {
  final _states = WidgetStatesController();

  @override
  void initState() {
    super.initState();
    _states.addListener(_update);
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _states.removeListener(_update);
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.onPressed != null && !widget.busy;
    final pressed = enabled && _states.value.contains(WidgetState.pressed);
    final colors = Theme.of(context).colorScheme;

    final style = ButtonStyle(
      backgroundColor: widget.outlined
          ? WidgetStatePropertyAll(colors.surface)
          : null,
      foregroundColor: widget.outlined
          ? WidgetStateProperty.resolveWith<Color>((states) {
              return states.contains(WidgetState.disabled)
                  ? colors.onSurface.withValues(alpha: 0.38)
                  : colors.onSurface;
            })
          : null,
      side: widget.outlined
          ? WidgetStatePropertyAll(
              BorderSide(color: colors.outline, width: 1.2),
            )
          : null,
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused) ||
            states.contains(WidgetState.hovered)) {
          return colors.primary.withValues(alpha: 0.12);
        }
        return Colors.transparent;
      }),
    );

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.busy) ...[
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.outlined
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.38),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (widget.icon != null) ...[
          widget.icon!,
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(widget.label, textAlign: TextAlign.center)),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: AnimatedScale(
        scale: pressed && !reduceMotion ? 0.97 : 1,
        duration: reduceMotion
            ? Duration.zero
            : Duration(milliseconds: pressed ? 90 : 260),
        curve: pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.outlined
            ? OutlinedButton(
                statesController: _states,
                style: style,
                onPressed: enabled ? widget.onPressed : null,
                child: content,
              )
            : FilledButton(
                statesController: _states,
                style: style,
                onPressed: enabled ? widget.onPressed : null,
                child: content,
              ),
      ),
    );
  }
}
