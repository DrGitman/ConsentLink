import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import 'accessibility_preferences.dart';

class LanguageAccessibilityScreen extends ConsumerStatefulWidget {
  const LanguageAccessibilityScreen({super.key});

  @override
  ConsumerState<LanguageAccessibilityScreen> createState() =>
      _LanguageAccessibilityScreenState();
}

class _LanguageAccessibilityScreenState
    extends ConsumerState<LanguageAccessibilityScreen> {
  double? _dragTextScale;
  TextScaler? _dragTextScaler;
  final _preferencesListKey = GlobalKey<_AnchoredPreferencesListState>();
  final _textSizeCardKey = GlobalKey();

  static const _languageRows = [
    ['English', 'Afrikaans', 'Deutsch'],
    ['Otjiherero', 'Khoekhoegowab'],
    ['Rukwangali', 'Silozi', 'Oshiwambo'],
  ];

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(selectedAppLanguageProvider);
    final appliedTextScale = ref.watch(appTextScaleProvider);
    final textScale = _dragTextScale ?? appliedTextScale;
    final liveTextScaler = MediaQuery.textScalerOf(context);
    final highContrast = ref.watch(highContrastProvider);
    final readAloud = ref.watch(readScreensAloudProvider);
    final voiceAnswers = ref.watch(voiceAnswersProvider);
    final largerTargets = ref.watch(largerTouchTargetsProvider);

    final primary = Theme.of(context).colorScheme.primary;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 120);

    final border = highContrast
        ? Border.all(color: AppColors.ink, width: 2)
        : null;

    Widget card(Widget child, {Key? key}) {
      final isTextSizeCard = key == _textSizeCardKey;

      return Container(
        key: key,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: border,
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: isTextSizeCard && _dragTextScaler != null
                ? _dragTextScaler!
                : MediaQuery.textScalerOf(context),
          ),
          child: child,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              children: [
                Expanded(
                  child: _AnchoredPreferencesList(
                    key: _preferencesListKey,
                    anchorChildKey: _textSizeCardKey,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Make it comfortable',
                          style: TextStyle(
                            fontSize: 30,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.9,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Change any of this later in Settings.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        header: true,
                        child: Text(
                          'App language',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final row in _languageRows)
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final name in row)
                              _LanguageChip(
                                label: name,
                                selected: name == language,
                                primary: primary,
                                highContrast: highContrast,
                                largerTargets: largerTargets,
                                onPressed: () {
                                  ref
                                          .read(
                                            selectedAppLanguageProvider
                                                .notifier,
                                          )
                                          .state =
                                      name;
                                },
                              ),
                          ],
                        ),
                      const SizedBox(height: 18),
                      card(
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LiveSliderText(
                                'Text size',
                                liveTextScaler: liveTextScaler,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  textScaler:
                                      _dragTextScaler ??
                                      MediaQuery.textScalerOf(context),
                                ),
                                child: Row(
                                  children: [
                                    ExcludeSemantics(
                                      child: _LiveSliderText(
                                        'Aa',
                                        liveTextScaler: liveTextScaler,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.subtle,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: SizedBox(
                                        height: largerTargets ? 72 : 64,
                                        child: _SliderGestureArea(
                                          child: SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              trackHeight: 6,
                                              trackShape:
                                                  const _EvenRoundedSliderTrack(),
                                              activeTrackColor: primary,
                                              inactiveTrackColor:
                                                  AppColors.line,
                                              activeTickMarkColor:
                                                  Colors.transparent,
                                              inactiveTickMarkColor:
                                                  Colors.transparent,
                                              thumbColor: Colors.white,
                                              thumbShape: _OutlinedSliderThumb(
                                                outline: primary,
                                              ),
                                              overlayShape: SliderComponentShape
                                                  .noOverlay,
                                              showValueIndicator:
                                                  ShowValueIndicator.never,
                                            ),
                                            child: Slider(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              value: textScale,
                                              min: 1,
                                              max: 1.6,
                                              semanticFormatterCallback: (value) {
                                                return 'Text size '
                                                    '${(value * 100).round()} '
                                                    'percent';
                                              },
                                              allowedInteraction:
                                                  SliderInteraction.tapAndSlide,
                                              onChangeStart: (value) {
                                                _preferencesListKey.currentState
                                                    ?.anchorToSlider();

                                                final scaler =
                                                    MediaQuery.textScalerOf(
                                                      context,
                                                    );

                                                setState(() {
                                                  _dragTextScaler = scaler;
                                                  _dragTextScale = value;
                                                });
                                              },
                                              onChanged: (value) {
                                                setState(() {
                                                  _dragTextScale = value;
                                                });

                                                final preview =
                                                    (value * 100).round() / 100;

                                                if (ref.read(
                                                      appTextScaleProvider,
                                                    ) !=
                                                    preview) {
                                                  ref
                                                          .read(
                                                            appTextScaleProvider
                                                                .notifier,
                                                          )
                                                          .state =
                                                      preview;
                                                }
                                              },
                                              onChangeEnd: (value) {
                                                final finalScale =
                                                    (value * 100).round() / 100;

                                                if (ref.read(
                                                      appTextScaleProvider,
                                                    ) !=
                                                    finalScale) {
                                                  ref
                                                          .read(
                                                            appTextScaleProvider
                                                                .notifier,
                                                          )
                                                          .state =
                                                      finalScale;
                                                }

                                                setState(() {
                                                  _dragTextScale = null;
                                                  _dragTextScaler = null;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    ExcludeSemantics(
                                      child: _LiveSliderText(
                                        'Aa',
                                        liveTextScaler: liveTextScaler,
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _LiveSliderText(
                                '${(textScale * 100).round()}%',
                                liveTextScaler: liveTextScaler,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        key: _textSizeCardKey,
                      ),
                      const SizedBox(height: 16),
                      card(
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Column(
                            children: [
                              _PreferenceRow(
                                icon: 'volume',
                                title: 'Read screens aloud',
                                subtitle: 'Speaks every page and field',
                                value: readAloud,
                                duration: duration,
                                primary: primary,
                                largerTargets: largerTargets,
                                onChanged: (value) {
                                  ref
                                          .read(
                                            readScreensAloudProvider.notifier,
                                          )
                                          .state =
                                      value;
                                },
                              ),
                              _PreferenceRow(
                                icon: 'eye',
                                title: 'High contrast',
                                subtitle: 'Stronger colours and borders',
                                value: highContrast,
                                duration: duration,
                                primary: primary,
                                largerTargets: largerTargets,
                                onChanged: (value) {
                                  ref
                                          .read(highContrastProvider.notifier)
                                          .state =
                                      value;
                                },
                              ),
                              _PreferenceRow(
                                icon: 'mic',
                                title: 'Voice answers',
                                subtitle: 'Fill fields by speaking',
                                value: voiceAnswers,
                                duration: duration,
                                primary: primary,
                                largerTargets: largerTargets,
                                onChanged: (value) {
                                  ref
                                          .read(voiceAnswersProvider.notifier)
                                          .state =
                                      value;
                                },
                              ),
                              _PreferenceRow(
                                icon: 'hand',
                                title: 'Larger touch targets',
                                subtitle: 'For limited dexterity',
                                value: largerTargets,
                                duration: duration,
                                primary: primary,
                                largerTargets: largerTargets,
                                onChanged: (value) {
                                  ref
                                          .read(
                                            largerTouchTargetsProvider.notifier,
                                          )
                                          .state =
                                      value;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      // Temporary destination until the account screen is ready.
                      onPressed: () => context.go('/home'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                        shape: const StadiumBorder(),
                        animationDuration: duration,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.primary,
    required this.highContrast,
    required this.largerTargets,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color primary;
  final bool highContrast;
  final bool largerTargets;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 48,
                minHeight: largerTargets ? 56 : 48,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? primary : Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: highContrast ? AppColors.ink : AppColors.line,
                      width: highContrast ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : AppColors.muted,
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

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.duration,
    required this.primary,
    required this.largerTargets,
    required this.onChanged,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool value;
  final Duration duration;
  final Color primary;
  final bool largerTargets;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. $subtitle',
      toggled: value,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: largerTargets ? 76 : 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F6F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/accessibility/$icon.svg',
                        width: 22,
                        height: 22,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.25,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: duration,
                      curve: Curves.easeOut,
                      width: 50,
                      height: 30,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: value ? primary : const Color(0xFFD5DAD8),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: AnimatedAlign(
                        duration: duration,
                        curve: Curves.easeOut,
                        alignment: value
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: const SizedBox.square(
                          dimension: 24,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
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
        ),
      ),
    );
  }
}

class _OutlinedSliderThumb extends SliderComponentShape {
  const _OutlinedSliderThumb({required this.outline});

  final Color outline;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(24, 24);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    canvas.drawCircle(center, 12, Paint()..color = Colors.white);

    canvas.drawCircle(
      center,
      11.25,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}

class _EvenRoundedSliderTrack extends RoundedRectSliderTrackShape {
  const _EvenRoundedSliderTrack();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: 0,
    );
  }
}

class _SliderGestureArea extends StatelessWidget {
  const _SliderGestureArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(gestureSettings: const DeviceGestureSettings(touchSlop: 6)),
      child: child,
    );
  }
}

class _AnchoredPreferencesList extends StatefulWidget {
  const _AnchoredPreferencesList({
    required this.anchorChildKey,
    required this.children,
    super.key,
  });

  final GlobalKey anchorChildKey;
  final List<Widget> children;

  @override
  State<_AnchoredPreferencesList> createState() =>
      _AnchoredPreferencesListState();
}

class _AnchoredPreferencesListState extends State<_AnchoredPreferencesList> {
  final _controller = ScrollController();
  final _viewportKey = GlobalKey();
  final _centerSliverKey = GlobalKey();

  bool _anchored = false;
  double _anchorFraction = 0;

  void anchorToSlider() {
    final cardObject = widget.anchorChildKey.currentContext?.findRenderObject();
    final viewportObject = _viewportKey.currentContext?.findRenderObject();

    if (cardObject is! RenderBox ||
        viewportObject is! RenderBox ||
        !cardObject.hasSize ||
        !viewportObject.hasSize ||
        !_controller.hasClients ||
        viewportObject.size.height <= 0) {
      return;
    }

    final cardTop = cardObject
        .localToGlobal(Offset.zero, ancestor: viewportObject)
        .dy;

    final viewportHeight = viewportObject.size.height;
    final fraction = (cardTop / viewportHeight).clamp(0.0, 1.0).toDouble();
    final initialOffset = fraction * viewportHeight - cardTop;

    setState(() {
      _anchored = true;
      _anchorFraction = fraction;
    });

    _controller.jumpTo(initialOffset);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: _viewportKey,
      child: CustomScrollView(
        controller: _controller,
        center: _anchored ? _centerSliverKey : null,
        anchor: _anchored ? _anchorFraction : 0,
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          for (final child in widget.children)
            SliverToBoxAdapter(
              key: child.key == widget.anchorChildKey ? _centerSliverKey : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: child,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

class _LiveSliderText extends StatelessWidget {
  const _LiveSliderText(
    this.text, {
    required this.liveTextScaler,
    required this.style,
  });

  final String text;
  final TextScaler liveTextScaler;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final layoutScaler = MediaQuery.textScalerOf(context);
    final fontSize = style.fontSize ?? 14;

    final scale = liveTextScaler.scale(fontSize) / layoutScaler.scale(fontSize);

    return Transform.scale(
      scale: scale,
      alignment: Alignment.centerLeft,
      child: Text(text, style: style),
    );
  }
}
