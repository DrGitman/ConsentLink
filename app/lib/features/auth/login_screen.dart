import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../preferences/accessibility_preferences.dart';
import 'widgets/auth_button.dart';
import 'widgets/password_visibility_icon.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _hidePassword = true;
  bool _submitted = false;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showNotice(String message) {
    setState(() => _notice = message);
  }

  void _submit() {
    setState(() {
      _submitted = true;
      _notice = null;
    });

    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    _showNotice(
      'The login form is ready. Authentication is not connected yet.',
    );
  }

  Widget _icon(String name, Color color) {
    return SvgPicture.asset(
      'assets/icons/auth/$name.svg',
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
    bool password = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final target = largerTargets ? 72.0 : 46.0;

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
          obscureText: password && _hidePassword,
          autocorrect: false,
          enableSuggestions: !password,
          keyboardType: password
              ? TextInputType.visiblePassword
              : TextInputType.emailAddress,
          textInputAction: password
              ? TextInputAction.done
              : TextInputAction.next,
          autofillHints: [
            password ? AutofillHints.password : AutofillHints.username,
          ],
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

    return _LoginViewport(
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(left: 15),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset(
                    'assets/icons/auth/logo.svg',
                    height: 64,
                    semanticsLabel: 'ConsentLink',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 28,
                        height: 34 / 28,
                        letterSpacing: -0.84,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Log in once online, then work offline.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.2,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Spacer(flex: 2),
              _field(
                label: 'Email',
                icon: 'mail',
                controller: _email,
                largerTargets: largerTargets,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Enter your email.';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Password',
                icon: 'lock',
                controller: _password,
                largerTargets: largerTargets,
                password: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your password.';
                  }
                  return null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size(48, largerTargets ? 72 : 46),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () {
                    FocusScope.of(context).unfocus();

                    if (const bool.fromEnvironment('AUTH_PREVIEW')) {
                      context.push('/password-recovery-preview');
                    } else {
                      _showNotice('Password recovery is not connected yet.');
                    }
                  },
                  child: const Text('Forgot password?'),
                ),
              ),
              AuthButton(label: 'Log in', onPressed: _submit),
              const SizedBox(height: 14),
              AuthButton(
                label: 'Unlock with fingerprint',
                outlined: true,
                icon: _icon('fingerprint', colors.onSurface),
                onPressed: () => _showNotice(
                  'Fingerprint unlock needs a saved account '
                  'and biometric setup. It is not connected yet.',
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size(48, largerTargets ? 72 : 48),
                  foregroundColor: colors.onSurface,
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  context.push('/sign-up');
                },
                child: const Text(
                  'New here?  Create an account',
                  textAlign: TextAlign.center,
                ),
              ),
              AnimatedSize(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _notice == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
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
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginViewport extends StatelessWidget {
  const _LoginViewport({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
                        child: child,
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
