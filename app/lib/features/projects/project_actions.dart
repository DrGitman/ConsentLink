import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../contracts/models.dart' as m;
import '../../core/data/data_revision.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/local/app_database.dart' as db;
import '../../data/repositories/repository_providers.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../responses/responses_widgets.dart' show showOverlayToast;
import '../settings/settings_widgets.dart' show SettingsRow;
import '../templates/template_widgets.dart' show SheetHandle;
import 'project_data.dart';
import 'project_widgets.dart';

/// Search text on Projects (03.3). Null while the search field is closed.
final projectSearchProvider = StateProvider<String?>((ref) => null);

bool projectMatches(Project p, String query) {
  final q = query.trim().toLowerCase();
  return q.isEmpty ||
      p.title.toLowerCase().contains(q) ||
      p.languages.toLowerCase().contains(q) ||
      (p.ethicsRef?.toLowerCase().contains(q) ?? false);
}

/// Renames a study. Synced like every other change (title is editable on
/// the server too).
Future<void> renameStudy(WidgetRef ref, String id, String title) async {
  final database = await ref.read(appDatabaseProvider.future);
  await (database.update(database.studies)..where((s) => s.id.equals(id)))
      .write(db.StudiesCompanion(title: Value(title.trim())));
  ref.read(dataRevisionProvider.notifier).state++;
}

/// Closes a study: no new consent can be collected. Records stay.
/// Reopening puts it back to collecting (published) or draft.
Future<void> setStudyClosed(WidgetRef ref, String id, bool closed) async {
  final database = await ref.read(appDatabaseProvider.future);
  final row = await (database.select(
    database.studies,
  )..where((s) => s.id.equals(id))).getSingle();
  final status = closed ? 'closed' : (row.formVersion > 0 ? 'active' : 'draft');
  await (database.update(database.studies)..where((s) => s.id.equals(id)))
      .write(db.StudiesCompanion(status: Value(status)));
  ref.read(dataRevisionProvider.notifier).state++;
}

/// A new draft study with the same form text. Nothing is approved or
/// published in the copy, and no consent records come with it.
Future<String> duplicateStudy(WidgetRef ref, String id) async {
  final repo = await ref.read(studyRepositoryProvider.future);
  final source = (await repo.listStudies()).firstWhere((s) => s.id == id);
  final copy = await repo.createStudy(
    m.StudyDraft(
      title: 'Copy of ${source.title}',
      involvesMinors: source.involvesMinors,
    ),
  );
  for (final s in await repo.getSections(id)) {
    await repo.saveSection(
      m.ConsentSection(
        id: const Uuid().v4(),
        studyId: copy.id,
        order: s.order,
        language: s.language,
        text: s.text,
        sourcePage: s.sourcePage,
        sourceQuote: s.sourceQuote,
        changes: s.changes,
        confidence: s.confidence,
        requiredElement: s.requiredElement,
        status: m.SectionStatus.draft,
      ),
    );
  }
  ref.read(dataRevisionProvider.notifier).state++;
  return copy.id;
}

/// More options for a project (03.3 card ⋯ and 03.4 ⋯).
Future<void> showProjectMenu(
  BuildContext context,
  WidgetRef ref,
  Project project,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  useRootNavigator: true,
  backgroundColor: Colors.white,
  barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
  sheetAnimationStyle: sheetMotion(context),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (sheet) {
    void then(Future<void> Function() action) {
      Navigator.pop(sheet);
      action();
    }

    final closed = project.status == ProjectStatus.closed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 19),
          Text(
            project.title,
            style: dashboardText(20, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SettingsRow(
            icon: 'capture/users',
            title: 'Participants',
            subtitle: 'Age groups, guardians and assent',
            onTap: () => then(() async {
              context.push('/participants/${project.id}');
            }),
          ),
          SettingsRow(
            icon: 'form/type',
            title: 'Rename',
            subtitle: 'Change the project name',
            onTap: () => then(() => _rename(context, ref, project)),
          ),
          SettingsRow(
            icon: 'templates/copy',
            title: 'Duplicate',
            subtitle: 'A new draft with the same consent text',
            onTap: () => then(() => _duplicate(context, ref, project)),
          ),
          SettingsRow(
            icon: 'form/lock',
            title: closed ? 'Reopen project' : 'Close project',
            subtitle: closed
                ? 'Collect consent again'
                : 'Stop collecting. Records are kept',
            onTap: () => then(() => _close(context, ref, project, !closed)),
          ),
        ],
      ),
    );
  },
);

bool _previewOnly(BuildContext context, WidgetRef ref, String title) {
  if (!ref.read(projectsPreviewProvider)) return false;
  showProjectNotice(
    context,
    title,
    'Preview only: sample projects can\'t change.',
  );
  return true;
}

Future<void> _rename(
  BuildContext context,
  WidgetRef ref,
  Project project,
) async {
  if (_previewOnly(context, ref, 'Rename')) return;
  final controller = TextEditingController(text: project.title);
  final name = await showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Rename project'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Project name'),
        onSubmitted: (v) => Navigator.pop(dialog, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.trim().isEmpty || name.trim() == project.title) {
    return;
  }
  await renameStudy(ref, project.id, name);
  if (!context.mounted) return;
  showOverlayToast(
    context,
    kind: AppToastKind.success,
    title: 'Project renamed',
  );
}

Future<void> _duplicate(
  BuildContext context,
  WidgetRef ref,
  Project project,
) async {
  if (_previewOnly(context, ref, 'Duplicate')) return;
  final id = await duplicateStudy(ref, project.id);
  if (!context.mounted) return;
  showOverlayToast(
    context,
    kind: AppToastKind.success,
    title: 'Copy created',
    subtitle: 'Review and publish its form before collecting consent.',
  );
  context.go('/projects/$id');
}

Future<void> _close(
  BuildContext context,
  WidgetRef ref,
  Project project,
  bool close,
) async {
  if (_previewOnly(context, ref, close ? 'Close project' : 'Reopen project')) {
    return;
  }
  if (close) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Close this project?'),
        content: const Text(
          'No new consent can be collected. Every record and export stays, '
          'and you can reopen it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Close project'),
          ),
        ],
      ),
    );
    if (ok != true) return;
  }
  await setStudyClosed(ref, project.id, close);
  if (!context.mounted) return;
  showOverlayToast(
    context,
    kind: AppToastKind.info,
    title: close ? 'Project closed' : 'Project reopened',
  );
}
