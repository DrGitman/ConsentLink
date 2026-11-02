import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_providers.dart';
import '../../ai/tts/audio_source.dart';
import '../../contracts/models.dart' as m;
import '../../core/data/data_revision.dart';
import '../../data/repositories/repository_providers.dart';
import 'field_capture_data.dart';

/// The app language code for a field capture language chip.
String captureLanguageCode(String displayName) =>
    languageCodeForName(displayName);

/// The id of the consent saved last on this phone (for the done screen).
final lastConsentIdProvider = StateProvider<String?>((ref) => null);

/// Saves the finished capture: a participant, their consent against the
/// published form version, and the signature image when there is one.
/// Does nothing in preview builds. Returns the consent id.
Future<String?> saveCapturedConsent(
  WidgetRef ref, {
  Uint8List? signature,
  Future<Uint8List?>? signatureLater,
  bool isMinor = false,
  bool? guardianConsent,
  bool? childAssent,
}) async {
  // Everything from ref is read now, before any await: the screen may
  // already have moved on (and been disposed) when the save finishes.
  if (ref.read(fieldCapturePreviewProvider)) return null;
  final session = ref.read(captureSessionProvider);
  final studyId = session.projectId;
  if (studyId == null) return null;
  // The language the participant actually read (the form may not have the
  // chip they picked; then they read English).
  final language = ref.read(readLanguageCodeProvider);
  final studiesFuture = ref.read(studyRepositoryProvider.future);
  final participantsFuture = ref.read(participantRepositoryProvider.future);
  final consentsFuture = ref.read(consentRepositoryProvider.future);
  final lastConsent = ref.read(lastConsentIdProvider.notifier);
  final revision = ref.read(dataRevisionProvider.notifier);

  final studies = await studiesFuture;
  final study = (await studies.listStudies())
      .where((s) => s.id == studyId)
      .firstOrNull;
  if (study == null || study.formVersion == 0 || study.formHash == null) {
    throw StateError('This project has no published consent form yet.');
  }
  final participants = await participantsFuture;
  final participant = await participants.create(
    m.ParticipantDraft(studyId: studyId, language: language, isMinor: isMinor),
  );
  final agreed =
      !session.declined && guardianConsent != false && childAssent != false;
  final consents = await consentsFuture;
  final consent = await consents.saveConsent(
    m.ConsentDraft(
      studyId: studyId,
      participantId: participant.id,
      language: language,
      decision: agreed ? m.ConsentDecision.yes : m.ConsentDecision.no,
      method: switch (session.method) {
        ConsentMethod.sign => m.ConsentMethod.signature,
        ConsentMethod.thumbprint => m.ConsentMethod.thumbprint,
        ConsentMethod.verbal => m.ConsentMethod.verbal,
      },
      witnessName: session.witness,
      interpreterName: session.interpreter ? 'Interpreter present' : null,
      guardianConsent: isMinor ? guardianConsent : null,
      childAssent: isMinor ? childAssent : null,
      formVersion: study.formVersion,
      formHash: study.formHash!,
    ),
  );
  final png = signature ?? await signatureLater;
  if (png != null && png.isNotEmpty) {
    await participants.storeSignature(
      consent.id,
      m.SignatureKind.signature,
      png,
    );
  }
  lastConsent.state = consent.id;
  revision.state++;
  return consent.id;
}

/// Draws signature strokes onto a white PNG, cropped to the ink.
Future<Uint8List?> strokesToPng(List<List<Offset>> strokes) async {
  final points = strokes.expand((s) => s).toList();
  if (points.length < 2) return null;
  var left = points.first.dx, top = points.first.dy;
  var right = left, bottom = top;
  for (final p in points) {
    if (p.dx < left) left = p.dx;
    if (p.dx > right) right = p.dx;
    if (p.dy < top) top = p.dy;
    if (p.dy > bottom) bottom = p.dy;
  }
  const pad = 16.0;
  final width = (right - left + pad * 2).ceil();
  final height = (bottom - top + pad * 2).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.white,
  );
  final ink = Paint()
    ..color = const Color(0xFF111614)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  for (final s in strokes) {
    if (s.isEmpty) continue;
    final path = Path()
      ..moveTo(s.first.dx - left + pad, s.first.dy - top + pad);
    for (final p in s.skip(1)) {
      path.lineTo(p.dx - left + pad, p.dy - top + pad);
    }
    canvas.drawPath(path, ink);
  }
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

/// Reads [text] aloud with this phone's voice for the participant's text
/// language. Silent when the phone has no voice for it; never throws.
Future<void> speakAloud(WidgetRef ref, String text) async {
  try {
    final service = ref.read(readAloudServiceProvider);
    final source = await service.resolve(ref.read(readLanguageCodeProvider));
    if (source is DeviceTts) await service.speak(source, text);
  } catch (_) {
    // No voice or the engine failed: the screen still shows the words.
  }
}
