// data/auth/auth_service.dart
// Sign-up, email confirmation (6-digit code), log-in and log-out through
// Supabase Auth. Only email domains in public.institutions get a profile (and
// access), so we check the domain before sign-up and the profile after log-in.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase/supabase.dart';

import '../local/database_key.dart' show KeyStore;

/// The Supabase calls the service needs. Tests replace it with a fake.
abstract interface class AuthGateway {
  /// Name of the institution that owns [domain], or null.
  Future<String?> institutionForDomain(String domain);
  Future<void> signUp(String email, String password, String name);
  Future<void> verifySignupCode(String email, String code);
  Future<void> resendSignupCode(String email);
  Future<void> signIn(String email, String password);

  /// Whether the signed-in account has a profile (= belongs to an institution).
  Future<bool> hasProfile();
  Future<void> signOut();
  Future<String?> accessToken();

  /// Restores the login saved on this phone. False if there is none.
  Future<bool> restore();
}

/// A plain message to show the researcher.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.needsConfirmation = false});
  final String message;

  /// The account exists but its email is not confirmed yet.
  final bool needsConfirmation;

  @override
  String toString() => message;
}

const noInstitutionMessage =
    'ConsentLink is only open to institutions that have joined. Use your '
    'NUST (nust.na) or UNAM (unam.na) email, or ask your institution to join.';

class AuthService {
  AuthService(
    this._gateway, {
    required this.onSignedIn,
    required this.onSignedOut,
  });

  final AuthGateway _gateway;

  /// Starts sync. A failure here never blocks signing in.
  final Future<void> Function() onSignedIn;

  /// Stops sync. Runs before the session ends.
  final Future<void> Function() onSignedOut;

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final domain = email.trim().toLowerCase().split('@').last;
    final institution = await _run(() => _gateway.institutionForDomain(domain));
    if (institution == null) throw const AuthFailure(noInstitutionMessage);
    await _run(() => _gateway.signUp(email.trim(), password, name.trim()));
  }

  /// Checks the 6-digit code from the email. A right code also signs in.
  Future<void> confirm(String email, String code) async {
    await _run(() => _gateway.verifySignupCode(email.trim(), code));
    await _afterSignIn();
  }

  Future<void> resendCode(String email) =>
      _run(() => _gateway.resendSignupCode(email.trim()));

  Future<void> signIn(String email, String password) async {
    await _run(() => _gateway.signIn(email.trim(), password));
    await _afterSignIn();
  }

  Future<void> signOut() async {
    await _quietly(onSignedOut);
    await _run(_gateway.signOut);
  }

  /// At app start: signs back in with the saved login, if any.
  Future<bool> restore() async {
    final restored = await _gateway.restore();
    if (restored) await _quietly(onSignedIn);
    return restored;
  }

  Future<String?> accessToken() => _gateway.accessToken();

  Future<void> _afterSignIn() async {
    if (!await _run(_gateway.hasProfile)) {
      await _run(_gateway.signOut);
      throw const AuthFailure(noInstitutionMessage);
    }
    await _quietly(onSignedIn);
  }

  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('ConsentLink sync could not start or stop: $error');
    }
  }

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AuthFailure {
      rethrow;
    } on AuthRetryableFetchException {
      throw const AuthFailure(_offline);
    } on AuthException catch (e) {
      throw switch (e.code) {
        'invalid_credentials' => const AuthFailure(
          'That email and password don’t match. Check them and try again.',
        ),
        'email_not_confirmed' => const AuthFailure(
          'Confirm your email first. We sent you a 6-digit code.',
          needsConfirmation: true,
        ),
        'user_already_exists' || 'email_exists' => const AuthFailure(
          'There is already an account for this email. Log in instead.',
        ),
        'otp_expired' => const AuthFailure(
          'That code is wrong or has expired. Check it, or request a new one.',
        ),
        'weak_password' => const AuthFailure(
          'Choose a stronger password: at least 8 characters, not a common one.',
        ),
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          const AuthFailure('Too many tries. Wait a minute, then try again.'),
        _ => AuthFailure(e.message),
      };
    } on SocketException {
      throw const AuthFailure(_offline);
    } on ClientException {
      throw const AuthFailure(_offline);
    } on PostgrestException {
      throw const AuthFailure(
        'ConsentLink’s server could not answer. Try again in a minute.',
      );
    } on TimeoutException {
      throw const AuthFailure(_offline);
    }
  }

  static const _offline =
      'No internet connection. Log in once while online; after that '
      'ConsentLink works offline.';
}

const _sessionKey = 'consentlink_session_v1';

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this.client, this.store) {
    // Keep the login in the keystore so the app opens signed in offline.
    client.auth.onAuthStateChange.listen((state) {
      final session = state.session;
      if (state.event == AuthChangeEvent.signedOut) {
        store.delete(_sessionKey);
      } else if (session != null) {
        store.write(_sessionKey, jsonEncode(session.toJson()));
      }
    }, onError: (_) {});
  }

  final SupabaseClient client;
  final KeyStore store;

  @override
  Future<String?> institutionForDomain(String domain) async =>
      await client.rpc('institution_for_domain', params: {'p_domain': domain})
          as String?;

  @override
  Future<void> signUp(String email, String password, String name) => client.auth
      .signUp(email: email, password: password, data: {'name': name});

  @override
  Future<void> verifySignupCode(String email, String code) =>
      client.auth.verifyOTP(type: OtpType.signup, email: email, token: code);

  @override
  Future<void> resendSignupCode(String email) =>
      client.auth.resend(type: OtpType.signup, email: email);

  @override
  Future<void> signIn(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  @override
  Future<bool> hasProfile() async {
    final id = client.auth.currentUser?.id;
    if (id == null) return false;
    final row = await client
        .from('profiles')
        .select('id')
        .eq('id', id)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<void> signOut() => client.auth.signOut();

  @override
  Future<String?> accessToken() async {
    final session = client.auth.currentSession;
    if (session != null && session.isExpired) {
      try {
        return (await client.auth.refreshSession()).session?.accessToken;
      } on AuthException {
        return null;
      }
    }
    return session?.accessToken;
  }

  @override
  Future<bool> restore() async {
    final saved = await store.read(_sessionKey);
    if (saved == null || saved.isEmpty) return false;
    try {
      await client.auth.recoverSession(saved);
      return true;
    } on AuthRetryableFetchException {
      // No signal: keep the login; sync waits until it can refresh.
      return true;
    } on AuthException {
      await store.delete(_sessionKey);
      return false;
    }
  }
}
