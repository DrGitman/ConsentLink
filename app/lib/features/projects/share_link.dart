import 'dart:io';

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase/supabase.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/auth/auth_providers.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../responses/export_files.dart' show exportFolder;
import '../responses/responses_widgets.dart' show showOverlayToast;
import '../templates/template_widgets.dart' show SheetHandle;
import 'project_data.dart';
import 'project_widgets.dart';

/// Where participant_web/ is hosted (see its README).
const consentLinkBaseUrl = String.fromEnvironment(
  'CONSENT_LINK_BASE_URL',
  defaultValue: 'https://drgitman.github.io/ConsentLink/participant_web/',
);

class ConsentLink {
  const ConsentLink({
    required this.id,
    required this.token,
    required this.expiresAt,
  });
  final String id;
  final String token;
  final DateTime expiresAt;
  String get url => '$consentLinkBaseUrl?t=$token';
}

/// Creates a link on the server (checked there: published, open, no
/// minors, your institution). Needs the internet and a signed in researcher.
Future<ConsentLink> createConsentLink(
  SupabaseClient client,
  String studyId,
) async {
  final row = await client
      .from('consent_links')
      .insert({'study_id': studyId})
      .select('id, token, expires_at')
      .single();
  return ConsentLink(
    id: row['id'] as String,
    token: row['token'] as String,
    expiresAt: DateTime.parse(row['expires_at'] as String).toLocal(),
  );
}

Future<void> revokeConsentLink(SupabaseClient client, String id) => client
    .from('consent_links')
    .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
    .eq('id', id);

String _problem(Object e) {
  if (e is PostgrestException) {
    final m = e.message;
    if (m.contains('publish the consent form')) {
      return 'Publish the consent form first, then share a link.';
    }
    if (m.contains('without minors')) {
      return 'Links are only for open projects without participants under 18. '
          'Minors give consent in person with their guardian.';
    }
    if (m.contains('relation') && m.contains('consent_links')) {
      return 'Share links are not set up on the server yet '
          '(migration 20261102000001_consent_links.sql).';
    }
    return m;
  }
  if (e is SocketException || e is AuthException) {
    return 'Creating a link needs the internet and a signed in account.';
  }
  return 'The link could not be created. Try again.';
}

String _date(DateTime d) =>
    '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';

/// 03.4 "Share link / QR code": the participant fills the form on their own
/// phone. Shows the QR code and the link, with copy, poster and turn off.
Future<void> showShareLinkSheet(
  BuildContext context,
  WidgetRef ref,
  Project project,
) async {
  final preview = ref.read(projectsPreviewProvider);
  ConsentLink link;
  final client = ref.read(supabaseClientProvider);
  if (preview) {
    link = ConsentLink(
      id: 'preview',
      token: 'preview',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
  } else {
    if (client == null || client.auth.currentSession == null) {
      await showProjectNotice(
        context,
        'Share link / QR code',
        'Sign in with your institution account and connect to the internet to '
            'create a link.',
      );
      return;
    }
    if (!project.canCollect) {
      await showProjectNotice(
        context,
        'Share link / QR code',
        project.status == ProjectStatus.closed
            ? 'This project is closed. Reopen it to share a link.'
            : 'Publish the consent form first, then share a link.',
      );
      return;
    }
    try {
      link = await createConsentLink(client, project.id);
    } catch (e) {
      if (context.mounted) {
        await showProjectNotice(context, 'Share link / QR code', _problem(e));
      }
      return;
    }
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
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
    builder: (sheet) => _ShareSheet(
      project: project,
      link: link,
      preview: preview,
      onRevoke: preview || client == null
          ? null
          : () async {
              await revokeConsentLink(client, link.id);
              if (sheet.mounted) Navigator.pop(sheet);
              if (context.mounted) {
                showOverlayToast(
                  context,
                  kind: AppToastKind.info,
                  title: 'Link turned off',
                  subtitle: 'Anyone opening it now sees that it has expired.',
                );
              }
            },
    ),
  );
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({
    required this.project,
    required this.link,
    required this.preview,
    required this.onRevoke,
  });
  final Project project;
  final ConsentLink link;
  final bool preview;
  final Future<void> Function()? onRevoke;

  @override
  Widget build(BuildContext context) {
    final svg = Barcode.qrCode().toSvg(link.url, width: 240, height: 240);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 19),
          Text(
            'Share link / QR code',
            style: dashboardText(22, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            preview
                ? 'Preview only: this sample link does not open a real form.'
                : '${project.title} · works until ${_date(link.expiresAt)}',
            style: dashboardText(14, color: AppColors.subtle),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.line),
              ),
              child: Semantics(
                label: 'QR code for the consent form link',
                image: true,
                child: SvgPicture.string(svg, width: 220, height: 220),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SelectableText(
            link.url,
            style: dashboardText(13, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Text(
            'The participant scans the code or opens the link on their own phone, '
            'reads the form in their language, chooses, and signs with a finger. '
            'Their record appears in Responses after the next sync.',
            style: dashboardText(13, color: AppColors.subtle),
          ),
          const SizedBox(height: 16),
          ConsentPillButton(
            icon: 'projects/link',
            label: 'Copy link',
            height: 52,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link.url));
              if (context.mounted) {
                showOverlayToast(
                  context,
                  kind: AppToastKind.success,
                  title: 'Link copied',
                );
              }
            },
          ),
          const SizedBox(height: 10),
          ConsentPillButton(
            icon: 'projects/download',
            label: 'Save QR poster (PDF)',
            filled: false,
            height: 52,
            onPressed: () => _poster(context),
          ),
          if (onRevoke != null)
            Center(
              child: TextButton(
                onPressed: onRevoke,
                child: Text(
                  'Turn off this link',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _poster(BuildContext context) async {
    try {
      final regular = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/Inter-SemiBold.ttf');
      final doc = pw.Document(
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(regular),
          bold: pw.Font.ttf(bold),
        ),
      );
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(48),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                project.title,
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Scan to read the consent form and choose',
                style: const pw.TextStyle(fontSize: 16),
              ),
              pw.SizedBox(height: 28),
              pw.BarcodeWidget(
                barcode: Barcode.qrCode(),
                data: link.url,
                width: 300,
                height: 300,
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                link.url,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Works until ${_date(link.expiresAt)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Spacer(),
              pw.Text(
                'Taking part is your choice. You can say no or stop at any time.',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ),
        ),
      );
      final (dir, place) = await exportFolder();
      final safe = project.title
          .replaceAll(RegExp(r'[^A-Za-z0-9 _]'), '')
          .trim();
      final file = File(
        '${dir.path}/${safe.isEmpty ? 'Consent link' : safe} QR.pdf',
      );
      await file.writeAsBytes(await doc.save(), flush: true);
      if (context.mounted) {
        showOverlayToast(
          context,
          kind: AppToastKind.success,
          title: 'QR poster saved',
          subtitle: 'Saved to $place/${file.uri.pathSegments.last}.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        showOverlayToast(
          context,
          kind: AppToastKind.error,
          title: 'The poster could not be saved',
        );
      }
    }
  }
}
