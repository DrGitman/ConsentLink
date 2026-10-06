import 'package:consentlink/app.dart';
import 'package:consentlink/features/splash/splash_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitForSplashToComplete(WidgetTester tester) async {
  final splashFinder = find.byType(SplashScreen);
  var splashWasMounted = splashFinder.evaluate().isNotEmpty;

  for (var attempt = 0; attempt < 200; attempt++) {
    if (splashFinder.evaluate().isNotEmpty) {
      splashWasMounted = true;
    } else if (splashWasMounted) {
      return;
    }

    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }

  throw TestFailure('The ConsentLink splash did not finish and navigate away.');
}

Future<void> pumpConsentLinkApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: ConsentLinkApp()));
  await tester.pump();
  await waitForSplashToComplete(tester);
  await tester.pumpAndSettle();
}
