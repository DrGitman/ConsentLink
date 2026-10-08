import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zxcvbn/zxcvbn.dart';

int estimatePasswordScore(String password) {
  final Object? score = Zxcvbn().evaluate(password).score;
  return score is num ? score.toInt().clamp(0, 4).toInt() : 0;
}

String? suggestedInstitution(String email) {
  final parts = email.trim().toLowerCase().split('@');

  if (parts.length != 2 ||
      parts.first.isEmpty ||
      RegExp(r'\s').hasMatch(parts.first)) {
    return null;
  }

  return switch (parts.last) {
    'nust.na' => 'NUST',
    _ => null,
  };
}

class InstitutionHint extends StatelessWidget {
  const InstitutionHint({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final institution = suggestedInstitution(value.text);

        if (institution == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            'Suggested institution: $institution. Confirm this later.',
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: colors.onPrimaryContainer,
            ),
          ),
        );
      },
    );
  }
}

class PasswordStrengthHint extends StatefulWidget {
  const PasswordStrengthHint({super.key, required this.controller});

  final TextEditingController controller;

  @override
  State<PasswordStrengthHint> createState() => _PasswordStrengthHintState();
}

class _PasswordStrengthHintState extends State<PasswordStrengthHint> {
  Timer? _debounce;
  int _revision = 0;
  int? _score;
  bool _pending = false;
  bool _notRated = false;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _changed();
  }

  @override
  void didUpdateWidget(PasswordStrengthHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _lastText = '';
      _changed();
    }
  }

  void _changed() {
    final password = widget.controller.text;

    if (password == _lastText) return;
    _lastText = password;

    _debounce?.cancel();
    final revision = ++_revision;

    setState(() {
      _score = null;
      _notRated = password.length > 128;
      _pending = password.isNotEmpty && !_notRated;
    });

    if (!_pending) return;

    _debounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final score = await compute(estimatePasswordScore, password);
        if (!mounted || revision != _revision) return;

        setState(() {
          _score = score;
          _pending = false;
        });
      } catch (error, stackTrace) {
        debugPrint('Unable to estimate password strength: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (!mounted || revision != _revision) return;

        setState(() {
          _pending = false;
          _notRated = true;
        });
      }
    });
  }

  @override
  void dispose() {
    ++_revision;
    _debounce?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final label = _lastText.isEmpty
        ? 'Strength'
        : _pending
        ? 'Checking…'
        : _notRated
        ? 'Not rated'
        : const ['Very weak', 'Weak', 'Fair', 'Strong', 'Very strong'][_score!];

    final color = _score == null
        ? colors.onSurfaceVariant
        : _score! < 2
        ? colors.error
        : colors.onPrimaryContainer;

    final progress = _score == null ? 0.0 : (_score! + 1) / 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Tooltip(
        message:
            'Estimated strength, not a guarantee. Use a unique password. '
            'The account service will apply its own password rules.',
        child: Semantics(
          label: 'Estimated password strength',
          value: label,
          child: ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: colors.outlineVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _score != null && _score! >= 2 ? colors.primary : color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: color,
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
