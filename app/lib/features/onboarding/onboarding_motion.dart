import 'package:flutter/animation.dart';

abstract final class OnboardingMotion {
  static const duration = Duration(milliseconds: 350);
  static const reducedDuration = Duration(milliseconds: 200);

  static Interval _interval(
    int startMilliseconds,
    int endMilliseconds,
    Curve curve,
  ) {
    return Interval(
      startMilliseconds / 780,
      endMilliseconds / 780,
      curve: curve,
    );
  }

  static final outgoingIllustration = _interval(80, 500, Curves.easeInOut);

  static final outgoingIllustrationFade = _interval(80, 450, Curves.easeIn);

  static final incomingIllustration = _interval(150, 620, Curves.easeOut);

  static final outgoingText = _interval(50, 250, Curves.easeIn);

  static final incomingTitle = _interval(300, 600, Curves.easeOut);

  static final incomingDescription = _interval(380, 680, Curves.easeOut);

  static final firstInnerCard = _interval(420, 700, Curves.easeOut);

  static final secondInnerCard = _interval(500, 780, Curves.easeOut);

  static final pageIndicator = _interval(100, 450, Curves.easeInOut);

  static const outgoingTextDistance = 12.0;
  static const incomingTextDistance = 14.0;
  static const innerCardDistance = 16.0;

  static const inactiveDotWidth = 10.0;
  static const activeDotWidth = 34.0;
  static const dotHeight = 8.0;

  static const buttonPressScale = 0.96;
  static const buttonPressDuration = Duration(milliseconds: 60);
  static const buttonReleaseDuration = Duration(milliseconds: 140);
}
