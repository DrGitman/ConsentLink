import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/dictation_sheet.dart';
import '../dashboard/dashboard_components.dart';
import 'consent_draft_data.dart';
import 'consent_widgets.dart';

/// 04.1 "Describe your study by voice or text": six short questions, one at
/// a time, typed or spoken. The answers are drafted like a proposal (04.2).
class GuidedQuestionsScreen extends ConsumerStatefulWidget {
  const GuidedQuestionsScreen({super.key});
  @override
  ConsumerState<GuidedQuestionsScreen> createState() =>
      _GuidedQuestionsScreenState();
}

class _GuidedQuestionsScreenState extends ConsumerState<GuidedQuestionsScreen> {
  final _controllers = [
    for (final _ in guidedQuestions) TextEditingController(),
  ];
  var _index = 0;

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController get _current => _controllers[_index];
  bool get _last => _index == guidedQuestions.length - 1;

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/new-consent');
    }
  }

  Future<void> _speak() async {
    final text = await showDictationSheet(
      context,
      fieldLabel: guidedQuestions[_index].$2,
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    final before = _current.text.trim();
    _current.text = before.isEmpty ? text.trim() : '$before ${text.trim()}';
  }

  void _next() {
    if (!_last) {
      setState(() => _index++);
      return;
    }
    ref.read(consentDraftProvider.notifier).useAnswers([
      for (final c in _controllers) c.text.trim(),
    ]);
    context.pushReplacement('/new-consent/drafting');
  }

  @override
  Widget build(BuildContext context) {
    final (_, question, hint) = guidedQuestions[_index];
    final primary = Theme.of(context).colorScheme.primary;
    final answered = _controllers.where((c) => c.text.trim().isNotEmpty).length;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 9, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConsentTopBar(
                    leading: AppBackButton(onPressed: _back),
                    title: 'Describe your study',
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (_index + 1) / guidedQuestions.length,
                      minHeight: 6,
                      color: primary,
                      backgroundColor: AppColors.line,
                      semanticsLabel:
                          'Question ${_index + 1} of ${guidedQuestions.length}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Question ${_index + 1} of ${guidedQuestions.length} · '
                    'type or tap the mic to speak',
                    style: dashboardText(13, color: AppColors.subtle),
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    header: true,
                    child: Text(
                      question,
                      style: dashboardText(24, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(hint, style: dashboardText(14, color: AppColors.subtle)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: TextField(
                              key: ValueKey('answer-$_index'),
                              controller: _current,
                              autofocus: true,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              textCapitalization: TextCapitalization.sentences,
                              style: dashboardText(17).copyWith(height: 1.4),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Your answer',
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: DashboardAction(
                              label: 'Speak your answer',
                              radius: 28,
                              color: primary,
                              onPressed: _speak,
                              child: const SizedBox.square(
                                dimension: 56,
                                child: Center(
                                  child: DashboardIcon(
                                    'mic',
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConsentPillButton(
                    icon: _last ? 'sparkle' : null,
                    label: _last ? 'Draft with on-device AI' : 'Next',
                    onPressed: _last && answered == 0 ? null : _next,
                  ),
                  if (!_last) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _index++),
                        child: const Text('Skip this question'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
