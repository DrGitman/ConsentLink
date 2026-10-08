import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../preferences/accessibility_preferences.dart';
import 'widgets/auth_button.dart';
import 'widgets/password_visibility_icon.dart';
import 'widgets/sign_up_hints.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  late final AnimationController _shakeController;
  late final Animation<double> _shake;

  bool _hidePassword = true;
  bool _submitted = false;
  bool _acceptedTerms = false;
  late final TapGestureRecognizer _termsLink;
  late final TapGestureRecognizer _privacyLink;
  String? _notice;

  @override
  void initState() {
    super.initState();

    _termsLink = TapGestureRecognizer()..onTap = () => _openDocument('/terms');
    _privacyLink = TapGestureRecognizer()
      ..onTap = () => _openDocument('/privacy');

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Figma email-error movement: 0, -8, 8, -6, 6, -2, 0.
    final positions = <double>[0, -8, 8, -6, 6, -2, 0];
    final weights = <double>[60, 70, 70, 70, 70, 60];

    _shake = TweenSequence<double>([
      for (var i = 0; i < weights.length; i++)
        TweenSequenceItem(
          tween: Tween<double>(begin: positions[i], end: positions[i + 1])
              .chain(
                CurveTween(
                  curve: i == 0 || i == weights.length - 1
                      ? Curves.easeOut
                      : Curves.easeInOut,
                ),
              ),
          weight: weights[i],
        ),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _termsLink.dispose();
    _privacyLink.dispose();
    super.dispose();
  }

  void _openDocument(String route) {
    FocusScope.of(context).unfocus();
    context.push(route);
  }

  String? _emailError(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your institutional email.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  void _submit() {
    setState(() {
      _submitted = true;
      _notice = null;
    });

    final valid = _form.currentState!.validate();

    if (_emailError(_email.text) != null &&
        !MediaQuery.disableAnimationsOf(context)) {
      _shakeController.forward(from: 0);
    }

    if (!valid || !_acceptedTerms) return;

    FocusScope.of(context).unfocus();
    if (const bool.fromEnvironment('AUTH_PREVIEW')) {
      context.push('/confirm-email-preview', extra: _email.text.trim());
      return;
    }

    setState(() {
      _notice =
          'The form is ready. Account creation and email confirmation '
          'are not connected yet.';
    });
  }

  void _returnToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  Widget _icon(String name, Color color) {
    final folder = name == 'user' ? 'navigation' : 'auth';

    return SvgPicture.asset(
      'assets/icons/$folder/$name.svg',
      width: 22,
      height: 22,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }

  Widget _field({
    required String label,
    required String icon,
    required TextEditingController controller,
    required bool largerTargets,
    required String? Function(String?) validator,
    required TextInputType keyboardType,
    required String autofillHint,
    bool password = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final target = largerTargets ? 64.0 : 46.0;

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
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textCapitalization: icon == 'user'
              ? TextCapitalization.words
              : TextCapitalization.none,
          textInputAction: password
              ? TextInputAction.done
              : TextInputAction.next,
          autofillHints: [autofillHint],
          obscureText: password && _hidePassword,
          autocorrect: false,
          enableSuggestions: !password,
          onFieldSubmitted: password ? (_) => _submit() : null,
          onChanged: (_) {
            if (_notice != null) setState(() => _notice = null);
          },
          style: TextStyle(fontSize: 15, height: 1.2, color: colors.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            prefixIconConstraints: BoxConstraints(
              minWidth: 48,
              minHeight: target,
            ),
            prefixIcon: SizedBox(
              width: 48,
              child: Center(child: _icon(icon, colors.onSurfaceVariant)),
            ),
            suffixIconConstraints: BoxConstraints(
              minWidth: target,
              minHeight: target,
            ),
            suffixIcon: password
                ? IconButton(
                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                    onPressed: () {
                      setState(() => _hidePassword = !_hidePassword);
                    },
                    icon: PasswordVisibilityIcon(
                      obscured: _hidePassword,
                      color: colors.onSurfaceVariant,
                    ),
                  )
                : null,
            enabledBorder: border(colors.outline, 1.2),
            focusedBorder: border(colors.primary, 2),
            errorBorder: border(colors.error, 2),
            focusedErrorBorder: border(colors.error, 2),
            errorMaxLines: 3,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final largerTargets = ref.watch(largerTouchTargetsProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: AutofillGroup(
                          child: Form(
                            key: _form,
                            autovalidateMode: _submitted
                                ? AutovalidateMode.onUserInteraction
                                : AutovalidateMode.disabled,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Spacer(),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: SvgPicture.asset(
                                    'assets/icons/auth/logo.svg',
                                    height: 48,
                                    semanticsLabel: 'ConsentLink',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Create your account',
                                  style: TextStyle(
                                    fontSize: 30,
                                    height: 1.2,
                                    letterSpacing: -0.9,
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'For researchers and supervisors.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.2,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Spacer(),
                                _field(
                                  label: 'Full name',
                                  icon: 'user',
                                  controller: _name,
                                  largerTargets: largerTargets,
                                  keyboardType: TextInputType.name,
                                  autofillHint: AutofillHints.name,
                                  validator: (value) {
                                    return value == null || value.trim().isEmpty
                                        ? 'Enter your name.'
                                        : null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                AnimatedBuilder(
                                  animation: _shake,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(
                                        reduceMotion ? 0 : _shake.value,
                                        0,
                                      ),
                                      child: child,
                                    );
                                  },
                                  child: _field(
                                    label: 'Institutional email',
                                    icon: 'mail',
                                    controller: _email,
                                    largerTargets: largerTargets,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHint: AutofillHints.email,
                                    validator: _emailError,
                                  ),
                                ),
                                InstitutionHint(controller: _email),
                                const SizedBox(height: 12),
                                _field(
                                  label: 'Password',
                                  icon: 'lock',
                                  controller: _password,
                                  largerTargets: largerTargets,
                                  keyboardType: TextInputType.visiblePassword,
                                  autofillHint: AutofillHints.newPassword,
                                  password: true,
                                  validator: (value) {
                                    return value == null || value.isEmpty
                                        ? 'Enter a password.'
                                        : null;
                                  },
                                ),
                                PasswordStrengthHint(controller: _password),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: largerTargets ? 64 : 48,
                                      height: largerTargets ? 64 : 48,
                                      child: Checkbox(
                                        value: _acceptedTerms,
                                        semanticLabel:
                                            'Agree to the Terms of use and acknowledge the Privacy Notice',
                                        onChanged: (value) {
                                          setState(() {
                                            _acceptedTerms = value ?? false;
                                            _notice = null;
                                          });
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'I agree to the ',
                                              ),
                                              TextSpan(
                                                text: 'Terms of use',
                                                recognizer: _termsLink,
                                                style: TextStyle(
                                                  color: colors.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const TextSpan(
                                                text: ' and acknowledge the ',
                                              ),
                                              TextSpan(
                                                text: 'Privacy Notice',
                                                recognizer: _privacyLink,
                                                style: TextStyle(
                                                  color: colors.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const TextSpan(text: '.'),
                                            ],
                                          ),
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.4,
                                            color: colors.onSurface,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_submitted && !_acceptedTerms)
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      'Please agree to the Terms of use and acknowledge the Privacy Notice.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.error,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                AuthButton(
                                  label: 'Create account',
                                  onPressed: _submit,
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  style:
                                      TextButton.styleFrom(
                                        foregroundColor: colors.onSurface,
                                        overlayColor: Colors.transparent,
                                        minimumSize: Size(
                                          48,
                                          largerTargets ? 64 : 48,
                                        ),
                                        textStyle: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ).copyWith(
                                        splashFactory: NoSplash.splashFactory,
                                      ),
                                  onPressed: _returnToLogin,
                                  child: const Text(
                                    'Already have an account?  Log in',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF4E2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Internet needed for this step only',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF9A5B00),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_notice != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        _notice!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colors.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
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
