import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/app_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';

class AnimatedNavigationBar extends StatelessWidget {
  const AnimatedNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<(String, AppIconType)> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final movementDuration = reduceMotion ? Duration.zero : AppMotion.base;
    final fadeDuration = reduceMotion ? AppMotion.reduced : AppMotion.fast;

    final labelStyle = TextStyle(
      inherit: false,
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: MediaQuery.boldTextOf(context)
          ? FontWeight.w700
          : FontWeight.w600,
      letterSpacing: 0,
      height: 1.2,
    );

    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.navigation,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Every inactive destination retains a 48 dp touch target.
              // Extremely narrow windows can scroll the navigation.
              final width = math.max(
                constraints.maxWidth,
                destinations.length * 48.0 + 24,
              );

              final maximumActiveWidth = width - (destinations.length - 1) * 48;

              final activeWidths = <double>[];
              var height = 48.0;

              for (final destination in destinations) {
                final painter = TextPainter(
                  text: TextSpan(text: destination.$1, style: labelStyle),
                  textDirection: textDirection,
                  textScaler: textScaler,
                  locale: Localizations.maybeLocaleOf(context),
                  textWidthBasis: TextWidthBasis.parent,
                )..layout();

                // Reserve enough space for the active icon, label, and horizontal
                // padding so longer labels like "Insights" do not clip as the pill
                // animates between destinations.
                final activeWidth =
                    (painter.maxIntrinsicWidth.ceilToDouble() + 72)
                        .clamp(72.0, maximumActiveWidth)
                        .toDouble();

                painter.layout(maxWidth: math.max(1, activeWidth - 56));

                // Grow vertically when large text wraps on a small phone.
                height = math.max(height, painter.height + 24);
                activeWidths.add(activeWidth);
                painter.dispose();
              }

              final activeWidth = activeWidths[selectedIndex];
              final inactiveWidth =
                  (width - activeWidth) / (destinations.length - 1);

              final widths = [
                for (var index = 0; index < destinations.length; index++)
                  index == selectedIndex ? activeWidth : inactiveWidth,
              ];

              final starts = <double>[];
              var offset = 0.0;

              for (final itemWidth in widths) {
                starts.add(offset);
                offset += itemWidth;
              }

              final navigation = SizedBox(
                width: width,
                height: height,
                child: Stack(
                  children: [
                    if (!reduceMotion)
                      AnimatedPositionedDirectional(
                        duration: movementDuration,
                        curve: AppMotion.baseCurve,
                        start: starts[selectedIndex],
                        top: 0,
                        bottom: 0,
                        width: activeWidth,
                        child: DecoratedBox(
                          key: const ValueKey('nav-active-pill'),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    for (var index = 0; index < destinations.length; index++)
                      AnimatedPositionedDirectional(
                        key: ValueKey('nav-position-$index'),
                        duration: movementDuration,
                        curve: AppMotion.baseCurve,
                        start: starts[index],
                        top: 0,
                        bottom: 0,
                        width: widths[index],
                        child: _NavigationTarget(
                          index: index,
                          label: destinations[index].$1,
                          icon: destinations[index].$2,
                          selected: index == selectedIndex,
                          reduceMotion: reduceMotion,
                          movementDuration: movementDuration,
                          fadeDuration: fadeDuration,
                          labelStyle: labelStyle,
                          onTap: () => onSelected(index),
                        ),
                      ),
                  ],
                ),
              );

              if (width > constraints.maxWidth) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: navigation,
                );
              }

              return navigation;
            },
          ),
        ),
      ),
    );
  }
}

class _NavigationTarget extends StatelessWidget {
  const _NavigationTarget({
    required this.index,
    required this.label,
    required this.icon,
    required this.selected,
    required this.reduceMotion,
    required this.movementDuration,
    required this.fadeDuration,
    required this.labelStyle,
    required this.onTap,
  });

  final int index;
  final String label;
  final AppIconType icon;
  final bool selected;
  final bool reduceMotion;
  final Duration movementDuration;
  final Duration fadeDuration;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.ink : Colors.white;

    return Semantics(
      key: ValueKey('nav-semantics-$index'),
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Reduce Motion uses a local fade rather than a sliding pill.
          if (reduceMotion)
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: fadeDuration,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('nav-$index'),
              borderRadius: BorderRadius.circular(24),
              onTap: onTap,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: AnimatedAlign(
                        alignment: selected
                            ? AlignmentDirectional.centerStart
                            : AlignmentDirectional.center,
                        duration: movementDuration,
                        curve: AppMotion.baseCurve,
                        child: AppIcon(icon, color: foreground),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 44,
                    end: 12,
                    top: 0,
                    bottom: 0,
                    child: ClipRect(
                      child: AnimatedOpacity(
                        opacity: selected ? 1 : 0,
                        duration: fadeDuration,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: RichText(
                            text: TextSpan(
                              text: label,
                              style: labelStyle.copyWith(color: AppColors.ink),
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                            locale: Localizations.maybeLocaleOf(context),
                            textWidthBasis: TextWidthBasis.parent,
                            softWrap: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
