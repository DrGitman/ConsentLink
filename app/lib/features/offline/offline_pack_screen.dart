import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../ai/ai_providers.dart';
import '../../ai/service/device_memory.dart';
import '../../ai/tts/audio_source.dart';
import '../../contracts/languages.dart';
import '../../core/widgets/app_back_button.dart';
import '../auth/widgets/auth_button.dart';
import '../preferences/accessibility_preferences.dart';
import 'language_packs.dart';
import 'model_download.dart';

/// Figma 02.6 Offline pack: the on-device AI model and the reviewed
/// language packs, downloaded once on Wi-Fi. Downloads keep going after the
/// screen closes and resume where they stopped.
class OfflinePackScreen extends ConsumerWidget {
  const OfflinePackScreen({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/researcher-details');
    }
  }

  Future<void> _downloadAll(BuildContext context, WidgetRef ref) async {
    final model = ref.read(modelDownloadProvider.notifier);
    final remote = ref.read(remotePacksProvider).valueOrNull ?? const {};
    final installed = ref.read(installedPacksProvider).valueOrNull ?? const {};
    for (final pack in remote.values) {
      final have = installed[pack.language];
      if (have == null || have.version != pack.version) {
        try {
          await installPack(ref, pack);
        } catch (_) {
          // The row shows it as not installed; the rest still installs.
        }
      }
    }
    // The model downloads in the background; continue right away.
    model.start();
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final largerTargets = ref.watch(largerTouchTargetsProvider);
    final backSpace = largerTargets ? 64.0 : 48.0;
    final model = ref.watch(modelDownloadProvider);
    final remote = ref.watch(remotePacksProvider);
    final installed = ref.watch(installedPacksProvider).valueOrNull ?? const {};
    final pending = [
      for (final p in remote.valueOrNull?.values ?? const <RemotePack>[])
        if (installed[p.language]?.version != p.version) p,
    ];
    final needsModel = model.phase != ModelDownloadPhase.installed;
    final anything = needsModel || pending.isNotEmpty;

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
                    'Step 3 of 3 · download on Wi-Fi, then no internet is needed',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _ModelCard(),
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
                        for (final (i, l) in consentLanguages.indexed) ...[
                          if (i > 0) const SizedBox(height: 6),
                          _LanguageRow(
                            language: l,
                            largerTargets: largerTargets,
                            remote: remote,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    remote.isLoading
                        ? 'Checking the reviewed language packs…'
                        : remote.hasError
                        ? 'Language packs could not be checked. Connect to the internet and come back.'
                        : 'Only sections a first-language or fluent reviewer checked are '
                              'downloaded. A language with no reviewed pack yet shows its '
                              'English form.',
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: AuthButton(
                label: anything ? 'Download & continue' : 'Continue',
                icon: anything
                    ? SvgPicture.asset(
                        'assets/icons/offline/download.svg',
                        width: 20,
                        height: 20,
                        excludeFromSemantics: true,
                        colorFilter: ColorFilter.mode(
                          colors.onPrimary,
                          BlendMode.srcIn,
                        ),
                      )
                    : null,
                onPressed: anything
                    ? () => _downloadAll(context, ref)
                    : () => context.go('/home'),
              ),
            ),
            if (anything)
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Skip for now'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

final _memoryProvider = FutureProvider<int?>((ref) => readTotalMemoryBytes());

String formatBytes(int bytes) {
  if (bytes >= 1000000000) {
    return '${(bytes / 1000000000).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1000000) return '${(bytes / 1000000).toStringAsFixed(0)} MB';
  if (bytes >= 1000) return '${(bytes / 1000).toStringAsFixed(0)} KB';
  return '$bytes B';
}

String _left(Duration d) => d.inMinutes >= 1
    ? '${d.inMinutes} min left'
    : '${d.inSeconds.clamp(1, 59)} s left';

class _ModelCard extends ConsumerWidget {
  const _ModelCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final s = ref.watch(modelDownloadProvider);
    final control = ref.read(modelDownloadProvider.notifier);
    final memory = ref.watch(_memoryProvider).valueOrNull;
    final enough = memory == null || memory >= minimumMemoryBytes;
    final percent = (s.progress * 100).floor();
    final status = switch (s.phase) {
      ModelDownloadPhase.installed => 'Installed · works with no internet',
      ModelDownloadPhase.downloading =>
        '$percent%${s.remaining == null ? '' : ' · ${_left(s.remaining!)}'}',
      ModelDownloadPhase.paused =>
        'Paused at $percent% · ${formatBytes(s.received)} kept',
      ModelDownloadPhase.verifying => 'Checking the file is intact…',
      ModelDownloadPhase.failed => s.error ?? 'The download stopped.',
      ModelDownloadPhase.notInstalled => 'Not downloaded',
    };
    final (label, action) = switch (s.phase) {
      ModelDownloadPhase.notInstalled => ('Download', control.start),
      ModelDownloadPhase.downloading => ('Pause', control.pause),
      ModelDownloadPhase.paused ||
      ModelDownloadPhase.failed => ('Resume', control.start),
      ModelDownloadPhase.verifying => ('Checking…', null),
      ModelDownloadPhase.installed => (
        'Remove',
        () => _confirmRemove(context, control),
      ),
    };
    return Container(
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
                      'Gemma 4 E2B · ${formatBytes(s.total)} · runs privately on this phone',
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
              value: s.phase == ModelDownloadPhase.verifying
                  ? null
                  : s.progress,
              minHeight: 10,
              backgroundColor: colors.outlineVariant,
              semanticsLabel: 'AI model download',
              semanticsValue: '$percent%',
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              status,
              style: TextStyle(
                fontSize: 13,
                color: s.phase == ModelDownloadPhase.failed
                    ? colors.error
                    : colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Wraps onto two lines with large text instead of squeezing.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _Badge(
                icon: enough ? 'check' : 'warn',
                label: enough
                    ? 'Recommended for 6 GB+ RAM'
                    : 'This phone has ${(memory / (1 << 30)).toStringAsFixed(1)} GB RAM: '
                          'drafting needs 6 GB',
                good: enough,
              ),
              TextButton(onPressed: action, child: Text(label)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    ModelDownloadController control,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove the AI model?'),
        content: const Text(
          'This frees about 3 GB. Drafting, simpler wording and the template '
          'assistant use plain rules until you download it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await control.remove();
  }
}

/// How a language can be read aloud on this phone.
final voiceLabelProvider = FutureProvider.family<String, String>((
  ref,
  code,
) async {
  try {
    final source = await ref.watch(readAloudServiceProvider).resolve(code);
    return switch (source) {
      DeviceTts() => 'Text + voice',
      RecordedAudio() => 'Text + recorded audio',
      NoAudio(reason: NoAudioReason.voiceNotInstalled) =>
        'Text · install the voice in phone settings',
      NoAudio() => 'Text only · no voice on this phone yet',
    };
  } catch (_) {
    return 'Text only';
  }
});

class _LanguageRow extends ConsumerWidget {
  const _LanguageRow({
    required this.language,
    required this.largerTargets,
    required this.remote,
  });

  final ConsentLanguage language;
  final bool largerTargets;
  final AsyncValue<Map<String, RemotePack>> remote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final voice =
        ref.watch(voiceLabelProvider(language.code)).valueOrNull ?? '…';
    final installed = ref
        .watch(installedPacksProvider)
        .valueOrNull?[language.code];
    final pack = remote.valueOrNull?[language.code];
    final english = language.code == 'en';
    final Widget badge;
    if (english ||
        (installed != null && installed.version == pack?.version) ||
        (installed != null && pack == null)) {
      badge = const _Badge(icon: 'check', label: 'Ready', good: true);
    } else if (pack != null) {
      badge = InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () async {
          try {
            await installPack(ref, pack);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'The ${language.displayName} pack could not be read.',
                  ),
                ),
              );
            }
          }
        },
        child: _Badge(
          icon: 'download',
          label: installed == null ? formatBytes(pack.bytes) : 'Update',
        ),
      );
    } else {
      badge = _Badge(
        icon: 'none',
        label: remote.isLoading ? 'Checking…' : 'Not reviewed yet',
      );
    }
    final subtitle = english
        ? voice
        : installed != null
        ? '$voice · ${installed.participantSections.length} reviewed sections'
        : voice;
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language.displayName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
    final stacked = MediaQuery.textScalerOf(context).scale(15) > 20;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: largerTargets ? 72 : 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [label, const SizedBox(height: 6), badge],
              )
            : Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 8),
                  badge,
                ],
              ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, this.good = false});

  final String icon;
  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = good ? const Color(0xFFE3F4EA) : colors.primaryContainer;
    final ink = good ? const Color(0xFF1C6B3E) : colors.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == 'download')
            SvgPicture.asset(
              'assets/icons/offline/download.svg',
              width: 15,
              height: 15,
              excludeFromSemantics: true,
              colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
            )
          else if (icon == 'check')
            Icon(Icons.check, size: 15, color: ink)
          else if (icon == 'warn')
            Icon(Icons.warning_amber_rounded, size: 15, color: ink),
          if (icon != 'none') const SizedBox(width: 4),
          Flexible(
            child: Text(label, style: TextStyle(fontSize: 12, color: ink)),
          ),
        ],
      ),
    );
  }
}
