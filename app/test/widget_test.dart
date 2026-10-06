import 'package:consentlink/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the ConsentLink app opens on Home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ConsentLinkApp()));

    await tester.pumpAndSettle();

    final titleFinder = find.byKey(const ValueKey('shell-title-0'));

    expect(titleFinder, findsOneWidget);
    expect(tester.widget<Text>(titleFinder).data, 'Home');
    expect(find.byKey(const ValueKey('page-title-home')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme motion responds to the device accessibility setting', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);

    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(const ProviderScope(child: ConsentLinkApp()));
    await tester.pumpAndSettle();

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.themeAnimationDuration, const Duration(milliseconds: 400));

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.themeAnimationDuration, const Duration(milliseconds: 200));
    expect(app.themeAnimationCurve, Curves.linear);
    expect(tester.takeException(), isNull);
  });
}
