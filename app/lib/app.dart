import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'core/motion/app_motion.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme_provider.dart';

class ConsentLinkApp extends ConsumerWidget {
  const ConsentLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                ? AppMotion.reduced
                : AppMotion.slow,
            themeAnimationCurve: reduceMotion
                ? Curves.linear
                : AppMotion.slowCurve,
            routerConfig: ref.watch(appRouterProvider),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    );
  }
}
