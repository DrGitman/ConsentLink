import 'package:consentlink/data/auth/auth_providers.dart';
import 'package:consentlink/data/auth/auth_service.dart';
import 'package:consentlink/features/auth/check_email_screen.dart';
import 'package:consentlink/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase/supabase.dart' show AuthException, PostgrestException;

class _Gateway implements AuthGateway {
  bool profile = true;
  bool confirmed = true;
  int resent = 0;
  @override
  Future<String?> institutionForDomain(String domain) async => 'NUST';
  @override
  Future<void> signUp(String email, String password, String name) async {}
  @override
  Future<void> verifySignupCode(String email, String code) async {}
  @override
  Future<void> resendSignupCode(String email) async => resent++;
  @override
  Future<void> signIn(String email, String password) async {
    if (!confirmed) {
      throw const AuthException(
        'Email not confirmed',
        code: 'email_not_confirmed',
      );
    }
  }

  @override
  Future<bool> hasProfile() async => profile;
  @override
  Future<void> signOut() async {}
  @override
  Future<String?> accessToken() async => 'jwt';
  @override
  Future<bool> restore() async => false;
}

class _Lookup extends _Gateway {
  _Lookup(this.error);
  final Object error;
  @override
  Future<String?> institutionForDomain(String domain) async => throw error;
}

void main() {
  late _Gateway gateway;
  late List<String> events;
  late AuthService auth;
  setUp(() {
    gateway = _Gateway();
    events = [];
    auth = AuthService(
      gateway,
      onSignedIn: () async => events.add('sync started'),
      onSignedOut: () async {},
    );
  });

  Future<void> logIn(WidgetTester tester, String email) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/home', builder: (_, _) => const Text('Home page')),
        GoRoute(
          path: '/check-email',
          builder: (_, state) =>
              CheckEmailScreen(email: state.extra! as String),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, email);
    await tester.enterText(find.byType(TextFormField).last, 'pw');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
  }

  testWidgets('logging in starts sync and opens Home', (tester) async {
    await logIn(tester, 'ana@nust.na');
    expect(find.text('Home page'), findsOneWidget);
    expect(events, ['sync started']);
  });

  test('lost connection or a server error is a plain message', () async {
    for (final error in [
      ClientException('Proxy failed to establish tunnel'),
      const PostgrestException(message: 'Could not find the function'),
    ]) {
      final failing = AuthService(
        _Lookup(error),
        onSignedIn: () async {},
        onSignedOut: () async {},
      );
      await expectLater(
        failing.signUp(name: 'A', email: 'a@nust.na', password: 'pw'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            isNot(contains('Exception')),
          ),
        ),
      );
    }
  });

  testWidgets('an unconfirmed email gets the link again and says what to do', (
    tester,
  ) async {
    gateway.confirmed = false;
    await logIn(tester, 'ana@nust.na');
    expect(gateway.resent, 1);
    expect(
      find.textContaining('tap the confirmation link, then log in'),
      findsOneWidget,
    );
    expect(events, isEmpty, reason: 'not signed in, so no sync');

    await tester.tap(find.text('Resend email'));
    await tester.pumpAndSettle();
    expect(gateway.resent, 2);
    expect(find.text('Email sent again to ana@nust.na.'), findsOneWidget);

    await tester.tap(find.text('Go to log in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
