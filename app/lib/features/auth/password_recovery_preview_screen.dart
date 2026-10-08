import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../preferences/accessibility_preferences.dart';
import 'widgets/auth_button.dart';
import 'widgets/password_visibility_icon.dart';
import 'widgets/sign_up_hints.dart';

enum _RecoveryStep { email, sent, password, complete }

class PasswordRecoveryPreviewScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryPreviewScreen({super.key});

  @override
  ConsumerState<PasswordRecoveryPreviewScreen> createState() =>
      _PasswordRecoveryPreviewScreenState();
}

class _PasswordRecoveryPreviewScreenState
    extends ConsumerState<PasswordRecoveryPreviewScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  _RecoveryStep _step = _RecoveryStep.email;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _backPressed = false;

  String? _emailError;
  String? _passwordError;
  String? _confirmationError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _goTo(_RecoveryStep step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  void _requestReset() {
    final email = _email.text.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

    setState(() {
      _emailError = valid ? null : 'Enter a valid email address.';
    });

    if (valid) _goTo(_RecoveryStep.sent);
  }

  void _resetPreview() {
    setState(() {
      _passwordError = _password.text.isEmpty ? 'Enter a new password.' : null;
      _confirmationError = _confirmation.text.isEmpty
          ? 'Enter the password again.'
          : _confirmation.text != _password.text
          ? 'The passwords do not match.'
          : null;
    });

    if (_passwordError != null || _confirmationError != null) return;

    _password.clear();
    _confirmation.clear();
    _goTo(_RecoveryStep.complete);
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? error,
    bool password = false,
    bool hidden = false,
    VoidCallback? toggle,
    bool last = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final largerTargets = ref.watch(largerTouchTargetsProvider);

    OutlineInputBorder border(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: password && hidden,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: password
              ? TextInputType.visiblePassword
              : TextInputType.emailAddress,
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          onSubmitted: last
              ? (_) => password ? _resetPreview() : _requestReset()
              : null,
          style: TextStyle(fontSize: 15, height: 1.2, color: colors.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surface,
            isDense: true,
            errorText: error,
            errorMaxLines: 3,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            prefixIconConstraints: BoxConstraints(
              minWidth: 48,
              minHeight: largerTargets ? 64 : 46,
            ),
            prefixIcon: SizedBox(
              width: 48,
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/auth/${password ? 'lock' : 'mail'}.svg',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(
                    colors.onSurfaceVariant,
                    BlendMode.srcIn,
                  ),
                  excludeFromSemantics: true,
                ),
              ),
            ),
            suffixIcon: password
                ? IconButton(
                    tooltip: hidden ? 'Show password' : 'Hide password',
                    onPressed: toggle,
                    constraints: BoxConstraints(
                      minWidth: largerTargets ? 64 : 48,
                      minHeight: largerTargets ? 64 : 48,
                    ),
                    icon: PasswordVisibilityIcon(
                      obscured: hidden,
                      color: colors.onSurfaceVariant,
                    ),
                  )
                : null,
            enabledBorder: border(colors.outline, 1.2),
            focusedBorder: border(colors.primary, 2),
            errorBorder: border(colors.error, 2),
            focusedErrorBorder: border(colors.error, 2),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final title = switch (_step) {
      _RecoveryStep.email => 'Forgot password?',
      _RecoveryStep.sent => 'Check your inbox',
      _RecoveryStep.password => 'Choose a new password',
      _RecoveryStep.complete => 'Preview complete',
    };

    final description = switch (_step) {
      _RecoveryStep.email =>
        'Enter your account email to request a password-reset link.',
      _RecoveryStep.sent =>
        'In the connected service, an eligible account would receive '
            'a reset link. This preview does not check whether an account exists.',
      _RecoveryStep.password =>
        'Choose a unique password that you do not use elsewhere.',
      _RecoveryStep.complete =>
        'The passwords matched. No real password has been changed.',
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'Back to login',
                        child: Material(
                          color: colors.surface,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            splashFactory: NoSplash.splashFactory,
                            highlightColor: Colors.transparent,
                            onTap: _leave,
                            onHighlightChanged: (pressed) {
                              setState(() => _backPressed = pressed);
                            },
                            child: SizedBox.square(
                              dimension: 48,
                              child: Semantics(
                                button: true,
                                label: 'Back to login',
                                child: AnimatedScale(
                                  scale: _backPressed && !reduceMotion
                                      ? 0.9
                                      : 1,
                                  duration: reduceMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 100),
                                  child: Icon(
                                    Icons.chevron_left_rounded,
                                    size: 28,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Development preview',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    children: [
                      AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        child: Column(
                          key: ValueKey(_step),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 28,
                                  height: 1.2,
                                  letterSpacing: -0.6,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_step == _RecoveryStep.email) ...[
                              _field(
                                label: 'Email',
                                controller: _email,
                                error: _emailError,
                                last: true,
                              ),
                              const SizedBox(height: 20),
                              AuthButton(
                                label: 'Preview reset request',
                                onPressed: _requestReset,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No email will be sent in this preview.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (_step == _RecoveryStep.sent) ...[
                              Text(
                                _email.text.trim(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 20),
                              AuthButton(
                                label: 'Preview new-password screen',
                                onPressed: () => _goTo(_RecoveryStep.password),
                              ),
                              TextButton(
                                onPressed: () => _goTo(_RecoveryStep.email),
                                child: const Text('Change email'),
                              ),
                            ],
                            if (_step == _RecoveryStep.password) ...[
                              _field(
                                label: 'New password',
                                controller: _password,
                                error: _passwordError,
                                password: true,
                                hidden: _hidePassword,
                                toggle: () {
                                  setState(() {
                                    _hidePassword = !_hidePassword;
                                  });
                                },
                              ),
                              PasswordStrengthHint(controller: _password),
                              const SizedBox(height: 16),
                              _field(
                                label: 'Confirm new password',
                                controller: _confirmation,
                                error: _confirmationError,
                                password: true,
                                hidden: _hideConfirmation,
                                last: true,
                                toggle: () {
                                  setState(() {
                                    _hideConfirmation = !_hideConfirmation;
                                  });
                                },
                              ),
                              const SizedBox(height: 20),
                              AuthButton(
                                label: 'Preview password reset',
                                onPressed: _resetPreview,
                              ),
                            ],
                            if (_step == _RecoveryStep.complete)
                              AuthButton(
                                label: 'Back to login',
                                onPressed: _leave,
                              ),
                          ],
                        ),
                      ),
                    ],
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
