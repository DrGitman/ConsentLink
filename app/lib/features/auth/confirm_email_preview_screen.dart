import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_back_button.dart';
import '../preferences/accessibility_preferences.dart';
import 'widgets/auth_button.dart';

class ConfirmEmailPreviewScreen extends ConsumerStatefulWidget {
  const ConfirmEmailPreviewScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ConfirmEmailPreviewScreen> createState() =>
      _ConfirmEmailPreviewScreenState();
}

class _ConfirmEmailPreviewScreenState
    extends ConsumerState<ConfirmEmailPreviewScreen>
    with SingleTickerProviderStateMixin {
  static const _previewCode = '123456';

  final _digits = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  late final AnimationController _motion;
  late final Animation<double> _shake;
  late DateTime _resendAt;
  Timer? _timer;

  int _remaining = 60;
  int _tries = 3;
  bool _complete = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final positions = <double>[0, -8, 8, -6, 6, -2, 0];
    final durations = <double>[60, 70, 70, 70, 70, 60];

    _shake = TweenSequence<double>([
      for (var i = 0; i < durations.length; i++)
        TweenSequenceItem(
          tween: Tween<double>(begin: positions[i], end: positions[i + 1])
              .chain(
                CurveTween(
                  curve: i == 0 || i == durations.length - 1
                      ? Curves.easeOut
                      : Curves.easeInOut,
                ),
              ),
          weight: durations[i],
        ),
    ]).animate(_motion);

    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _remaining = 60;
    _resendAt = DateTime.now().add(const Duration(seconds: 60));

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final seconds = math.max(
        0,
        (_resendAt.difference(DateTime.now()).inMilliseconds / 1000).ceil(),
      );

      if (seconds != _remaining) {
        setState(() => _remaining = seconds);
      }
      if (seconds == 0) timer.cancel();
    });
  }

  void _changeDigit(int index, String value) {
    if (value.length > 1) {
      final start = value.length == 6 ? 0 : index;
      final count = math.min(value.length, 6 - start);

      for (var i = 0; i < count; i++) {
        _digits[start + i].text = value[i];
      }

      final last = start + count - 1;
      _focusNodes[math.min(last + 1, 5)].requestFocus();
    } else if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    setState(() => _error = null);
  }

  void _showError(String message) {
    setState(() => _error = message);
    if (!MediaQuery.disableAnimationsOf(context)) {
      _motion.forward(from: 0);
    }
  }

  void _verify() {
    if (_complete || _tries == 0) return;

    if (_digits.any((controller) => controller.text.length != 1)) {
      _showError('Enter all six digits.');
      return;
    }

    final code = _digits.map((controller) => controller.text).join();

    if (code != _previewCode) {
      _tries--;
      _showError(
        _tries == 0
            ? 'No tries left. Request another preview code.'
            : 'That code didn’t match. $_tries '
                  '${_tries == 1 ? 'try' : 'tries'} left.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    _timer?.cancel();
    setState(() {
      _error = null;
      _complete = true;
    });
  }

  void _resend() {
    if (_remaining > 0 || _complete) return;

    for (final controller in _digits) {
      controller.clear();
    }

    setState(() {
      _tries = 3;
      _error = null;
      _startCountdown();
    });

    _focusNodes.first.requestFocus();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/sign-up');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _motion.dispose();
    for (final controller in _digits) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Widget _codeFields(ColorScheme colors) {
    final textScale = MediaQuery.textScalerOf(context);
    final largerTargets = ref.watch(largerTouchTargetsProvider);
    final fieldWidth = math.max(
      largerTargets ? 72.0 : 46.0,
      textScale.scale(24) + 20,
    );
    final fieldHeight = math.max(
      largerTargets ? 72.0 : 62.0,
      textScale.scale(24) + 24,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(reduceMotion ? 0 : _shake.value, 0),
          child: child,
        );
      },
      child: SizedBox(
        height: fieldHeight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                SizedBox(
                  width: fieldWidth,
                  height: fieldHeight,
                  child: TextField(
                    controller: _digits[i],
                    focusNode: _focusNodes[i],
                    readOnly: _complete || _tries == 0,
                    keyboardType: TextInputType.number,
                    textInputAction: i == 5
                        ? TextInputAction.done
                        : TextInputAction.next,
                    autofillHints: i == 0
                        ? const [AutofillHints.oneTimeCode]
                        : null,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textAlign: TextAlign.center,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                    onTap: () {
                      _digits[i].selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _digits[i].text.length,
                      );
                    },
                    onChanged: (value) => _changeDigit(i, value),
                    onSubmitted: (_) {
                      if (i == 5) {
                        _verify();
                      } else {
                        _focusNodes[i + 1].requestFocus();
                      }
                    },
                    decoration: InputDecoration(
                      semanticCounterText: 'Code digit ${i + 1} of 6',
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _error == null ? colors.outline : colors.error,
                          width: _error == null ? 1.2 : 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _error == null ? colors.primary : colors.error,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final countdown =
        '${_remaining ~/ 60}:${(_remaining % 60).toString().padLeft(2, '0')}';

    void showPreviewInfo() {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Email confirmation preview'),
          content: const Text(
            'No email has been sent. Use 123456 to test a successful '
            'confirmation, or another code to test the error state.\n\n'
            'This preview does not create or verify a real account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    final message = _complete
        ? 'Preview complete — no account verified.'
        : _error;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final room = ((constraints.maxHeight - 600) / 166).clamp(
                  0.0,
                  1.0,
                );

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        children: [
                          AppBackButton(onPressed: _back),
                          const Spacer(),
                          TextButton(
                            onPressed: showPreviewInfo,
                            style: TextButton.styleFrom(
                              foregroundColor: colors.onSurfaceVariant,
                              textStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                              ),
                            ),
                            child: const Text('Preview'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        children: [
                          SizedBox(height: 16 + 50 * room),
                          Center(
                            child: Container(
                              width: 160,
                              height: 160,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primaryContainer,
                              ),
                              child: Container(
                                width: 120,
                                height: 120,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.alphaBlend(
                                    colors.primary.withValues(alpha: 0.14),
                                    colors.primaryContainer,
                                  ),
                                ),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.primary,
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/icons/auth/mail.svg',
                                    width: 36,
                                    height: 36,
                                    colorFilter: ColorFilter.mode(
                                      colors.onPrimary,
                                      BlendMode.srcIn,
                                    ),
                                    excludeFromSemantics: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 24 + 16 * room),
                          Text(
                            'Check your inbox',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 30,
                              height: 1.2,
                              letterSpacing: -0.9,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'Enter the 6-digit code for\n${widget.email}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Center(child: _codeFields(colors)),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 38),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: AnimatedSwitcher(
                                duration: reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 250),
                                child: message == null
                                    ? const SizedBox.shrink()
                                    : Semantics(
                                        key: ValueKey(message),
                                        liveRegion: true,
                                        child: Text(
                                          message,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.3,
                                            color: _complete
                                                ? colors.onPrimaryContainer
                                                : colors.error,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          AuthButton(
                            label: _complete
                                ? 'Preview complete'
                                : 'Verify email',
                            onPressed: _complete || _tries == 0
                                ? null
                                : _verify,
                          ),
                          const SizedBox(height: 12),
                          if (!_complete)
                            TextButton(
                              onPressed: _remaining == 0 ? _resend : null,
                              style: TextButton.styleFrom(
                                foregroundColor: colors.onPrimaryContainer,
                                disabledForegroundColor:
                                    colors.onSurfaceVariant,
                                textStyle: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: Text(
                                _remaining > 0
                                    ? 'Resend code in $countdown'
                                    : 'Resend preview code',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          TextButton(
                            onPressed: _back,
                            style: TextButton.styleFrom(
                              foregroundColor: colors.onPrimaryContainer,
                              textStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: const Text(
                              'Wrong address? Change email',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
