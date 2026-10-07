import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingArtwork extends StatelessWidget {
  const OnboardingArtwork({
    required this.currentPage,
    required this.previousPage,
    required this.progress,
    required this.reduceMotion,
    super.key,
  });

  final int currentPage;
  final int? previousPage;
  final Animation<double> progress;
  final bool reduceMotion;

  static const _assets = [
    'assets/illustrations/onboarding/languages.svg',
    'assets/illustrations/onboarding/offline.svg',
    'assets/illustrations/onboarding/ai.svg',
    'assets/illustrations/onboarding/institution.svg',
  ];

  Widget _picture(int page) {
    return SvgPicture.asset(
      _assets[page],
      fit: BoxFit.contain,
      alignment: Alignment.center,
      excludeFromSemantics: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final incoming = _picture(currentPage);
    final outgoing = previousPage == null ? null : _picture(previousPage!);

    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 350 / 400,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              if (outgoing == null) return incoming;

              final value = progress.value.clamp(0.0, 1.0).toDouble();
              final fade = reduceMotion
                  ? value
                  : Curves.easeInOut.transform(value);

              return Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(opacity: 1 - fade, child: outgoing),
                  Opacity(opacity: fade, child: incoming),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
