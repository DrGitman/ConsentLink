import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/app_toast.dart';
import '../dashboard/dashboard_components.dart';
import '../institution/institution_preferences.dart';
import '../institution/researcher_details_screen.dart'
    show researcherDraftProvider;
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../projects/project_widgets.dart';
import '../responses/responses_widgets.dart' show showOverlayToast;
import '../templates/template_widgets.dart' show SheetHandle, VoiceTextField;
import 'settings_data.dart';

/// Name and role shown on the Me card and the Account page.
({String name, String role, String initials}) profileIdentity(WidgetRef ref) {
  final preview = ref.watch(settingsPreviewProvider);
  final institution = ref.watch(selectedInstitutionProvider);
  final role = ref.watch(selectedResearchRoleProvider);
  final saved = ref.watch(researcherDraftProvider).first.trim();
  return (
    name: saved.isNotEmpty
        ? saved
        : preview
        ? 'Ndapewa Shikongo'
        : 'Your profile',
    role: preview
        ? 'Student researcher · ${institution?.label ?? 'NUST'}'
        : [role?.label ?? 'Researcher', ?institution?.label].join(' · '),
    initials: saved.isNotEmpty
        ? _initials(saved)
        : preview
        ? 'NS'
        : (institution?.initials ?? 'CL'),
  );
}

/// "Ms Ndapewa Shikongo" → "NS" (titles skipped).
String _initials(String name) {
  const titles = {'mr', 'mrs', 'ms', 'miss', 'dr', 'prof', 'rev'};
  final words = name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .where((w) => !titles.contains(w.toLowerCase().replaceAll('.', '')))
      .toList();
  if (words.isEmpty) return '?';
  final first = words.first[0];
  final last = words.length > 1 ? words.last[0] : '';
  return (first + last).toUpperCase();
}

