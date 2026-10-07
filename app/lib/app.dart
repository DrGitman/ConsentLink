import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme_provider.dart';
import 'features/preferences/accessibility_preferences.dart';

class ConsentLinkApp extends ConsumerWidget {
  const ConsentLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(appTextScaleProvider);

    return MediaQuery.fromView(
      view: View.of(context),
      child: Builder(
        builder: (context) {
          final reduceMotion = MediaQuery.disableAnimationsOf(context);

          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (context) {
              return AppLocalizations.of(context).appName;
            },
            theme: ref.watch(appThemeProvider),
            themeAnimationDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 120),
            themeAnimationCurve: Curves.easeOut,
            routerConfig: ref.watch(appRouterProvider),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) {
              final media = MediaQuery.of(context);

              return MediaQuery(
                data: media.copyWith(
                  textScaler: _AppTextScaler(
                    system: media.textScaler,
                    multiplier: textScale,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}

class _AppTextScaler extends TextScaler {
  const _AppTextScaler({required this.system, required this.multiplier});

  final TextScaler system;
  final double multiplier;

  @override
  double scale(double fontSize) => system.scale(fontSize) * multiplier;

  @override
  double get textScaleFactor => scale(14) / 14;
}
