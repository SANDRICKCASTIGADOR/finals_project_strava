import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/activity_model.dart';
import '../utils/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> shareActivity(ActivityModel activity, {String? photoPath}) async {
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const w = 720.0;
    const h = 1280.0;
    final size = Size(w, h);

    await _drawStrava(canvas, size, activity, photoPath);

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    if (bytes != null) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/stepwalking_share_${activity.id}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${activity.name} — ${(activity.distanceMeters / 1000).toStringAsFixed(2)} km with StepWalking',
      );
    }
  } catch (e) {
    await Share.share(
      '🚶 ${activity.name}\n'
          '📍 ${(activity.distanceMeters / 1000).toStringAsFixed(2)} km\n'
          '⏱ ${activity.durationString}\n'
          '⚡ ${activity.paceString} /km\n'
          '👟 ${activity.steps} steps\n\n'
          'Tracked with StepWalking',
    );
  }
}

Future<void> _drawStrava(Canvas canvas, Size size, ActivityModel activity, String? photoPath) async {
  // ── Background ──────────────────────────────────────────────────────────────
  if (photoPath != null) {
    try {
      final file = File(photoPath);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: size.width.toInt(), targetHeight: size.height.toInt());
      final frame = await codec.getNextFrame();
      paintImage(canvas: canvas, rect: Offset.zero & size, image: frame.image, fit: BoxFit.cover);
    } catch (_) {
      _drawGradientBg(canvas, size);
    }
  } else {
    _drawGradientBg(canvas, size);
  }

  // ── Dark overlay on right side for readability ────────────────────────────
  final overlayPaint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
      stops: const [0.2, 1.0],
    ).createShader(Offset.zero & size);
  canvas.drawRect(Offset.zero & size, overlayPaint);

  // ── Bottom gradient ────────────────────────────────────────────────────────
  final bottomGrad = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
      stops: const [0.6, 1.0],
    ).createShader(Offset.zero & size);
  canvas.drawRect(Offset.zero & size, bottomGrad);

  // ── Stats on right side (Strava style) ────────────────────────────────────
  final rightX = size.width * 0.52;
  double y = size.height * 0.35;
  const double lineGap = 110.0;

  _drawStat(canvas, 'Distance', '${(activity.distanceMeters / 1000).toStringAsFixed(2)} km', rightX, y);
  y += lineGap;
  _drawStat(canvas, 'Pace', '${activity.paceString} /km', rightX, y);
  y += lineGap;
  _drawStat(canvas, 'Time', activity.durationString, rightX, y);
  y += lineGap;
  _drawStat(canvas, 'Steps', '${activity.steps}', rightX, y);

  // ── StepWalking branding bottom right ────────────────────────────────────
  _drawBranding(canvas, size);
}

void _drawGradientBg(Canvas canvas, Size size) {
  final bg = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFF0A0A0A), const Color(0xFF1A1A1A), const Color(0xFF0F0F0F)],
    ).createShader(Offset.zero & size);
  canvas.drawRect(Offset.zero & size, bg);

  // Subtle orange glow
  final glow = Paint()
    ..color = AppTheme.orange.withOpacity(0.08)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
  canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.3), 300, glow);
}

void _drawStat(Canvas canvas, String label, String value, double x, double y) {
  // Label
  final labelPainter = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        fontSize: 22,
        color: Colors.white70,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  labelPainter.paint(canvas, Offset(x, y));

  // Value
  final valuePainter = TextPainter(
    text: TextSpan(
      text: value,
      style: const TextStyle(
        fontSize: 52,
        color: Colors.white,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  valuePainter.paint(canvas, Offset(x, y + 28));
}

void _drawBranding(Canvas canvas, Size size) {
  // Orange circle background
  final circlePaint = Paint()..color = AppTheme.orange;
  canvas.drawCircle(Offset(size.width - 80, size.height - 140), 40, circlePaint);

  // Walking icon (simple representation)
  final iconPaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 4
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final cx = size.width - 80;
  final cy = size.height - 140;
  // Head
  canvas.drawCircle(Offset(cx + 5, cy - 20), 7, Paint()..color = Colors.white);
  // Body line
  canvas.drawLine(Offset(cx + 5, cy - 13), Offset(cx + 5, cy + 5), iconPaint);
  // Arms
  canvas.drawLine(Offset(cx - 8, cy - 5), Offset(cx + 18, cy - 5), iconPaint);
  // Legs
  canvas.drawLine(Offset(cx + 5, cy + 5), Offset(cx - 8, cy + 22), iconPaint);
  canvas.drawLine(Offset(cx + 5, cy + 5), Offset(cx + 18, cy + 22), iconPaint);

  // App name
  final namePainter = TextPainter(
    text: const TextSpan(
      text: 'StepWalking',
      style: TextStyle(
        fontSize: 26,
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  namePainter.paint(canvas, Offset(size.width - namePainter.width - 24, size.height - 72));
}