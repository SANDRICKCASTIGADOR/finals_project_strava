import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/activity_model.dart';
import '../utils/app_theme.dart';

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
        text:
        '${activity.name} — ${(activity.distanceMeters / 1000).toStringAsFixed(2)} km with StepWalking 🚶',
      );
    }
  } catch (_) {

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

Future<void> _drawShareCard(
    Canvas canvas, Size size, ActivityModel activity, String? photoPath) async {

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
      _drawPlainBg(canvas, size);
    }
  } else {
    _drawPlainBg(canvas, size);
  }

  final vignettePaint = Paint()
    ..shader = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        Colors.transparent,
        Colors.black.withOpacity(0.30),
      ],
    ).createShader(Offset.zero & size);
  canvas.drawRect(Offset.zero & size, vignettePaint);

  final cx = size.width / 2;
  double y = size.height * 0.20;
  const gap = 132.0;

  _drawStatCentered(
    canvas,
    'Distance',
    '${(activity.distanceMeters / 1000).toStringAsFixed(2)} km',
    cx, y, size,
  );
  y += gap;

  _drawStatCentered(canvas, 'Pace', '${activity.paceString} /km', cx, y, size);
  y += gap;

  _drawStatCentered(canvas, 'Time', activity.durationString, cx, y, size);

  if (activity.route.length > 1) {
    _drawRouteMap(canvas, activity, size);
  }

  _drawBranding(canvas, size);
}

void _drawPlainBg(Canvas canvas, Size size) {
  final paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1C1C1C), Color(0xFF111111)],
    ).createShader(Offset.zero & size);
  canvas.drawRect(Offset.zero & size, paint);

  canvas.drawCircle(
    Offset(size.width * 0.5, size.height * 0.38),
    200,
    Paint()
      ..color = AppTheme.orange.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
  );
}

void _drawStatCentered(
    Canvas canvas, String label, String value, double cx, double y, Size size) {

  final labelPainter = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        fontSize: 26,
        color: Colors.white70,
        fontWeight: FontWeight.w400,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  labelPainter.paint(canvas, Offset(cx - labelPainter.width / 2, y));

  // Value (e.g. "6.02 km") — large, bold, pure white
  final valuePainter = TextPainter(
    text: TextSpan(
      text: value,
      style: const TextStyle(
        fontSize: 82,
        color: Colors.white,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -1.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size.width - 48);
  valuePainter.paint(canvas, Offset(cx - valuePainter.width / 2, y + 32));
}

void _drawRouteMap(Canvas canvas, ActivityModel activity, Size size) {
  const mapW = 220.0;
  const mapH = 170.0;
  const mapX = 28.0;
  final mapY = size.height - mapH - 90;
  final mapRect = Rect.fromLTWH(mapX, mapY, mapW, mapH);

  canvas.drawRRect(
    RRect.fromRectAndRadius(mapRect, const Radius.circular(14)),
    Paint()..color = Colors.black.withOpacity(0.42),
  );


  canvas.drawRRect(
    RRect.fromRectAndRadius(mapRect, const Radius.circular(14)),
    Paint()
      ..color = AppTheme.orange.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );

  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(mapRect, const Radius.circular(14)));

  final route = activity.route;
  double minLat = route.first.latitude, maxLat = route.first.latitude;
  double minLng = route.first.longitude, maxLng = route.first.longitude;
  for (final p in route) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }

  final latRange = (maxLat - minLat).abs();
  final lngRange = (maxLng - minLng).abs();
  const pad = 16.0;

  Offset toCanvas(double lat, double lng) {
    final nx = lngRange == 0 ? 0.5 : (lng - minLng) / lngRange;
    final ny = latRange == 0 ? 0.5 : 1.0 - (lat - minLat) / latRange;
    return Offset(
      mapX + pad + nx * (mapW - pad * 2),
      mapY + pad + ny * (mapH - pad * 2),
    );
  }

  final path = Path();
  final first = toCanvas(route.first.latitude, route.first.longitude);
  path.moveTo(first.dx, first.dy);
  for (int i = 1; i < route.length; i++) {
    final pt = toCanvas(route[i].latitude, route[i].longitude);
    path.lineTo(pt.dx, pt.dy);
  }
  canvas.drawPath(
    path,
    Paint()
      ..color = AppTheme.orange
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );

  final startPt = toCanvas(route.first.latitude, route.first.longitude);
  canvas.drawCircle(startPt, 5.5, Paint()..color = AppTheme.green);
  canvas.drawCircle(startPt, 5.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

  final endPt = toCanvas(route.last.latitude, route.last.longitude);
  canvas.drawCircle(endPt, 5.5, Paint()..color = Colors.red);
  canvas.drawCircle(endPt, 5.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

  canvas.restore();
}

void _drawBranding(Canvas canvas, Size size) {
  const pillW = 210.0;
  const pillH = 44.0;
  final pillX = size.width - pillW - 28;
  final pillY = size.height - pillH - 84;

  final pillRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(pillX, pillY, pillW, pillH),
    const Radius.circular(22),
  );

  canvas.drawRRect(pillRect, Paint()..color = Colors.white.withOpacity(0.18));
  canvas.drawRRect(
    pillRect,
    Paint()
      ..color = Colors.white.withOpacity(0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );

  final tp = TextPainter(
    text: const TextSpan(
      text: 'StepWalking',
      style: TextStyle(
        fontSize: 22,
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  tp.paint(
    canvas,
    Offset(
      pillX + (pillW - tp.width) / 2,
      pillY + (pillH - tp.height) / 2,
    ),
  );
}