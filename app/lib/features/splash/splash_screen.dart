import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _artworkProgress;
  var _animationStarted = false;
  var _navigationStarted = false;
  var _loadErrorReported = false;
  var _reduceMotion = false;
  var _backgroundLoaded = false;
  LottieComposition? _foregroundComposition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_handleAnimationStatus);
    _artworkProgress = _controller;
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _navigateHome();
    }
  }

  void _startAnimation(LottieComposition composition) {
    _foregroundComposition = composition;
    if (!mounted || _animationStarted || !_backgroundLoaded) {
      return;
    }

    _animationStarted = true;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    const hold = Duration(milliseconds: 700);
    _controller.duration = _reduceMotion ? hold : composition.duration + hold;
    setState(() {
      _artworkProgress = _reduceMotion
          ? const AlwaysStoppedAnimation<double>(1)
          : TweenSequence<double>([
              TweenSequenceItem(
                tween: Tween(begin: 0.0, end: 1.0),
                weight: composition.duration.inMicroseconds.toDouble(),
              ),
              TweenSequenceItem(
                tween: ConstantTween<double>(1),
                weight: hold.inMicroseconds.toDouble(),
              ),
            ]).animate(_controller);
    });
    // onLoaded runs before Lottie's first paint. Start the clock only after
    // the composition has reached the screen, so loading cannot consume it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward(from: 0);
    });
  }

  void _onBackgroundLoaded(LottieComposition composition) {
    _backgroundLoaded = true;
    final foreground = _foregroundComposition;
    if (foreground != null) _startAnimation(foreground);
  }

  void _navigateHome() {
    if (!mounted || _navigationStarted) {
      return;
    }

    _navigationStarted = true;
    context.go('/home');
  }

  Widget _buildLoadError(
    BuildContext context,
    AppLocalizations strings,
    Object error,
    StackTrace? stackTrace,
  ) {
    if (!_loadErrorReported) {
      _loadErrorReported = true;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'ConsentLink splash animation',
          context: ErrorDescription('while loading the splash animation'),
        ),
      );
    }

    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white, size: 40),
            const SizedBox(height: 16),
            Text(
              strings.routeErrorTitle,
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              strings.routeErrorDescription,
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _navigateHome,
              child: Text(strings.returnHome),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final insets = MediaQuery.paddingOf(context);
    final horizontalInset = insets.left > insets.right
        ? insets.left
        : insets.right;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.navigation,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.navigation,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.navigation,
        body: Semantics(
          image: true,
          label: strings.appName,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Lottie.asset(
                  'assets/animations/consentlink-splash-background.json',
                  controller: _artworkProgress,
                  animate: false,
                  repeat: false,
                  fit: BoxFit.fill,
                  backgroundLoading: false,
                  onLoaded: _onBackgroundLoaded,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildLoadError(context, strings, error, stackTrace),
                ),
                SafeArea(
                  minimum: EdgeInsets.symmetric(horizontal: horizontalInset),
                  child: Lottie.asset(
                    'assets/animations/consentlink-splash.json',
                    key: const ValueKey('consentlink-splash-animation'),
                    controller: _artworkProgress,
                    animate: false,
                    repeat: false,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    onLoaded: _startAnimation,
                    backgroundLoading: false,
                    delegates: LottieDelegates(
                      textStyle: (font) {
                        final style = font.style.toLowerCase().replaceAll(
                          ' ',
                          '',
                        );
                        return TextStyle(
                          fontFamily: font.fontFamily,
                          fontWeight: style.contains('semibold')
                              ? FontWeight.w600
                              : style.contains('medium')
                              ? FontWeight.w500
                              : FontWeight.w400,
                        );
                      },
                    ),
                    errorBuilder: (context, error, stackTrace) =>
                        _buildLoadError(context, strings, error, stackTrace),
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
