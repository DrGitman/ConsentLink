import 'dart:convert';
import 'dart:io';

import 'package:consentlink/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('reduced motion keeps the final artwork visible before leaving', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const ProviderScope(child: ConsentLinkApp()));
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      final animations = tester.widgetList<Lottie>(find.byType(Lottie));
      if (animations.length == 2 &&
              animations.every((animation) => animation.composition != null) ||
          find.byKey(const ValueKey('page-title-home')).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('consentlink-splash-animation')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('page-title-home')), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('page-title-home')), findsNothing);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-title-home')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the splash animation plays once before opening Home', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ConsentLinkApp()));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('consentlink-splash-animation')),
      findsOneWidget,
    );

    // Wait for parsing without advancing animation time.
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      final animations = tester.widgetList<Lottie>(find.byType(Lottie));
      if (animations.length == 2 &&
          animations.every((animation) => animation.composition != null)) {
        break;
      }
    }
    final animation = tester.widget<Lottie>(
      find.descendant(
        of: find.byKey(const ValueKey('consentlink-splash-animation')),
        matching: find.byType(Lottie),
      ),
    );
    expect(animation.composition, isNotNull);
    expect(animation.controller!.value, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(animation.controller!.value, closeTo(0.25, 0.02));
    expect(find.byKey(const ValueKey('page-title-home')), findsNothing);

    await tester.pump(const Duration(milliseconds: 2400));
    expect(animation.controller!.value, 1);
    await tester.pump(const Duration(milliseconds: 699));
    expect(find.byKey(const ValueKey('page-title-home')), findsNothing);
    await tester.pump(const Duration(milliseconds: 21));

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('page-title-home')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the splash asset excludes mock status-bar graphics', () async {
    final source = await File(
      'assets/animations/consentlink-splash.json',
    ).readAsString();
    final animation = jsonDecode(source) as Map<String, dynamic>;
    final layers = animation['layers'] as List<dynamic>;
    final layerNames = layers
        .map((layer) => (layer as Map<String, dynamic>)['nm'])
        .toList();

    expect(layerNames, isNot(contains('9:41')));
    expect(layerNames, isNot(contains('icon/wifi')));
    expect(layerNames, contains('Lang/Oshiwambo'));
    expect(layerNames, contains('Wordmark/0 C'));
    expect(layerNames, contains('Wordmark/7 L'));
    expect(layerNames, contains('Wordmark/10 k'));
  });

  test('splash text and loading dots share the screen centre', () async {
    final animation =
        jsonDecode(
              await File(
                'assets/animations/consentlink-splash.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final center = (animation['w'] as num) / 2;
    final layers = animation['layers'] as List;
    for (final layer in layers.where(
      (layer) =>
          layer['ty'] == 5 && !(layer['nm'] as String).startsWith('Wordmark/'),
    )) {
      final position = layer['ks']['p'];
      final positions = position['a'] == 0
          ? [position['k']]
          : (position['k'] as List).map((key) => key['s']);
      final text = layer['t']['d']['k'][0]['s'];
      for (final point in positions) {
        final textCenter =
            (point[0] as num) -
            (layer['ks']['a']['k'][0] as num) +
            (text['ps'][0] as num) +
            (text['sz'][0] as num) / 2;
        expect(textCenter, closeTo(center, 0.001), reason: layer['nm']);
      }
    }
    final dots = layers.where(
      (layer) => (layer['nm'] as String).startsWith('Dot '),
    );
    final dotsCenter =
        dots.fold<double>(
          0,
          (sum, layer) => sum + (layer['ks']['p']['k'][0] as num),
        ) /
        dots.length;
    expect(dotsCenter, center);
  });
}
