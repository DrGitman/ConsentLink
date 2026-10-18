import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
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
          // Every tab draws its own Figma header (Capture since 13.7).
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
