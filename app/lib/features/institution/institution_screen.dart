import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/app_back_button.dart';
import '../auth/widgets/auth_button.dart';
import '../preferences/accessibility_preferences.dart';
import 'institution.dart';
import 'institution_preferences.dart';

class InstitutionScreen extends ConsumerStatefulWidget {
  const InstitutionScreen({super.key});

  @override
  ConsumerState<InstitutionScreen> createState() => _InstitutionScreenState();
}

class _InstitutionScreenState extends ConsumerState<InstitutionScreen> {
  final _search = TextEditingController();

  Institution? _institution;
  ResearchRole? _role;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _institution = ref.read(selectedInstitutionProvider);
    _role = ref.read(selectedResearchRoleProvider);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/sign-up');
    }
  }

  void _continue() {
    final institution = _institution;
    final role = _role;
    if (institution == null || role == null) return;

    FocusScope.of(context).unfocus();

    applyInstitutionSelection(ref, institution: institution, role: role);

    context.push('/researcher-details');
  }

  @override
  Widget build(BuildContext context) {
    final highContrast = ref.watch(highContrastProvider);
    final largerTargets = ref.watch(largerTouchTargetsProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final selected = _institution ?? Institution.independent;

    final theme = AppTheme.light(
      seed: selected.primary,
      accent: selected.accent,
      highContrast: highContrast,
      largerTouchTargets: largerTargets,
    );

    final query = _search.text.trim();
    final institutions = Institution.values
        .where((item) => item != Institution.independent)
        .where((item) => item.matches(query))
        .toList();

    final visible = query.isNotEmpty || _showAll
        ? institutions
        : institutions.take(4).toList();

    return AnimatedTheme(
      data: theme,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;

          return Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: Row(
                          children: [
                            AppBackButton(onPressed: _back),
                            Expanded(
                              child: Text(
                                'Your institution',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
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
                                value: 1 / 3,
                                minHeight: 6,
                                color: colors.primary,
                                backgroundColor: colors.outlineVariant,
                                semanticsLabel: 'Setup progress',
                                semanticsValue: 'Step 1 of 3',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Step 1 of 3',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _search,
                              onChanged: (_) => setState(() {}),
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Search institutions',
                                filled: true,
                                fillColor: colors.surface,
                                prefixIconConstraints: BoxConstraints(
                                  minWidth: 48,
                                  minHeight: largerTargets ? 72 : 48,
                                ),
                                suffixIconConstraints: BoxConstraints(
                                  minWidth: largerTargets ? 72 : 48,
                                  minHeight: largerTargets ? 72 : 48,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 22,
                                ),
                                suffixIcon: query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: () {
                                          _search.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 20,
                                        ),
                                      ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colors.outline),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: colors.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final institution in visible)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _InstitutionTile(
                                  institution: institution,
                                  selected: _institution == institution,
                                  largerTargets: largerTargets,
                                  onPressed: () {
                                    setState(() {
                                      _institution = institution;
                                    });
                                  },
                                ),
                              ),
                            if (visible.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Text(
                                  'No matching institutions. You can '
                                  'continue as independent.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                            Wrap(
                              spacing: 4,
                              children: [
                                if (query.isEmpty)
                                  TextButton(
                                    onPressed: () {
                                      setState(() => _showAll = !_showAll);
                                    },
                                    child: Text(
                                      _showAll ? 'Show fewer' : 'Show 2 more',
                                    ),
                                  ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _institution = Institution.independent;
                                    });
                                  },
                                  child: Text(
                                    _institution == Institution.independent
                                        ? 'Independent selected'
                                        : 'Continue as independent',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your role',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final role in ResearchRole.values)
                                  ChoiceChip(
                                    label: Text(role.label),
                                    selected: _role == role,
                                    showCheckmark: false,
                                    onSelected: (_) {
                                      setState(() => _role = role);
                                    },
                                    backgroundColor: colors.surface,
                                    selectedColor: colors.primary,
                                    labelStyle: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _role == role
                                          ? colors.onPrimary
                                          : colors.onSurface,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: largerTargets ? 22 : 8,
                                    ),
                                    shape: const StadiumBorder(),
                                    side: BorderSide(
                                      color: _role == role
                                          ? colors.primary
                                          : colors.outline,
                                    ),
                                    elevation: 0,
                                    pressElevation: 0,
                                    shadowColor: Colors.transparent,
                                    selectedShadowColor: Colors.transparent,
                                    surfaceTintColor: Colors.transparent,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 46,
                                    height: 46,
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: colors.primary,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: colors.secondary,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _institution == null
                                              ? 'Choose your institution'
                                              : selected ==
                                                    Institution.independent
                                              ? 'Keep ConsentLink colours'
                                              : 'App will switch to '
                                                    '${selected.label} colours',
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.3,
                                            fontWeight: FontWeight.w500,
                                            color: colors.onPrimaryContainer,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Your accessibility settings stay '
                                          'the same.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.3,
                                            color: colors.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: AuthButton(
                          label: 'Continue',
                          onPressed: _institution != null && _role != null
                              ? _continue
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InstitutionTile extends StatelessWidget {
  const _InstitutionTile({
    required this.institution,
    required this.selected,
    required this.largerTargets,
    required this.onPressed,
  });

  final Institution institution;
  final bool selected;
  final bool largerTargets;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? colors.primary : colors.outline,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: largerTargets ? 84 : 62),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: institution.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      institution.initials,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          institution.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          institution.fullName,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox.square(
                    dimension: 24,
                    child: selected
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primary,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: colors.onPrimary,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
