import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_providers.dart';
import '../../data/auth/auth_service.dart';
import 'widgets/auth_button.dart';

/// After sign-up or an unconfirmed log-in: tap the emailed link, then log in.
class CheckEmailScreen extends ConsumerStatefulWidget {
  const CheckEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends ConsumerState<CheckEmailScreen> {
  bool _sending = false;
  String? _notice;

  Future<void> _resend() async {
    final auth = ref.read(authServiceProvider);
    if (auth == null || _sending) return;
    setState(() => _sending = true);
    String notice;
    try {
      await auth.resendCode(widget.email);
      notice = 'Email sent again to ${widget.email}.';
    } on AuthFailure catch (failure) {
      notice = failure.message;
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _notice = notice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    TextStyle text(double size, [FontWeight? weight]) => TextStyle(
      fontSize: size,
      height: 1.35,
      fontWeight: weight,
      color: onSurface,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Check your email',
                      textAlign: TextAlign.center,
                      style: text(28, FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Check your email and tap the confirmation link, '
                    'then log in.\n\nWe sent it to ${widget.email}.',
                    textAlign: TextAlign.center,
                    style: text(15),
                  ),
                  const SizedBox(height: 32),
                  AuthButton(
                    label: 'Go to log in',
                    onPressed: () => context.go('/login'),
                  ),
                  const SizedBox(height: 14),
                  AuthButton(
                    label: 'Resend email',
                    outlined: true,
                    busy: _sending,
                    onPressed: _resend,
                  ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _notice!,
                          textAlign: TextAlign.center,
                          style: text(14),
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
