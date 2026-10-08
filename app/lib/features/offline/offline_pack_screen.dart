import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_back_button.dart';
import '../auth/widgets/auth_button.dart';
import '../preferences/accessibility_preferences.dart';

/// The setup UI until verified pack artifacts and a downloader are available.
/// No timer, installation flag or progress value represents a fake download.
class OfflinePackScreen extends ConsumerWidget {
  const OfflinePackScreen({super.key});

  static const _languages = [
    'English',
    'Otjiherero',
    'Khoekhoegowab',
    'Afrikaans',
    'Rukwangali',
    'Silozi',
    'Oshiwambo',
    'Deutsch',
  ];

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/researcher-details');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final largerTargets = ref.watch(largerTouchTargetsProvider);
    final backSpace = largerTargets ? 64.0 : 48.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Row(
                children: [
                  AppBackButton(onPressed: () => _back(context)),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text(
                        'Get ready for the field',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: backSpace),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: 1,
                      minHeight: 6,
                      color: colors.primary,
                      semanticsLabel: 'Setup step 3 of 3',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Step 3 of 3 · offline downloads are not connected yet',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ModelCard(colors: colors),
                  const SizedBox(height: 14),
                  const Text(
                    'Languages for forms & read-aloud',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        for (var index = 0; index < 4; index++) ...[
                          if (index > 0) const SizedBox(height: 6),
                          _LanguageRow(
                            name: _languages[index],
                            largerTargets: largerTargets,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '+ ${_languages.skip(4).join(', ')} planned',
                    style: TextStyle(fontSize: 13, color: colors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No AI or language pack has been installed. You can continue '
                    'using the app preview without downloading anything.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: AuthButton(
                label: 'Continue without pack',
                onPressed: () => context.go('/home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 176),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SvgPicture.asset(
                  'assets/icons/offline/sparkle.svg',
                  width: 22,
                  height: 22,
                  excludeFromSemantics: true,
                  colorFilter: ColorFilter.mode(
                    colors.onPrimaryContainer,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'On-device AI assistant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Model package and device requirements are not configured.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: 0,
              minHeight: 10,
              backgroundColor: colors.outlineVariant,
              semanticsLabel: 'Offline model not downloaded',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Not downloaded',
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          const _PendingBadge(label: 'Download setup pending'),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.name, required this.largerTargets});

  final String name;
  final bool largerTargets;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stacked = MediaQuery.textScalerOf(context).scale(15) > 20;
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          'Pack not installed',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: largerTargets ? 72 : 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  const SizedBox(height: 6),
                  const _PendingBadge(label: 'Pending'),
                ],
              )
            : Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 8),
                  const _PendingBadge(label: 'Pending'),
                ],
              ),
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/offline/download.svg',
            width: 15,
            height: 15,
            excludeFromSemantics: true,
            colorFilter: ColorFilter.mode(
              colors.onPrimaryContainer,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: colors.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
