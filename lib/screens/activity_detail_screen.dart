import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/activity_model.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../widgets/stat_card.dart';
class ActivityDetailScreen extends StatefulWidget {
  final ActivityModel activity;
  final StorageService storageService;
  const ActivityDetailScreen({super.key, required this.activity, required this.storageService});
  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}
class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  late ActivityModel _activity;
  final _picker = ImagePicker();
  bool _savingPhoto = false;
  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
  }
  LatLng get _center {
    if (_activity.route.isEmpty) return const LatLng(14.5995, 120.9842);
    double lat = 0, lng = 0;
    for (final p in _activity.route) { lat += p.latitude; lng += p.longitude; }
    return LatLng(lat / _activity.route.length, lng / _activity.route.length);
  }
  double _calcZoom() {
    if (_activity.route.length < 2) return 15;
    double minLat=90, maxLat=-90, minLng=180, maxLng=-180;
    for (final p in _activity.route) {
      if (p.latitude < minLat)  minLat = p.latitude;
      if (p.latitude > maxLat)  maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final diff = [maxLat-minLat, maxLng-minLng].reduce((a,b) => a > b ? a : b);
    if (diff < 0.002) return 16; if (diff < 0.01) return 15;
    if (diff < 0.05)  return 13; if (diff < 0.1)  return 12;
    return 11;
  }
  Future<void> _addPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200);
      if (picked == null) return;
      setState(() => _savingPhoto = true);
      final dir  = await getApplicationDocumentsDirectory();
      final dest = p.join(dir.path, 'activity_photos', '${_activity.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await Directory(p.dirname(dest)).create(recursive: true);
      await File(picked.path).copy(dest);
      final updated = _activity.copyWith(photoPaths: [..._activity.photoPaths, dest]);
      await widget.storageService.updateActivity(updated);
      setState(() { _activity = updated; _savingPhoto = false; });
    } catch (e) {
      setState(() => _savingPhoto = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add photo: $e'), backgroundColor: AppTheme.red),
      );
    }
  }
  Future<void> _deletePhoto(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Photo', style: GoogleFonts.dmSans(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Remove this photo from the activity?', style: GoogleFonts.dmSans(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.dmSans(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try { await File(path).delete(); } catch (_) {}
    final updated = _activity.copyWith(photoPaths: _activity.photoPaths.where((e) => e != path).toList());
    await widget.storageService.updateActivity(updated);
    setState(() => _activity = updated);
  }
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 32, height: 3, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2))),
          _sheetOption(Icons.camera_alt_outlined, 'Take Photo', () { Navigator.pop(context); _addPhoto(ImageSource.camera); }),
          _sheetOption(Icons.photo_library_outlined, 'Choose from Gallery', () { Navigator.pop(context); _addPhoto(ImageSource.gallery); }),
          const SizedBox(height: 8),
        ]),
      )),
    );
  }
  Widget _sheetOption(IconData icon, String label, VoidCallback onTap) => ListTile(
    leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: AppTheme.surfaceBg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppTheme.orange, size: 20)),
    title: Text(label, style: GoogleFonts.dmSans(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
    onTap: onTap,
  );
  void _viewPhoto(String path) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _PhotoViewer(path: path)));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: AppTheme.darkBg,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.cardBg.withOpacity(0.9), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
                child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 20)),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(children: [
              if (_activity.route.length > 1)
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _center, initialZoom: _calcZoom(),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a','b','c','d'], userAgentPackageName: 'com.stravaclone.app'),
                    PolylineLayer(polylines: [Polyline(points: _activity.route, color: AppTheme.orange, strokeWidth: 4)]),
                    MarkerLayer(markers: [
                      Marker(point: _activity.route.first, width: 14, height: 14,
                          child: Container(decoration: BoxDecoration(color: AppTheme.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                      Marker(point: _activity.route.last, width: 14, height: 14,
                          child: Container(decoration: BoxDecoration(color: AppTheme.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                    ]),
                  ],
                )
              else
                Container(color: AppTheme.cardBg, child: Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.map_outlined, size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 8),
                    Text('No route data', style: GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 13)),
                  ]),
                )),
              Positioned(bottom:0, left:0, right:0, height: 80,
                  child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppTheme.darkBg.withOpacity(0.9)])))),
              Positioned(bottom: 16, right: 16,
                  child: Row(children: [
                    _legendDot(AppTheme.green), const SizedBox(width: 4),
                    Text('Start', style: GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(width: 12),
                    _legendDot(AppTheme.red), const SizedBox(width: 4),
                    Text('Finish', style: GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 11)),
                  ])),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: AppTheme.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.orange.withOpacity(0.2))),
                  child: const Icon(Icons.directions_walk_rounded, color: AppTheme.orange, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_activity.name, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                Text(DateFormat('EEE, MMM d, y · h:mm a').format(_activity.startTime),
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.textSecondary)),
              ])),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _bigStat('${(_activity.distanceMeters/1000).toStringAsFixed(2)}', 'km', 'Distance')),
              const SizedBox(width: 12),
              Expanded(child: _bigStat(_activity.durationString, '', 'Duration')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: StatCard(label: 'Pace', value: _activity.paceString, unit: '/km', icon: Icons.speed_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Steps', value: '${_activity.steps}', icon: Icons.directions_walk_rounded)),
            ]),
            const SizedBox(height: 32),
            Row(children: [
              Container(width: 3, height: 18, decoration: BoxDecoration(color: AppTheme.orange, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text('Photos', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              if (_savingPhoto)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.orange))
              else
                GestureDetector(
                  onTap: _showPhotoOptions,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.orange.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.add_a_photo_outlined, size: 14, color: AppTheme.orange),
                      const SizedBox(width: 6),
                      Text('Add Photo', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.orange)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            if (_activity.photoPaths.isEmpty)
              GestureDetector(
                onTap: _showPhotoOptions,
                child: Container(
                  width: double.infinity, height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.divider, style: BorderStyle.solid),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppTheme.textMuted),
                    const SizedBox(height: 8),
                    Text('Tap to add photos', style: GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 13)),
                    Text('Camera or gallery', style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 11)),
                  ]),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: _activity.photoPaths.length + 1,
                itemBuilder: (_, i) {
                  if (i == _activity.photoPaths.length) {
                    return GestureDetector(
                      onTap: _showPhotoOptions,
                      child: Container(
                        decoration: BoxDecoration(
                            color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.divider)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.add_rounded, color: AppTheme.textSecondary, size: 24),
                          const SizedBox(height: 4),
                          Text('Add', style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.textSecondary)),
                        ]),
                      ),
                    );
                  }
                  final path = _activity.photoPaths[i];
                  return GestureDetector(
                    onTap: () => _viewPhoto(path),
                    onLongPress: () => _deletePhoto(path),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(fit: StackFit.expand, children: [
                        Image.file(File(path), fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: AppTheme.cardBg,
                                child: const Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary))),
                        Positioned(bottom: 0, left: 0, right: 0, height: 28,
                            child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.5)])))),
                      ]),
                    ),
                  );
                },
              ),
            if (_activity.photoPaths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Long press a photo to delete', style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.textMuted)),
              ),
            const SizedBox(height: 40),
          ]),
        )),
      ]),
    );
  }
  Widget _bigStat(String value, String unit, String label) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 1)),
      const SizedBox(height: 8),
      RichText(text: TextSpan(children: [
        TextSpan(text: value, style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1)),
        if (unit.isNotEmpty) TextSpan(text: ' $unit', style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.textSecondary)),
      ])),
    ]),
  );
  Widget _legendDot(Color color) => Container(width: 10, height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)));
}
class _PhotoViewer extends StatelessWidget {
  final String path;
  const _PhotoViewer({required this.path});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(children: [
      Center(child: InteractiveViewer(
        child: Image.file(File(path), fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64)),
      )),
      SafeArea(child: Padding(
        padding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 38, height: 38,
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20)),
        ),
      )),
    ]),
  );
}