/// Round profile picture: the saved photo, otherwise initials. Fades
/// between the two when the photo changes.
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({super.key, this.size = 60});
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(profilePhotoProvider);
    final preview = ref.watch(settingsPreviewProvider);
    final accent = ref.watch(institutionAccentProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final initials = profileIdentity(ref).initials;
    return SizedBox.square(
      dimension: size,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: reduceMotion(context) ? 0 : 250),
        child: photo != null
            ? ClipOval(
                key: ValueKey(photo.hashCode),
                child: Image.memory(
                  photo,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  semanticLabel: 'Profile photo',
                ),
              )
            : Container(
                key: const ValueKey('initials'),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: preview ? const Color(0xFFF9B21B) : accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials,
                  textScaler: TextScaler.noScaling,
                  style: dashboardText(
                    size / 3,
                    color: preview ? primary : Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Camera / gallery / remove sheet for the profile photo. The picture is
/// resized to 512 px and kept only on this phone.
Future<void> showProfilePhotoSheet(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
      sheetAnimationStyle: sheetMotion(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Consumer(
        builder: (sheetContext, ref, _) {
          final hasPhoto = ref.watch(profilePhotoProvider) != null;
          Future<void> pick(ImageSource source) async {
            Navigator.pop(sheetContext);
            await _pickPhoto(context, ref, source);
          }

          return SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 19),
                Text(
                  'Profile photo',
                  style: dashboardText(22, weight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kept on this phone only. Never added to consent records.',
                  style: dashboardText(13, color: AppColors.subtle),
                ),
                const SizedBox(height: 10),
                _SheetOption(
                  icon: 'settings/camera',
                  label: 'Take photo',
                  onTap: () => pick(ImageSource.camera),
                ),
                _SheetOption(
                  icon: 'form/image',
                  label: 'Choose from gallery',
                  onTap: () => pick(ImageSource.gallery),
                ),
                if (hasPhoto)
                  _SheetOption(
                    icon: 'settings/trash',
                    label: 'Remove photo',
                    color: AppColors.error,
                    onTap: () {
                      ref.read(profilePhotoProvider.notifier).state = null;
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );

Future<void> _pickPhoto(
  BuildContext context,
  WidgetRef ref,
  ImageSource source,
) async {
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return; // Cancelled.
    final bytes = await file.readAsBytes();
    ref.read(profilePhotoProvider.notifier).state = bytes;
  } on PlatformException catch (error) {
    debugPrint('Profile photo: $error');
    if (!context.mounted) return;
    await showProjectNotice(
      context,
      'Profile photo',
      source == ImageSource.camera
          ? 'The camera couldn\'t be opened. Check that ConsentLink may use '
                'the camera in your phone settings.'
          : 'Your photos couldn\'t be opened. Check that ConsentLink may '
                'use photos in your phone settings.',
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final ink = color ?? AppColors.ink;
    return DashboardAction(
      label: label,
      radius: 16,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            DashboardIcon(
              icon,
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: dashboardText(16, color: ink, weight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Researcher details (Account): the onboarding details plus email, edited
/// in a sheet. Shown to participants so they know who to contact.
Future<void> showResearcherDetailsSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
    sheetAnimationStyle: sheetMotion(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _ResearcherDetailsSheet(),
  );
  if (saved != true || !context.mounted) return;
  showOverlayToast(
    context,
    kind: AppToastKind.success,
    title: 'Details saved',
    subtitle: 'New consent forms will show these details.',
  );
}

class _ResearcherDetailsSheet extends ConsumerStatefulWidget {
  const _ResearcherDetailsSheet();
  @override
  ConsumerState<_ResearcherDetailsSheet> createState() =>
      _ResearcherDetailsSheetState();
}

class _ResearcherDetailsSheetState
    extends ConsumerState<_ResearcherDetailsSheet> {
  // Order on screen; index 1 is the email, the rest map to the draft.
  static const _fields = [
    ('Title & name', 'Enter your title and full name', 'navigation/user', 0),
    ('Email', 'name@institution.na', 'settings/mail', -1),
    (
      'Student / staff number',
      'Enter your student or staff number',
      'researcher/file',
      1,
    ),
    (
      'Faculty / department',
      'Enter your faculty or department',
      'researcher/layers',
      2,
    ),
    (
      'Phone (for participant queries)',
      'For example, +264 81 000 0000',
      'researcher/info',
      3,
    ),
    (
      'Supervisor name & email',
      'Enter your supervisor’s name and email',
      'researcher/users',
      4,
    ),
    (
      'Languages you speak',
      'For example, English, Oshiwambo, Afrikaans',
      'researcher/globe',
      5,
    ),
  ];

  static const _sample = [
    'Ms Ndapewa Shikongo',
    '219034567',
    'Computing & Informatics',
    '+264 81 234 5678',
    'Dr J. Kavari · jkavari@nust.na',
    'English, Oshiwambo',
  ];

  late final List<TextEditingController> _controllers;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    final preview = ref.read(settingsPreviewProvider);
    final draft = ref.read(researcherDraftProvider);
    final email = ref.read(researcherEmailProvider);
    final empty = draft.every((d) => d.trim().isEmpty) && email.isEmpty;
    _controllers = [
      for (final (_, _, _, i) in _fields)
        TextEditingController(
          text: i < 0
              ? (empty && preview ? 'nshikongo@nust.na' : email)
              : (empty && preview ? _sample[i] : draft[i]),
        ),
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final email = _controllers[1].text.trim();
    final valid =
        email.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) {
      setState(() => _emailError = 'Enter an email like name@nust.na');
      return;
    }
    final draft = List<String>.of(ref.read(researcherDraftProvider));
    for (var k = 0; k < _fields.length; k++) {
      final i = _fields[k].$4;
      if (i >= 0) draft[i] = _controllers[k].text.trim();
    }
    ref.read(researcherDraftProvider.notifier).state = draft;
    ref.read(researcherEmailProvider.notifier).state = email;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Outside the scroller, so dragging the handle always moves the
          // sheet.
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: SheetHandle(),
          ),
          Flexible(
            child: _PullDownToClose(
              child: SingleChildScrollView(
                // Clamping, so pulling down at the top reports overscroll.
                primary: false,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 19, 24, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Researcher details',
                      style: dashboardText(22, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shown to participants so they know who to contact.',
                      style: dashboardText(13, color: AppColors.subtle),
                    ),
                    const SizedBox(height: 14),
                    for (var k = 0; k < _fields.length; k++) ...[
                      Text(
                        _fields[k].$1,
                        style: dashboardText(
                          13,
                          color: AppColors.muted,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      VoiceTextField(
                        controller: _controllers[k],
                        hint: _fields[k].$2,
                        icon: _fields[k].$3,
                        fieldLabel: _fields[k].$1,
                        keyboardType: switch (k) {
                          1 => TextInputType.emailAddress,
                          4 => TextInputType.phone,
                          _ => null,
                        },
                        onChanged: k == 1 && _emailError != null
                            ? (_) => setState(() => _emailError = null)
                            : null,
                      ),
                      if (k == 1 && _emailError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _emailError!,
                          style: dashboardText(12, color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: ConsentPillButton(
              label: 'Save details',
              height: 56,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tall sheet's scroller takes the drag from the sheet. Pulling down past
/// the top (about 48 dp) closes the sheet instead, like the export sheet.
class _PullDownToClose extends StatefulWidget {
  const _PullDownToClose({required this.child});
  final Widget child;
  @override
  State<_PullDownToClose> createState() => _PullDownToCloseState();
}

class _PullDownToCloseState extends State<_PullDownToClose> {
  double _pull = 0;
  bool _closing = false;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<OverscrollNotification>(
        onNotification: (n) {
          if (n.dragDetails != null && n.overscroll < 0) {
            _pull -= n.overscroll;
            if (_pull > 48 && !_closing) {
              _closing = true;
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.maybePop(context);
            }
          }
          return false;
        },
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            _pull = 0;
            return false;
          },
          child: widget.child,
        ),
      );
}
