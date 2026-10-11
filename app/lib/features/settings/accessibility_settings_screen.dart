import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../preferences/accessibility_preferences.dart';
import 'settings_widgets.dart';

/// Figma 08.2 Accessibility (3:3735). Every switch is a real, saved setting.
/// Text size previews while dragging and applies when you let go (so the
/// page doesn't jump under your finger).
class AccessibilitySettingsScreen extends ConsumerStatefulWidget {
  const AccessibilitySettingsScreen({super.key});
  @override
  ConsumerState<AccessibilitySettingsScreen> createState() =>
      _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState
    extends ConsumerState<AccessibilitySettingsScreen> {
  double? _dragScale;

  @override
  Widget build(BuildContext context) {
    final applied = ref.watch(appTextScaleProvider);
    final scale = _dragScale ?? applied;
    final primary = Theme.of(context).colorScheme.primary;
    final readAloud = ref.watch(readScreensAloudProvider);
    final speed = ref.watch(readAloudSpeedProvider);

    // The preview shows the size being chosen; the rest of the page keeps
    // the applied size until the drag ends.
    final media = MediaQuery.of(context);
    final base = media.textScaler.scale(10) / 10 / applied;

    return SettingsPage(
      title: 'Accessibility',
      children: [
        _Card(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preview',
                style: dashboardText(
                  12,
                  color: AppColors.subtle,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(base * scale),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: reduceMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  style: dashboardText(22, weight: FontWeight.w500).copyWith(
                    letterSpacing: ref.watch(dyslexiaFontProvider) ? .6 : 0,
                    color: ref.watch(highContrastProvider)
                        ? Colors.black
                        : AppColors.ink,
                  ),
                  child: const Text('You can stop at any time.'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Text size',
                      style: dashboardText(15, weight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${(scale * 100).round()}%',
                    style: dashboardText(
                      13,
                      color: primary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ExcludeSemantics(
                    child: Text(
                      'A',
                      textScaler: TextScaler.noScaling,
                      style: dashboardText(
                        13,
                        color: AppColors.subtle,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Figma: 14 dp between each "A" and the track ends.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: AppSlider(
                        value: scale,
                        min: 1,
                        max: 1.6,
                        divisions: 12,
                        label: 'Text size',
                        valueLabel: '${(scale * 100).round()}%',
                        onChanged: (v) => setState(() => _dragScale = v),
                        onChangeEnd: (v) {
                          ref.read(appTextScaleProvider.notifier).state = v;
                          setState(() => _dragScale = null);
                        },
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      'A',
                      textScaler: TextScaler.noScaling,
                      style: dashboardText(24, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Read-aloud speed (replaces Brightness: the phone handles
        // brightness and volume itself).
        AnimatedOpacity(
          duration: reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          opacity: readAloud ? 1 : .45,
          child: IgnorePointer(
            ignoring: !readAloud,
            child: _Card(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Read-aloud speed',
                          style: dashboardText(15, weight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${speed.toStringAsFixed(1)}×',
                        style: dashboardText(
                          13,
                          color: primary,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const ExcludeSemantics(
                        child: DashboardIcon(
                          'capture/volume',
                          color: AppColors.subtle,
                          size: 16,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: AppSlider(
                            value: speed,
                            min: .5,
                            max: 1.5,
                            divisions: 10,
                            label: 'Read-aloud speed',
                            valueLabel: '${speed.toStringAsFixed(1)} times',
                            onChanged: (v) =>
                                ref
                                    .read(readAloudSpeedProvider.notifier)
                                    .state = double.parse(
                                  v.toStringAsFixed(1),
                                ),
                          ),
                        ),
                      ),
                      const ExcludeSemantics(
                        child: DashboardIcon(
                          'capture/volume',
                          color: AppColors.ink,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SettingsCard(
          children: [
            SettingsToggleRow(
              icon: 'consent/eye',
              title: 'High contrast',
              value: ref.watch(highContrastProvider),
              onChanged: (v) =>
                  ref.read(highContrastProvider.notifier).state = v,
            ),
            SettingsToggleRow(
              icon: 'form/type',
              title: 'Dyslexia-friendly font',
              subtitle: 'Atkinson Hyperlegible',
              value: ref.watch(dyslexiaFontProvider),
              onChanged: (v) =>
                  ref.read(dyslexiaFontProvider.notifier).state = v,
            ),
            SettingsToggleRow(
              icon: 'capture/volume',
              title: 'Read aloud',
              subtitle: 'Speed ${speed.toStringAsFixed(1)}×',
              value: readAloud,
              onChanged: (v) =>
                  ref.read(readScreensAloudProvider.notifier).state = v,
            ),
            SettingsToggleRow(
              icon: 'capture/hand',
              title: 'Reduce motion',
              value: ref.watch(reduceMotionPreferenceProvider),
              onChanged: (v) =>
                  ref.read(reduceMotionPreferenceProvider.notifier).state = v,
            ),
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.padding});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

/// Figma slider: 6 dp line track, institution fill, 24 dp white thumb with a
/// 1.5 dp institution ring.
class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.valueLabel,
    required this.onChanged,
    this.onChangeEnd,
    this.divisions,
    this.showThumb = true,
  });
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String label;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool showThumb;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: label,
      value: valueLabel,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 6,
          activeTrackColor: primary,
          inactiveTrackColor: AppColors.line,
          overlayShape: SliderComponentShape.noOverlay,
          overlayColor: Colors.transparent,
          thumbShape: showThumb
              ? _RingThumb(primary)
              : SliderComponentShape.noThumb,
          trackShape: const RoundedRectSliderTrackShape(),
          showValueIndicator: ShowValueIndicator.never,
          tickMarkShape: SliderTickMarkShape.noTickMark,
        ),
        child: SizedBox(
          height: 48,
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ),
    );
  }
}

class _RingThumb extends SliderComponentShape {
  const _RingThumb(this.color);
  final Color color;
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(24);
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
    final r = 12 + 2 * activationAnimation.value;
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      r - .75,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}
