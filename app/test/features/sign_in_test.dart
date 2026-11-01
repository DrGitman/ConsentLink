import 'package:consentlink/data/auth/auth_providers.dart';
import 'package:consentlink/data/auth/auth_service.dart';
import 'package:consentlink/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase/supabase.dart' show PostgrestException;

class _Gateway implements AuthGateway {
  bool profile = true;
  @override
  Future<String?> institutionForDomain(String domain) async => 'NUST';
  @override
  Future<void> signUp(String email, String password, String name) async {}
  @override
  Future<void> verifySignupCode(String email, String code) async {}
  @override
  Future<void> resendSignupCode(String email) async {}
  @override
  Future<void> signIn(String email, String password) async {}
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

  testWidgets('an account with no institution is told why', (tester) async {
    gateway.profile = false;
    await logIn(tester, 'a@gmail.com');
    expect(find.text(noInstitutionMessage), findsOneWidget);
    expect(find.text('Home page'), findsNothing);
    expect(events, isEmpty);
  });
}
