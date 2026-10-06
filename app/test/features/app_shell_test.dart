import 'package:consentlink/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' show SemanticsAction;

void main() {
  testWidgets('all five phone destinations can be opened', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: ConsentLinkApp()));
    await tester.pumpAndSettle();

    const destinations = ['home', 'projects', 'capture', 'insights', 'me'];

    for (var index = 0; index < destinations.length; index++) {
      await tester.tap(find.byKey(ValueKey('nav-$index')));
      await tester.pumpAndSettle();

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

    await tester.pumpWidget(const ProviderScope(child: ConsentLinkApp()));
    await tester.pumpAndSettle();

    for (var index = 0; index < 5; index++) {
      await tester.tap(find.byKey(ValueKey('nav-$index')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('wide layouts use the side navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: ConsentLinkApp()));
    await tester.pumpAndSettle();

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
      await tester.pumpWidget(const ProviderScope(child: ConsentLinkApp()));
      await tester.pumpAndSettle();

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
