import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import 'onboarding_artwork.dart';
import 'onboarding_motion.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _scrollController = ScrollController();

  int _page = 0;
  int? _previousPage;
  bool _reduceMotion = false;
  bool _busy = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OnboardingMotion.duration,
      value: 1,
    )..addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {
        _busy = false;
        _previousPage = null;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  void _changePage(int next) {
    if (_busy || next < 0 || next > 3 || next == _page) return;

    HapticFeedback.lightImpact();

    setState(() {
      _previousPage = _page;
      _page = next;
      _busy = true;
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    _controller.duration = _reduceMotion
        ? OnboardingMotion.reducedDuration
        : OnboardingMotion.duration;
    _controller.forward(from: 0);
  }

  void _complete() {
    if (_busy || _finished) return;
    _finished = true;
    HapticFeedback.lightImpact();
    widget.onComplete();
  }

  Widget _animatedText({
    required List<String> values,
    required TextStyle style,
    required bool title,
  }) {
    final current = Text(values[_page], style: style);
    if (_previousPage == null) return current;

    final t = _controller.value;
    final incoming = _reduceMotion
        ? t
        : (title
                  ? OnboardingMotion.incomingTitle
                  : OnboardingMotion.incomingDescription)
              .transform(t);
    final outgoing = _reduceMotion
        ? t
        : OnboardingMotion.outgoingText.transform(t);

    return Stack(
      alignment: Alignment.topLeft,
      children: [
        ExcludeSemantics(
          child: Opacity(
            opacity: 1 - outgoing,
            child: Transform.translate(
              offset: Offset(
                0,
                _reduceMotion
                    ? 0
                    : -OnboardingMotion.outgoingTextDistance * outgoing,
              ),
              child: Text(values[_previousPage!], style: style),
            ),
          ),
        ),
        Opacity(
          opacity: incoming,
          child: Transform.translate(
            offset: Offset(
              0,
              _reduceMotion
                  ? 0
                  : OnboardingMotion.incomingTextDistance * (1 - incoming),
            ),
            child: current,
          ),
        ),
      ],
    );
  }

  Widget _pageIndicators() {
    final t = _reduceMotion
        ? _controller.value
        : OnboardingMotion.pageIndicator.transform(_controller.value);

    return ExcludeSemantics(
      child: Row(
        children: List.generate(4, (index) {
          final wasActive = index == (_previousPage ?? _page);
          final isActive = index == _page;

          final startWidth = wasActive
              ? OnboardingMotion.activeDotWidth
              : OnboardingMotion.inactiveDotWidth;
          final endWidth = isActive
              ? OnboardingMotion.activeDotWidth
              : OnboardingMotion.inactiveDotWidth;

          final startColor = wasActive
              ? AppColors.brand
              : const Color(0xFFCDD3D0);
          final endColor = isActive ? AppColors.brand : const Color(0xFFCDD3D0);

          return Container(
            width: startWidth + (endWidth - startWidth) * t,
            height: OnboardingMotion.dotHeight,
            margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
            decoration: BoxDecoration(
              color: Color.lerp(startColor, endColor, t),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onAnimationStatus)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    final titles = [
      strings.onboardingLanguagesTitle,
      strings.onboardingOfflineTitle,
      strings.onboardingAiTitle,
      strings.onboardingInstitutionTitle,
    ];

    final descriptions = [
      strings.onboardingLanguagesBody,
      strings.onboardingOfflineBody,
      strings.onboardingAiBody,
      strings.onboardingInstitutionBody,
    ];

    final artwork = OnboardingArtwork(
      currentPage: _page,
      previousPage: _previousPage,
      progress: _controller,
      reduceMotion: _reduceMotion,
    );

    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy && _page > 0) _changePage(_page - 1);
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_page > 0)
                          _AnimatedBackChevron(
                            tooltip: strings.onboardingBack,
                            reduceMotion: _reduceMotion,
                            onPressed: _busy
                                ? null
                                : () => _changePage(_page - 1),
                          )
                        else
                          const SizedBox(width: 48, height: 48),
                        if (_page < 3)
                          TextButton(
                            onPressed: _busy ? null : _complete,
                            child: Text(strings.onboardingSkip),
                          )
                        else
                          const SizedBox(width: 48, height: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AnimatedBuilder(
                        animation: _controller,
                        child: artwork,
                        builder: (context, child) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              child!,
                              const SizedBox(height: 24),
                              Semantics(
                                liveRegion: true,
                                label: strings.onboardingPageAnnouncement(
                                  _page + 1,
                                  4,
                                ),
                                child: _pageIndicators(),
                              ),
                              const SizedBox(height: 24),
                              _animatedText(
                                values: titles,
                                title: true,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 30,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                  letterSpacing: -0.9,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _animatedText(
                                values: descriptions,
                                title: false,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  height: 1.5,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(60),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _busy
                            ? null
                            : () {
                                if (_page == 3) {
                                  _complete();
                                } else {
                                  _changePage(_page + 1);
                                }
                              },
                        child: Text(
                          _page == 3
                              ? strings.onboardingGetStarted
                              : strings.onboardingNext,
                          textAlign: TextAlign.center,
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
    );
  }
}

class _AnimatedBackChevron extends StatefulWidget {
  const _AnimatedBackChevron({
    required this.tooltip,
    required this.reduceMotion,
    required this.onPressed,
  });

  final String tooltip;
  final bool reduceMotion;
  final VoidCallback? onPressed;

  @override
  State<_AnimatedBackChevron> createState() => _AnimatedBackChevronState();
}

class _AnimatedBackChevronState extends State<_AnimatedBackChevron> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return Tooltip(
      message: widget.tooltip,
      child: SizedBox.square(
        dimension: 48,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onPressed,
            onHighlightChanged: (pressed) {
              if (_pressed != pressed) {
                setState(() => _pressed = pressed);
              }
            },
            child: Semantics(
              button: true,
              enabled: enabled,
              label: widget.tooltip,
              child: Center(
                child: AnimatedScale(
                  scale: _pressed && enabled && !widget.reduceMotion ? 0.88 : 1,
                  duration: widget.reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  child: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    size: 28,
                    color: enabled ? AppColors.ink : AppColors.muted,
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
