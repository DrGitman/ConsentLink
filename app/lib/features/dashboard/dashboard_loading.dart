import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Figma's 1.3-second left-to-right shimmer. Only mounted while loading.
class DashboardLoading extends StatefulWidget {
  const DashboardLoading({super.key});

  @override
  State<DashboardLoading> createState() => _DashboardLoadingState();
}

class _DashboardLoadingState extends State<DashboardLoading>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context)) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _block(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.line,
      borderRadius: BorderRadius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading dashboard',
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child!;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final t = const Cubic(.5, 0, .5, 1).transform(_controller.value);
              return LinearGradient(
                colors: const [
                  Colors.transparent,
                  Color(0x88FFFFFF),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromLTWH(
                  (-180 + 690 * t) * bounds.width / 350,
                  0,
                  140,
                  bounds.height,
                ),
              );
            },
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _block(double.infinity, 44),
            const SizedBox(height: 14),
            Container(
              height: 236,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(120, 10),
                  const SizedBox(height: 12),
                  _block(90, 34),
                  const SizedBox(height: 10),
                  _block(170, 10),
                  const Spacer(),
                  SizedBox(
                    height: 90,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < 18; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: _block(double.infinity, 28 + (i % 6) * 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _block(120, 14),
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 124,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _block(40, 40),
                          const SizedBox(height: 16),
                          _block(70, 10),
                          const SizedBox(height: 10),
                          _block(50, 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            _block(130, 14),
            const SizedBox(height: 18),
            Container(
              height: 96,
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(220, 12),
                  const SizedBox(height: 12),
                  _block(140, 8),
                  const SizedBox(height: 16),
                  _block(250, 8),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
