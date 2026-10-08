import 'package:consentlink/features/auth/widgets/auth_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('press animates and invokes the action once', (tester) async {
    var presses = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AuthButton(label: 'Log in', onPressed: () => presses++),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Log in')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.97,
    );
    expect(presses, 0);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(presses, 1);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });
}
