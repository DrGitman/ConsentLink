import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_theme.dart';
import 'dashboard_chart.dart';

TextStyle dashboardText(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  height: 1.2,
  fontWeight: weight,
  letterSpacing: 0,
  color: color ?? AppColors.ink,
);

class DashboardIcon extends StatelessWidget {
  const DashboardIcon(
    this.name, {
    super.key,
    this.color = AppColors.ink,
    this.size = 22,
  });
  final String name;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    // Plain names come from the dashboard folder; 'folder/name' from others.
    name.contains('/')
        ? 'assets/icons/$name.svg'
        : 'assets/icons/dashboard/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    excludeFromSemantics: true,
  );
}

class DashboardAction extends StatefulWidget {
  const DashboardAction({
    super.key,
    required this.child,
    required this.onPressed,
    required this.label,
    this.color = Colors.white,
    this.radius = 24,
  });
  final Widget child;
  final VoidCallback onPressed;
  final String label;
  final Color color;
  final double radius;
  @override
  State<DashboardAction> createState() => _DashboardActionState();
}

class _DashboardActionState extends State<DashboardAction> {
  final _states = WidgetStatesController();
  @override
  void initState() {
    super.initState();
    _states.addListener(_changed);
  }

  var _pressed = false;
  void _changed() {
    final pressed = _states.value.contains(WidgetState.pressed);
    if (pressed && !_pressed) HapticFeedback.lightImpact();
    setState(() => _pressed = pressed);
  }

  @override
  void dispose() {
    _states.removeListener(_changed);
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .97 : 1,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 90),
    child: Semantics(
      label: widget.label,
      child: TextButton(
        statesController: _states,
        onPressed: widget.onPressed,
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          minimumSize: const WidgetStatePropertyAll(Size.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: WidgetStatePropertyAll(widget.color),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          elevation: const WidgetStatePropertyAll(0),
        ),
        child: widget.child,
      ),
    ),
  );
}

class DashboardStats extends StatelessWidget {
  const DashboardStats({super.key, required this.preview});
  final bool preview;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Consents collected',
                style: dashboardText(
                  14,
                  color: AppColors.subtle,
                  weight: FontWeight.w500,
                ),
              ),
            ),
            if (preview)
              Container(
                margin: const EdgeInsets.only(right: 18),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+18%',
                  style: dashboardText(
                    12,
                    color: AppColors.brandDark,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        Text(
          preview ? '128' : '0',
          style: dashboardText(
            48,
            weight: FontWeight.w600,
          ).copyWith(letterSpacing: -1.44),
        ),
        Text(
          preview
              ? 'across 3 projects · 96% agreed'
              : 'No consent records connected yet',
          style: dashboardText(13, color: AppColors.subtle),
        ),
        const SizedBox(height: 12),
        if (preview)
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: 76,
              child: OverflowBox(
                minWidth: constraints.maxWidth + 8,
                maxWidth: constraints.maxWidth + 8,
                child: const DashboardActivityChart(
                  values: dashboardSampleActivity,
                  semanticsLabel: 'Sample consent activity chart',
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 76,
            child: Center(
              child: Text(
                'Your activity will appear here',
                style: dashboardText(13, color: AppColors.muted),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in ['Mon', 'Wed', 'Fri'])
              Text(
                label,
                style: dashboardText(
                  12,
                  color: AppColors.subtle,
                  weight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
