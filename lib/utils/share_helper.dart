import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/activity_model.dart';
import '../utils/app_theme.dart';

// ── Main share function ───────────────────────────────────────────────────────
Future<void> shareActivity(ActivityModel activity, {String? photoPath}) async {
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double w = 720;
    const double h = 1280;
    final size = Size(w, h);

    await _drawShareCard(canvas, size, activity, photoPath);

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    if (bytes != null) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/stepwalking_share_${activity.id}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${activity.name} — ${(activity.distanceMeters / 1000).toStringAsFixed(2)} km with StepWalking 🚶',
      );
    }
  } catch (_) {
    // Fallback to text share
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

// ── Draw full share card ──────────────────────────────────────────────────────
Future<void> _drawShareCard(
    Canvas canvas, Size size, ActivityModel activity, String? photoPath) async {

  // ── Background ───────────────────────────────────────────────────────────
  if (photoPath != null) {
    try {
      final bytes = await File(photoPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: size.width.toInt(),
        targetHeight: size.height.toInt(),
      );
      final frame = await codec.getNextFrame();
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: frame.image,
        fit: BoxFit.cover,
      );
    } catch (_) {
      _drawDarkBg(canvas, size);
    }
  } else {
    _drawDarkBg(canvas, size);
  }

  // ── Right side dark overlay for text readability ──────────────────────
  final overlayPaint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
      stops: const [0.25, 1.0],
    ).createShader(Offset.zero & size);
  canvas.drawRect(Offset.zero & size, overlayPaint);

  // ── Bottom gradient ───────────────────────────────────────────────────
  final bottomPaint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
      stops: const [0.55, 1.0],
    ).createShader(Offset.zero & size);
  canvas.drawRect(Offset.zero & size, bottomPaint);

  // ── Mini route map (bottom left) ──────────────────────────────────────
  if (activity.route.length > 1) {
    _drawRouteMap(canvas, activity, size);
  }

  // ── Stats (right side, Strava style) ─────────────────────────────────
  final rightX = size.width * 0.50;
  double y = size.height * 0.28;
  const gap = 115.0;

  _drawStat(canvas, 'Distance', '${(activity.distanceMeters / 1000).toStringAsFixed(2)} km', rightX, y);
  y += gap;
  _drawStat(canvas, 'Pace', '${activity.paceString} /km', rightX, y);
  y += gap;
  _drawStat(canvas, 'Time', activity.durationString, rightX, y);
  y += gap;
  _drawStat(canvas, 'Steps', '${activity.steps}', rightX, y);

  // ── Branding bottom right ─────────────────────────────────────────────
  _drawBranding(canvas, size);
}

