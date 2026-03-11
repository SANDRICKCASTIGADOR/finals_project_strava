import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/activity_model.dart';
import '../utils/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> shareActivity(ActivityModel activity) async {
  final boundary = GlobalKey();
  final widget = _ShareCard(activity: activity, repaintKey: boundary);

  final overlay = OverlayEntry(builder: (_) => Positioned(
    left: -10000, top: -10000,
    child: Material(color: Colors.transparent, child: widget),
  ));

  // Use a simpler approach - just share text if capture fails
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/share_${activity.id}.png');

    // Build widget offscreen and capture
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(400, 260);

    _drawShareCard(canvas, size, activity);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    if (bytes != null) {
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: '${activity.name} — ${(activity.distanceMeters/1000).toStringAsFixed(2)} km');
    }
  } catch (_) {
    await Share.share(
      '🏃 ${activity.name}\n'
          '📍 ${(activity.distanceMeters/1000).toStringAsFixed(2)} km\n'
          '⏱ ${activity.durationString}\n'
          '👟 ${activity.steps} steps\n'
          '⚡ ${activity.paceString} /km\n\n'
          'Tracked with StepWalking',
    );
  }
}

void _drawShareCard(Canvas canvas, Size size, ActivityModel activity) {
  final paint = Paint()..color = const Color(0xFF0F0F0F);
  final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24));
  canvas.drawRRect(rrect, paint);

  final borderPaint = Paint()..color = AppTheme.orange.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5;
  canvas.drawRRect(rrect, borderPaint);

  final orangePaint = Paint()..color = AppTheme.orange;
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(24, 24, 36, 36), const Radius.circular(10)), orangePaint);

  _drawText(canvas, 'StepWalking', const Offset(72, 26), 13, AppTheme.orange, FontWeight.w700);
  _drawText(canvas, activity.name, const Offset(72, 44), 16, Colors.white, FontWeight.w800);

  _drawStatBox(canvas, const Offset(24, 84), 176, '${(activity.distanceMeters/1000).toStringAsFixed(2)} km', 'DISTANCE', activity);
  _drawStatBox(canvas, const Offset(212, 84), 176, activity.durationString, 'DURATION', activity);
  _drawStatBox(canvas, const Offset(24, 156), 176, '${activity.paceString} /km', 'PACE', activity);
  _drawStatBox(canvas, const Offset(212, 156), 176, '${activity.steps} steps', 'STEPS', activity);

  final gradientPaint = Paint()..shader = LinearGradient(
    colors: [AppTheme.orange, AppTheme.orange.withOpacity(0.3)],
  ).createShader(Rect.fromLTWH(24, size.height - 20, size.width - 48, 4));
  canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(24, size.height - 20, size.width - 48, 4), const Radius.circular(2)), gradientPaint);
}

void _drawStatBox(Canvas canvas, Offset offset, double width, String value, String label, ActivityModel activity) {
  final bg = Paint()..color = const Color(0xFF1A1A1A);
  canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(offset.dx, offset.dy, width, 60), const Radius.circular(12)), bg);
  _drawText(canvas, label, Offset(offset.dx + 14, offset.dy + 12), 10, Colors.white38, FontWeight.w600);
  _drawText(canvas, value, Offset(offset.dx + 14, offset.dy + 30), 18, Colors.white, FontWeight.w800);
}

void _drawText(Canvas canvas, String text, Offset offset, double fontSize, Color color, FontWeight weight) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color, fontWeight: weight)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, offset);
}

class _ShareCard extends StatelessWidget {
  final ActivityModel activity;
  final GlobalKey repaintKey;
  const _ShareCard({required this.activity, required this.repaintKey});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: 400, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.orange.withOpacity(0.3), width: 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.orange, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.directions_walk_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('StepWalking', style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.orange)),
              Text(activity.name, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            _statBox('${(activity.distanceMeters/1000).toStringAsFixed(2)}', 'km', 'Distance'),
            const SizedBox(width: 12),
            _statBox(activity.durationString, '', 'Duration'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _statBox(activity.paceString, '/km', 'Pace'),
            const SizedBox(width: 12),
            _statBox('${activity.steps}', 'steps', 'Steps'),
          ]),
          const SizedBox(height: 20),
          Container(height: 4, decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(colors: [AppTheme.orange, AppTheme.orange.withOpacity(0.3)]),
          )),
        ]),
      ),
    );
  }

  Widget _statBox(String value, String unit, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 10, color: Colors.white38, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        RichText(text: TextSpan(children: [
          TextSpan(text: value, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
          if (unit.isNotEmpty) TextSpan(text: ' $unit', style: GoogleFonts.spaceGrotesk(fontSize: 12, color: Colors.white38)),
        ])),
      ]),
    ),
  );
}