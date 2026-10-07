import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';

class AnimatedNavigationBar extends StatefulWidget {
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
  State<AnimatedNavigationBar> createState() => _AnimatedNavigationBarState();
}

class _AnimatedNavigationBarState extends State<AnimatedNavigationBar>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 340);

  static const _iconCurve = Interval(0, 204 / 340, curve: Curves.easeOut);

  static const _labelCurve = Interval(
    40 / 340,
    238 / 340,
    curve: Curves.easeOut,
  );

  late final AnimationController _controller;
  final _scrollController = ScrollController();
  late List<double> _movementFrom;
  late List<double> _iconsFrom;
  late List<double> _labelsFrom;

  bool _reduceMotion = false;
  (double, double, double, int)? _lastScrollLayout;
  int _scrollRevision = 0;

  List<double> _selectedWeights(int selected) {
    return List.generate(
      widget.destinations.length,
      (index) => index == selected ? 1.0 : 0.0,
    );
  }

  List<double> _weights(List<double> from, Curve curve, int selected) {
    final progress = _reduceMotion ? 1.0 : curve.transform(_controller.value);

    return List.generate(from.length, (index) {
      final target = index == selected ? 1.0 : 0.0;
      return from[index] + (target - from[index]) * progress;
    });
  }

  void _keepSelectedPillVisible({
    required double width,
    required double visibleWidth,
    required double selectedWidth,
  }) {
    final selected = widget.selectedIndex;
    final layout = (width, visibleWidth, selectedWidth, selected);

    if (_lastScrollLayout == layout) return;

    final previous = _lastScrollLayout;
    _lastScrollLayout = layout;
    final revision = ++_scrollRevision;

    final inactiveWidth =
        (width - selectedWidth) / (widget.destinations.length - 1);
    final pillStart = selected * inactiveWidth;

    final target = (pillStart + selectedWidth / 2 - visibleWidth / 2)
        .clamp(0.0, math.max(0.0, width - visibleWidth))
        .toDouble();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _scrollRevision ||
          !_scrollController.hasClients) {
        return;
      }

      final position = _scrollController.position;
      final offset = target
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();

      if ((position.pixels - offset).abs() < 0.5) return;

      final selectionChanged = previous != null && previous.$4 != selected;

      if (selectionChanged && !_reduceMotion) {
        _scrollController.animateTo(
          offset,
          duration: _duration,
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(offset);
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: 1,
    );

    _movementFrom = _selectedWeights(widget.selectedIndex);
    _iconsFrom = List.of(_movementFrom);
    _labelsFrom = List.of(_movementFrom);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (_reduceMotion) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.destinations.length != widget.destinations.length) {
      _movementFrom = _selectedWeights(widget.selectedIndex);
      _iconsFrom = List.of(_movementFrom);
      _labelsFrom = List.of(_movementFrom);
      _controller.value = 1;
      return;
    }

    if (oldWidget.selectedIndex == widget.selectedIndex) return;

    _movementFrom = _weights(
      _movementFrom,
      Curves.easeOut,
      oldWidget.selectedIndex,
    );
    _iconsFrom = _weights(_iconsFrom, _iconCurve, oldWidget.selectedIndex);
    _labelsFrom = _weights(_labelsFrom, _labelCurve, oldWidget.selectedIndex);

    if (_reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.destinations.length;
    assert(count >= 2);

    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 588)
                .clamp(0.55, 1.0)
                .toDouble();
            final baseFontSize = 23 * scale;
            final textGrowth = (scaler.scale(baseFontSize) / baseFontSize - 1)
                .clamp(0.0, 1.0)
                .toDouble();

            final outerInset = math
                .max(8.0, (24 - 12 * textGrowth) * scale)
                .toDouble();
            final barPadding = math
                .max(4.0, (15 - 7 * textGrowth) * scale)
                .toDouble();
            final pillPadding = math
                .max(8.0, (30 - 18 * textGrowth) * scale)
                .toDouble();
            final iconLabelGap = math
                .max(4.0, (14 - 8 * textGrowth) * scale)
                .toDouble();
            final iconSize = 30 * scale;
            final capsuleWidth = constraints.maxWidth - outerInset * 2;
            final labelStyle = TextStyle(
              inherit: false,
              fontFamily: 'Inter',
              fontSize: 23 * scale,
              height: 1.2,
              fontWeight: MediaQuery.boldTextOf(context)
                  ? FontWeight.w700
                  : FontWeight.w600,
              color: AppColors.ink,
            );
            final naturalActiveWidths = <double>[];

            for (final destination in widget.destinations) {
              final painter = TextPainter(
                text: TextSpan(text: destination.$1, style: labelStyle),
                textDirection: direction,
                textScaler: scaler,
                maxLines: 1,
                locale: Localizations.maybeLocaleOf(context),
              )..layout();

              naturalActiveWidths.add(
                math
                    .max(
                      48.0,
                      painter.width.ceilToDouble() +
                          pillPadding * 2 +
                          iconSize +
                          iconLabelGap,
                    )
                    .toDouble(),
              );
              painter.dispose();
            }

            final inactiveIcons = [
              for (final destination in widget.destinations)
                AppIcon(
                  destination.$2,
                  size: 30 * scale,
                  color: Colors.white60,
                ),
            ];
            final activeWidths = naturalActiveWidths;

            final widestPill = activeWidths.reduce(
              (a, b) => math.max(a, b).toDouble(),
            );

            final visibleWidth = capsuleWidth - barPadding * 2;

            final width = math
                .max(visibleWidth, widestPill + (count - 1) * 48.0)
                .toDouble();

            _keepSelectedPillVisible(
              width: width,
              visibleWidth: visibleWidth,
              selectedWidth: activeWidths[widget.selectedIndex],
            );

            var contentHeight = math.max(48.0, 74 * scale).toDouble();

            for (var index = 0; index < count; index++) {
              final painter = TextPainter(
                text: TextSpan(
                  text: widget.destinations[index].$1,
                  style: labelStyle,
                ),
                textDirection: direction,
                textScaler: scaler,
                maxLines: 1,
                locale: Localizations.maybeLocaleOf(context),
              )..layout();

              contentHeight = math
                  .max(
                    contentHeight,
                    painter.height.ceilToDouble() + 24 * scale,
                  )
                  .toDouble();

              painter.dispose();
            }

            final selectedContents = [
              for (var index = 0; index < count; index++)
                SizedBox(
                  width: activeWidths[index],
                  height: contentHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: pillPadding),
                    child: Row(
                      children: [
                        AppIcon(
                          widget.destinations[index].$2,
                          size: iconSize,
                          color: AppColors.ink,
                        ),
                        SizedBox(width: iconLabelGap),
                        Expanded(
                          child: Text(
                            widget.destinations[index].$1,
                            style: labelStyle,
                            textScaler: scaler,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ];

            final navigation = SizedBox(
              width: width,
              height: contentHeight,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final movement = _weights(
                    _movementFrom,
                    Curves.easeOut,
                    widget.selectedIndex,
                  );
                  final icons = _weights(
                    _iconsFrom,
                    _iconCurve,
                    widget.selectedIndex,
                  );
                  final labels = _weights(
                    _labelsFrom,
                    _labelCurve,
                    widget.selectedIndex,
                  );

                  var pillStart = 0.0;
                  var pillWidth = 0.0;
                  final itemWidths = List.filled(count, 0.0);

                  for (var state = 0; state < count; state++) {
                    final inactiveWidth =
                        (width - activeWidths[state]) / (count - 1);
                    pillStart += movement[state] * state * inactiveWidth;
                    pillWidth += movement[state] * activeWidths[state];

                    for (var item = 0; item < count; item++) {
                      itemWidths[item] +=
                          movement[state] *
                          (item == state ? activeWidths[state] : inactiveWidth);
                    }
                  }

                  final starts = <double>[];
                  var position = 0.0;

                  for (final itemWidth in itemWidths) {
                    starts.add(position);
                    position += itemWidth;
                  }

                  return Stack(
                    children: [
                      PositionedDirectional(
                        start: pillStart,
                        top: 0,
                        width: pillWidth,
                        height: contentHeight,
                        child: IgnorePointer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              contentHeight / 2,
                            ),
                            child: DecoratedBox(
                              key: const ValueKey('nav-active-pill'),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                              ),
                              child: Stack(
                                children: [
                                  for (var index = 0; index < count; index++)
                                    PositionedDirectional(
                                      start: 0,
                                      top: 0,
                                      width: activeWidths[index],
                                      height: contentHeight,
                                      child: Opacity(
                                        opacity: labels[index]
                                            .clamp(0.0, 1.0)
                                            .toDouble(),
                                        child: selectedContents[index],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (var index = 0; index < count; index++)
                        PositionedDirectional(
                          start: starts[index],
                          top: 0,
                          width: itemWidths[index],
                          height: contentHeight,
                          child: IgnorePointer(
                            child: Center(
                              child: Opacity(
                                opacity: (1 - icons[index])
                                    .clamp(0.0, 1.0)
                                    .toDouble(),
                                child: inactiveIcons[index],
                              ),
                            ),
                          ),
                        ),
                      for (var index = 0; index < count; index++)
                        PositionedDirectional(
                          start: starts[index],
                          top: 0,
                          width: itemWidths[index],
                          height: contentHeight,
                          child: Semantics(
                            key: ValueKey('nav-semantics-$index'),
                            label: widget.destinations[index].$1,
                            button: true,
                            selected: index == widget.selectedIndex,
                            onTap: () => widget.onSelected(index),
                            excludeSemantics: true,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: ValueKey('nav-$index'),
                                onTap: () => widget.onSelected(index),
                                customBorder: const StadiumBorder(),
                                splashFactory: NoSplash.splashFactory,
                                highlightColor: Colors.transparent,
                                splashColor: Colors.transparent,
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: outerInset),
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1,
                child: SizedBox(
                  width: capsuleWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.navigation,
                      borderRadius: BorderRadius.circular(
                        (contentHeight + barPadding * 2) / 2,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(barPadding),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        child: navigation,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