// ── Draw route map ────────────────────────────────────────────────────────────
void _drawRouteMap(Canvas canvas, ActivityModel activity, Size size) {
  const mapW = 260.0;
  const mapH = 200.0;
  const mapX = 24.0;
  final mapY = size.height - mapH - 90;
  final mapRect = Rect.fromLTWH(mapX, mapY, mapW, mapH);

  // Map background
  final bgPaint = Paint()..color = const Color(0xFF1A1A1A);
  canvas.drawRRect(RRect.fromRectAndRadius(mapRect, const Radius.circular(16)), bgPaint);

  // Map border
  final borderPaint = Paint()
    ..color = AppTheme.orange.withOpacity(0.4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  canvas.drawRRect(RRect.fromRectAndRadius(mapRect, const Radius.circular(16)), borderPaint);

  // Clip to map bounds
  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(mapRect, const Radius.circular(16)));

  // Draw subtle grid
  final gridPaint = Paint()
    ..color = Colors.white.withOpacity(0.04)
    ..strokeWidth = 1;
  for (double gx = mapX; gx < mapX + mapW; gx += 30) {
    canvas.drawLine(Offset(gx, mapY), Offset(gx, mapY + mapH), gridPaint);
  }
  for (double gy = mapY; gy < mapY + mapH; gy += 30) {
    canvas.drawLine(Offset(mapX, gy), Offset(mapX + mapW, gy), gridPaint);
  }

  // Normalize route points to map bounds
  final route = activity.route;
  double minLat = route.first.latitude,  maxLat = route.first.latitude;
  double minLng = route.first.longitude, maxLng = route.first.longitude;

  for (final p in route) {
    if (p.latitude < minLat)  minLat = p.latitude;
    if (p.latitude > maxLat)  maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }

  final latRange = (maxLat - minLat).abs();
  final lngRange = (maxLng - minLng).abs();
  const pad = 20.0;

  Offset toCanvas(double lat, double lng) {
    final nx = lngRange == 0 ? 0.5 : (lng - minLng) / lngRange;
    final ny = latRange == 0 ? 0.5 : 1.0 - (lat - minLat) / latRange;
    return Offset(
      mapX + pad + nx * (mapW - pad * 2),
      mapY + pad + ny * (mapH - pad * 2),
    );
  }

  // Draw route line
  final routePaint = Paint()
    ..color = AppTheme.orange
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final path = Path();
  final first = toCanvas(route.first.latitude, route.first.longitude);
  path.moveTo(first.dx, first.dy);
  for (int i = 1; i < route.length; i++) {
    final pt = toCanvas(route[i].latitude, route[i].longitude);
    path.lineTo(pt.dx, pt.dy);
  }
  canvas.drawPath(path, routePaint);

  // Start dot (green)
  final startPt = toCanvas(route.first.latitude, route.first.longitude);
  canvas.drawCircle(startPt, 6, Paint()..color = AppTheme.green);
  canvas.drawCircle(startPt, 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);

  // End dot (red)
  final endPt = toCanvas(route.last.latitude, route.last.longitude);
  canvas.drawCircle(endPt, 6, Paint()..color = Colors.red);
  canvas.drawCircle(endPt, 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);

  canvas.restore();

  // Map label
  _drawText(canvas, 'Route', Offset(mapX + 10, mapY + mapH + 8), 18, Colors.white60, FontWeight.w500);
}

// ── Dark gradient background ──────────────────────────────────────────────────
void _drawDarkBg(Canvas canvas, Size size) {
  final paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0A0A0A), Color(0xFF141414), Color(0xFF0F0F0F)],
    ).createShader(Offset.zero & size);
  canvas.drawRect(Offset.zero & size, paint);

  // Subtle glow
  canvas.drawCircle(
    Offset(size.width * 0.75, size.height * 0.25),
    280,
    Paint()
      ..color = AppTheme.orange.withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100),
  );
}

// ── Draw a stat block ─────────────────────────────────────────────────────────
void _drawStat(Canvas canvas, String label, String value, double x, double y) {
  _drawText(canvas, label, Offset(x, y), 22, Colors.white60, FontWeight.w400);
  _drawText(canvas, value, Offset(x, y + 30), 52, Colors.white, FontWeight.w800);
}

// ── Draw branding ─────────────────────────────────────────────────────────────
void _drawBranding(Canvas canvas, Size size) {
  // Orange pill background
  final pillRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(size.width - 220, size.height - 72, 196, 48),
    const Radius.circular(24),
  );
  canvas.drawRRect(pillRect, Paint()..color = AppTheme.orange);

  // Walking icon
  final iconPaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final cx = size.width - 196.0;
  final cy = size.height - 48.0;
  canvas.drawCircle(Offset(cx, cy - 10), 5, Paint()..color = Colors.white);
  canvas.drawLine(Offset(cx, cy - 5), Offset(cx, cy + 6), iconPaint);
  canvas.drawLine(Offset(cx - 7, cy - 1), Offset(cx + 7, cy - 1), iconPaint);
  canvas.drawLine(Offset(cx, cy + 6), Offset(cx - 6, cy + 16), iconPaint);
  canvas.drawLine(Offset(cx, cy + 6), Offset(cx + 6, cy + 16), iconPaint);

  // App name
  _drawText(canvas, 'StepWalking', Offset(size.width - 178, size.height - 57), 24, Colors.white, FontWeight.w800);
}

// ── Text painter helper ───────────────────────────────────────────────────────
void _drawText(Canvas canvas, String text, Offset offset, double size, Color color, FontWeight weight) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, fontWeight: weight, height: 1.1)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, offset);
}