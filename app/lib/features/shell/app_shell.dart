import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/motion/app_motion.dart';
import '../../core/widgets/app_icon.dart';
import 'animated_navigation_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _selectDestination(int index) {
    unawaited(HapticFeedback.selectionClick());

    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final destinations = [
      (strings.home, AppIconType.home),
      (strings.projects, AppIconType.folder),
      (strings.capture, AppIconType.mic),
      (strings.insights, AppIconType.chart),
      (strings.me, AppIconType.user),
    ];

    final selectedIndex = navigationShell.currentIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSideRail = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: AppBar(
            title: AnimatedSwitcher(
              duration: reduceMotion ? AppMotion.reduced : AppMotion.base,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: AlignmentDirectional.centerStart,
                  children: [
                    for (final child in previousChildren)
                      ExcludeSemantics(child: child),
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: Text(
                destinations[selectedIndex].$1,
                key: ValueKey('shell-title-$selectedIndex'),
              ),
            ),
          ),
          body: SafeArea(
            child: Row(
              children: [
                if (useSideRail) ...[
                  NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: _selectDestination,
                    labelType: NavigationRailLabelType.all,
                    minWidth: 112,
                    destinations: [
                      for (final destination in destinations)
                        NavigationRailDestination(
                          icon: AppIcon(destination.$2),
                          selectedIcon: AppIcon(
                            destination.$2,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                          label: Text(destination.$1),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(child: navigationShell),
              ],
            ),
          ),
          bottomNavigationBar: useSideRail
              ? null
              : AnimatedNavigationBar(
                  destinations: destinations,
                  selectedIndex: selectedIndex,
                  onSelected: _selectDestination,
                ),
        );
      },
    );
  }
}
