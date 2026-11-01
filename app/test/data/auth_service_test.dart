import 'dart:io';

import 'package:consentlink/data/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

class _FakeGateway implements AuthGateway {
  final calls = <String>[];
  String? institution = 'NUST';
  bool profile = true;
  Object? signInError;

  @override
  Future<String?> institutionForDomain(String domain) async {
    calls.add('lookup $domain');
    return institution;
  }

  @override
  Future<void> signUp(String email, String password, String name) async =>
      calls.add('signUp $email $name');
  @override
  Future<void> verifySignupCode(String email, String code) async =>
      calls.add('verify $code');
  @override
  Future<void> resendSignupCode(String email) async => calls.add('resend');
  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signIn');
    if (signInError != null) throw signInError!;
  }

  @override
  Future<bool> hasProfile() async => profile;
  @override
  Future<void> signOut() async => calls.add('signOut');
  @override
  Future<String?> accessToken() async => 'jwt';
  @override
  Future<bool> restore() async => true;
}

void main() {
  late _FakeGateway gateway;
  late List<String> events;
  late AuthService auth;
  setUp(() {
    gateway = _FakeGateway();
    events = [];
    auth = AuthService(
      gateway,
      onSignedIn: () async => events.add('sync started'),
      onSignedOut: () async => events.add('sync stopped'),
    );
  });

  test('sign-up checks the email domain first', () async {
    await auth.signUp(name: ' Ana ', email: 'ana@NUST.na', password: 'pw');
    expect(gateway.calls, ['lookup nust.na', 'signUp ana@NUST.na Ana']);
  });

  test('a domain with no institution is told so, no account made', () async {
    gateway.institution = null;
    await expectLater(
      auth.signUp(name: 'A', email: 'a@gmail.com', password: 'pw'),
      throwsA(
        isA<AuthFailure>().having(
          (f) => f.message,
          'message',
          contains('nust.na'),
        ),
      ),
    );
    expect(gateway.calls, ['lookup gmail.com']);
  });

  test(
    'log-in starts sync; log-out stops it before the session ends',
    () async {
      await auth.signIn('ana@nust.na', 'pw');
      await auth.signOut();
      expect(events, ['sync started', 'sync stopped']);
      expect(gateway.calls.last, 'signOut');
    },
  );

  test('the right code confirms the email and signs in', () async {
    await auth.confirm('ana@nust.na', '123456');
    expect(gateway.calls, ['verify 123456']);
    expect(events, ['sync started']);
  });

  test('an account without an institution is signed out again', () async {
    gateway.profile = false;
    await expectLater(
      auth.signIn('old@gmail.com', 'pw'),
      throwsA(isA<AuthFailure>()),
    );
    expect(gateway.calls, ['signIn', 'signOut']);
    expect(events, isEmpty, reason: 'sync never starts');
  });

  test('Supabase errors become plain messages', () async {
    Future<AuthFailure> failure(Object error) async {
      gateway.signInError = error;
      try {
        await auth.signIn('a@nust.na', 'pw');
      } on AuthFailure catch (f) {
        return f;
      }
      fail('expected an AuthFailure');
    }

    final wrong = await failure(
      const AuthException('Invalid login', code: 'invalid_credentials'),
    );
    expect(wrong.message, contains('don’t match'));
    final unconfirmed = await failure(
      const AuthException('Email not confirmed', code: 'email_not_confirmed'),
    );
    expect(unconfirmed.needsConfirmation, isTrue);
    expect(
      (await failure(const SocketException('offline'))).message,
      contains('No internet'),
    );
  });

  test('a sync failure never blocks signing in', () async {
    final failing = AuthService(
      gateway,
      onSignedIn: () async => throw StateError('no PowerSync'),
      onSignedOut: () async {},
    );
    await failing.signIn('ana@nust.na', 'pw');
  });
}
