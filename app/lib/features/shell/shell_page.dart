import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';

enum ShellDestination { home, projects, capture, insights, me }

class ShellPage extends StatelessWidget {
  const ShellPage({required this.destination, super.key});

  final ShellDestination destination;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final (title, description, icon) = switch (destination) {
      ShellDestination.home => (
        strings.homeTitle,
        strings.homeDescription,
        Icons.assignment_outlined,
      ),
      ShellDestination.projects => (
        strings.projectsTitle,
        strings.projectsDescription,
        Icons.folder_outlined,
      ),
      ShellDestination.capture => (
        strings.captureTitle,
        strings.captureDescription,
        Icons.mic_none_outlined,
      ),
      ShellDestination.insights => (
        strings.insightsTitle,
        strings.insightsDescription,
        Icons.bar_chart_outlined,
      ),
      ShellDestination.me => (
        strings.meTitle,
        strings.meDescription,
        Icons.person_outline,
      ),
    };

    return SingleChildScrollView(
      key: PageStorageKey(destination),
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  title,
                  key: ValueKey('page-title-${destination.name}'),
                  style: theme.textTheme.headlineLarge,
                ),
              ),
              const SizedBox(height: 16),
              Text(description, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 32),
              if (destination == ShellDestination.home) ...[
                _InformationCard(
                  title: strings.workspaceTitle,
                  description: strings.workspaceDescription,
                ),
                const SizedBox(height: 16),
              ],
              _InformationCard(
                title: strings.foundationNotice,
                description: strings.foundationDescription,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
