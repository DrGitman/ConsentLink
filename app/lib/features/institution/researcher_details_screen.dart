import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/dictation_sheet.dart';
import '../auth/widgets/auth_button.dart';
import '../preferences/accessibility_preferences.dart';

final researcherDraftProvider = StateProvider<List<String>>(
  (ref) => List<String>.filled(6, ''),
);

class ResearcherDetailsScreen extends ConsumerStatefulWidget {
  const ResearcherDetailsScreen({super.key});

  @override
  ConsumerState<ResearcherDetailsScreen> createState() =>
      _ResearcherDetailsScreenState();
}

class _ResearcherDetailsScreenState
    extends ConsumerState<ResearcherDetailsScreen> {
  static const _voiceButtonSvg = '''
<svg width="36" height="36" viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="36" height="36" rx="18" fill="#E7F6F0"/>
  <path d="M20.5 13C20.5 11.6193 19.3807 10.5 18 10.5C16.6193 10.5 15.5 11.6193 15.5 13V17.1667C15.5 18.5474 16.6193 19.6667 18 19.6667C19.3807 19.6667 20.5 18.5474 20.5 17.1667V13Z" stroke="#168C69" stroke-width="1.66667" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M12.1666 17.1666C12.1666 18.7137 12.7812 20.1975 13.8752 21.2914C14.9691 22.3854 16.4529 23 18 23M18 23C19.5471 23 21.0308 22.3854 22.1247 21.2914C23.2187 20.1975 23.8333 18.7137 23.8333 17.1666M18 23V25.5" stroke="#168C69" stroke-width="1.66667" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  static const _labels = [
    'Title & name',
    'Student / staff number',
    'Faculty / department',
    'Phone (for participant queries)',
    'Supervisor name & email',
    'Languages you speak',
  ];

  static const _hints = [
    'Enter your title and full name',
    'Enter your student or staff number',
    'Enter your faculty or department',
    'For example, +264 81 000 0000',
    'Enter your supervisor’s name and email',
    'For example, English, Oshiwambo, Afrikaans',
  ];

  static const _icons = [
    'assets/icons/navigation/user.svg',
    'assets/icons/researcher/file.svg',
    'assets/icons/researcher/layers.svg',
    'assets/icons/researcher/info.svg',
    'assets/icons/researcher/users.svg',
    'assets/icons/researcher/globe.svg',
  ];

  late final List<TextEditingController> _controllers;
  bool _dictating = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(researcherDraftProvider);
    _controllers = [
      for (var index = 0; index < _labels.length; index++)
        TextEditingController(text: draft[index]),
    ];
  }

  void _rememberDraft() {
    ref.read(researcherDraftProvider.notifier).state = [
      for (final controller in _controllers) controller.text,
    ];
  }

  void _back() {
    _rememberDraft();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/institution');
    }
  }

  Future<void> _dictate(int index) async {
    if (_dictating) return;

    final controller = _controllers[index];
    final previous = controller.value;
    final selection = previous.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, previous.text.length).toInt()
        : previous.text.length;
    final end = selection.isValid
        ? selection.end.clamp(0, previous.text.length).toInt()
        : previous.text.length;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _dictating = true);

    try {
      final spoken = await showDictationSheet(
        context,
        fieldLabel: _labels[index],
      );

      if (!mounted || spoken == null || spoken.trim().isEmpty) return;

      final before = previous.text.substring(0, start);
      final after = previous.text.substring(end);
      final words = spoken.trim();

      final leadingSpace = before.isNotEmpty && !RegExp(r'\s$').hasMatch(before)
          ? ' '
          : '';
      final trailingSpace = after.isNotEmpty && !RegExp(r'^\s').hasMatch(after)
          ? ' '
          : '';

      final inserted = '$leadingSpace$words$trailingSpace';
      final updated = '$before$inserted$after';

      controller.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(
          offset: before.length + inserted.length,
        ),
      );

      _rememberDraft();
    } finally {
      if (mounted) setState(() => _dictating = false);
    }
  }

  void _continue() {
    FocusManager.instance.primaryFocus?.unfocus();
    _rememberDraft();
    context.push('/offline-pack');
  }

  void _skip() {
    FocusManager.instance.primaryFocus?.unfocus();
    _rememberDraft();
    context.push('/offline-pack');
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _svg(String path, Color color, {double size = 22}) {
    return ExcludeSemantics(
      child: SvgPicture.asset(
        path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }

  Widget _field(int index, bool largerTargets) {
    final colors = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.outline),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _labels[index],
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: largerTargets ? 72 : 54),
            child: TextField(
              controller: _controllers[index],
              readOnly: _dictating,
              keyboardType: index == 3
                  ? TextInputType.phone
                  : TextInputType.text,
              textInputAction: index == 5
                  ? TextInputAction.done
                  : TextInputAction.next,
              textCapitalization: index == 0 || index == 2
                  ? TextCapitalization.words
                  : TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: index != 1 && index != 3 && index != 4,
              style: TextStyle(fontSize: 15, color: colors.onSurface),
              textAlignVertical: TextAlignVertical.center,
              onChanged: (_) => _rememberDraft(),
              decoration: InputDecoration(
                hintText: _hints[index],
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: colors.onSurfaceVariant,
                ),
                filled: true,
                fillColor: colors.surface,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: largerTargets ? 20 : 16,
                ),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: largerTargets ? 60 : 54,
                  minHeight: largerTargets ? 72 : 54,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _svg(_icons[index], colors.onSurfaceVariant),
                ),
                suffixIconConstraints: BoxConstraints.tightFor(
                  width: largerTargets ? 72 : 56,
                  height: largerTargets ? 72 : 54,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Dictate ${_labels[index]}',
                  onPressed: _dictating ? null : () => _dictate(index),
                  padding: EdgeInsets.zero,
                  style: const ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                    shadowColor: WidgetStatePropertyAll(Colors.transparent),
                    elevation: WidgetStatePropertyAll(0),
                    splashFactory: NoSplash.splashFactory,
                  ),
                  icon: SizedBox.square(
                    dimension: largerTargets ? 44 : 36,
                    child: SvgPicture.string(_voiceButtonSvg),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final largerTargets = ref.watch(largerTouchTargetsProvider);
    final backSize = largerTargets ? 64.0 : 48.0;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 21;

    final skip = AuthButton(
      label: 'Skip for now',
      outlined: true,
      onPressed: _dictating ? null : _skip,
    );

    final next = AuthButton(
      label: 'Continue',
      onPressed: _dictating ? null : _continue,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Row(
                children: [
                  AppBackButton(onPressed: _back),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text(
                        'Researcher details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: backSize),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: 2 / 3,
                      minHeight: 6,
                      color: colors.primary,
                      backgroundColor: colors.outlineVariant,
                      semanticsLabel: 'Step 2 of 3',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Step 2 of 3 · shown on every consent form so '
                    'participants know who to contact',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var index = 0; index < _labels.length; index++)
                    _field(index, largerTargets),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: largeText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [skip, const SizedBox(height: 10), next],
                    )
                  : Row(
                      children: [
                        Expanded(child: skip),
                        const SizedBox(width: 10),
                        Expanded(child: next),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
