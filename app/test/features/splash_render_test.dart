import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  testWidgets('splash has visible artwork before the final frame', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final composition = await LottieComposition.fromBytes(
        await File('assets/animations/consentlink-splash.json').readAsBytes(),
      );
      final background = await LottieComposition.fromBytes(
        await File(
          'assets/animations/consentlink-splash-background.json',
        ).readAsBytes(),
      );
      for (final entry in {
        'Inter': [
          'Inter-Regular.ttf',
          'Inter-Medium.ttf',
          'Inter-SemiBold.ttf',
        ],
        'Mulish': ['Mulish-Variable.ttf'],
      }.entries) {
        final loader = FontLoader(entry.key);
        for (final font in entry.value) {
          loader.addFont(
            File(
              'assets/fonts/$font',
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        }
        await loader.load();
      }
      for (final progress in [0.15, 0.4, 0.7, 0.95]) {
        final drawable = LottieDrawable(composition)..setProgress(progress);
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        (LottieDrawable(background)..setProgress(progress)).draw(
          canvas,
          const ui.Rect.fromLTWH(0, 0, 390, 844),
        );
        drawable.draw(canvas, const ui.Rect.fromLTWH(0, 0, 390, 844));
        final picture = recorder.endRecording();
        final image = await picture.toImage(390, 844);
        final pixels = (await image.toByteData())!;
        for (final point in [const Offset(0, 0), const Offset(389, 843)]) {
          final offset = (point.dy.toInt() * 390 + point.dx.toInt()) * 4;
          expect(
            pixels.getUint8(offset + 3),
            255,
            reason: 'No transparent rounded screen corners',
          );
        }
        var brightPixels = 0;
        for (var offset = 0; offset < pixels.lengthInBytes; offset += 4) {
          if (pixels.getUint8(offset) > 200 &&
              pixels.getUint8(offset + 1) > 200 &&
              pixels.getUint8(offset + 2) > 200 &&
              pixels.getUint8(offset + 3) > 200) {
            brightPixels++;
          }
        }
        if (Platform.environment['SPLASH_CAPTURE'] == '1') {
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          await File(
            '${Directory.systemTemp.path}/consentlink-fixed-$progress.png',
          ).writeAsBytes(png.buffer.asUint8List());
        }
        image.dispose();
        picture.dispose();
        expect(brightPixels, greaterThan(20), reason: 'Artwork at $progress');
      }
      final json =
          jsonDecode(
                await File(
                  'assets/animations/consentlink-splash.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final fonts = {
        for (final font in json['fonts']['list'])
          font['fName']: font['fFamily'],
      };
      for (final layer in json['layers']) {
        if (layer['ty'] != 5) continue;
        final text = layer['t']['d']['k'][0]['s'];
        final width = (text['sz'][0] as num).toDouble();
        if (width == 0) continue;
        final size = (text['s'] as num).toDouble();
        var measured = 0.0;
        for (final character in (text['t'] as String).characters) {
          final painter = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
              text: character,
              style: TextStyle(
                fontFamily: fonts[text['f']],
                fontSize: size,
                fontWeight: (text['f'] as String).contains('Semi')
                    ? FontWeight.w600
                    : (text['f'] as String).contains('Medium')
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
          )..layout();
          final glyph = (json['chars'] as List).firstWhere(
            (glyph) =>
                glyph['ch'] == character &&
                glyph['fFamily'] == fonts[text['f']] &&
                glyph['style'] ==
                    (json['fonts']['list'] as List).firstWhere(
                      (font) => font['fName'] == text['f'],
                    )['fStyle'],
          );
          measured +=
              (glyph['w'] as num) * size / 100 + (text['tr'] as num) / 10;
          painter.dispose();
        }
        expect(
          measured,
          lessThan(width),
          reason: '${text['t']} must stay on one line',
        );
      }
    });
  });
}
