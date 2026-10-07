import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' show SemanticsAction;

import '../helpers/pump_consentlink_app.dart';

void main() {
  testWidgets('all five phone destinations can be opened', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpConsentLinkApp(tester);

    const destinations = ['home', 'projects', 'capture', 'insights', 'me'];

    for (var index = 0; index < destinations.length; index++) {
      final destination = find.byKey(ValueKey('nav-$index'));
      await tester.ensureVisible(destination);
      await tester.tap(destination);
      await tester.pumpAndSettle();

      final pillRect = tester.getRect(
        find.byKey(const ValueKey('nav-active-pill')),
      );
      final targetRect = tester.getRect(find.byKey(ValueKey('nav-$index')));

      expect(
        pillRect.center.dx,
        closeTo(targetRect.center.dx, 1),
        reason: 'The selected pill must align with its tab.',
      );

      expect(
        pillRect.bottom,
        greaterThan(700),
        reason: 'The navigation must remain near the bottom of the screen.',
      );

      expect(
        find.byKey(ValueKey('page-title-${destinations[index]}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('phone navigation works at 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpConsentLinkApp(tester);

    const destinations = ['home', 'projects', 'capture', 'insights', 'me'];

    for (var index = 0; index < destinations.length; index++) {
      final destination = find.byKey(ValueKey('nav-$index'));
      await tester.ensureVisible(destination);
      await tester.tap(destination);
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('page-title-${destinations[index]}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('wide layouts use the side navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpConsentLinkApp(tester);

    expect(find.byType(NavigationRail), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('page-title-projects')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation exposes an activation action to TalkBack', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await pumpConsentLinkApp(tester);

      for (var index = 0; index < 5; index++) {
        final node = tester.getSemantics(
          find.byKey(ValueKey('nav-semantics-$index')),
        );

        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason:
              'Navigation destination $index must support TalkBack activation.',
        );
      }
    } finally {
      semanticsHandle.dispose();
    }
  });
}
