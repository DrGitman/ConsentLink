import 'package:consentlink/core/widgets/screen_skeletons.dart';
import 'package:consentlink/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpBox(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('skeleton waits 300 ms, explains after 3 s, then fades out', (
    tester,
  ) async {
    final loading = ValueNotifier(true);
    addTearDown(loading.dispose);
    await pumpBox(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: loading,
        builder: (context, value, _) => SkeletonSwitch(
          loading: value,
          label: 'Loading projects',
          skeleton: const ProjectsSkeleton(),
          child: const Text('Loaded'),
        ),
      ),
    );
    // Nothing flashes for quick loads.
    expect(find.byType(ProjectsSkeleton), findsNothing);
    expect(find.text('Loaded'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(ProjectsSkeleton), findsOneWidget);
    expect(find.bySemanticsLabel('Loading projects'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue); // shimmer

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Decrypting records on this phone…'), findsOneWidget);

    loading.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Loaded'), findsOneWidget);
    expect(find.byType(ProjectsSkeleton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick loads never show the skeleton', (tester) async {
    final loading = ValueNotifier(true);
    addTearDown(loading.dispose);
    await pumpBox(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: loading,
        builder: (context, value, _) => SkeletonSwitch(
          loading: value,
          label: 'Loading',
          skeleton: const MeSkeleton(),
          child: const Text('Loaded'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    loading.value = false;
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(MeSkeleton), findsNothing);
    expect(find.text('Loaded'), findsOneWidget);
  });

  testWidgets('reduce motion: static blocks, no shimmer', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpBox(
      tester,
      const SkeletonSwitch(
        loading: true,
        label: 'Loading',
        skeleton: InsightsSkeleton(),
        child: SizedBox(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(InsightsSkeleton), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('LOADING_PREVIEW pretends to load, then shows content', (
    tester,
  ) async {
    await pumpBox(
      tester,
      PreviewLoad(
        builder: (context, loading) => SkeletonSwitch(
          loading: loading,
          label: 'Loading',
          skeleton: const DashboardSkeleton(),
          child: const Text('Loaded'),
        ),
      ),
      overrides: [
        loadingPreviewProvider.overrideWithValue(true),
        loadingPreviewDurationProvider.overrideWithValue(
          const Duration(seconds: 1),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DashboardSkeleton), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Loaded'), findsOneWidget);
    expect(find.byType(DashboardSkeleton), findsNothing);
  });

  for (final width in [390.0, 320.0, 600.0]) {
    testWidgets('every skeleton fits at $width dp', (tester) async {
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.toString());
      await pumpBox(
        tester,
        const Column(
          children: [
            DashboardSkeleton(),
            ProjectsSkeleton(),
            ProjectDetailSkeleton(),
            ReviewDraftSkeleton(),
            InsightsSkeleton(),
            TemplatesSkeleton(tint: Color(0xFFC9D0EA), ink: Color(0xFFB5BEDE)),
            ConsentRecordSkeleton(),
            MeSkeleton(),
          ],
        ),
        width: width,
      );
      FlutterError.onError = previous;
      expect(errors, isEmpty);
    });
  }
}
