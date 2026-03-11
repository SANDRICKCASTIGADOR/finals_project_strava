import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../models/activity_model.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../utils/share_helper.dart';
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

  @override
  void initState() { super.initState(); _activity = widget.activity; }

  LatLng get _center {
    if (_activity.route.isEmpty) return const LatLng(14.5995, 120.9842);
    double lat = 0, lng = 0;
    for (final pt in _activity.route) { lat += pt.latitude; lng += pt.longitude; }
    return LatLng(lat / _activity.route.length, lng / _activity.route.length);
  }

  Future<void> _addPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${dir.path}/activity_photos');
    await photoDir.create(recursive: true);
    final dest = '${photoDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(dest);
    final updated = _activity.copyWith(photoPaths: [..._activity.photoPaths, dest]);
    await widget.storageService.updateActivity(updated);
    setState(() => _activity = updated);
  }

  Future<void> _deletePhoto(String path) async {
    final updated = _activity.copyWith(photoPaths: _activity.photoPaths.where((x) => x != path).toList());
    await widget.storageService.updateActivity(updated);
    setState(() => _activity = updated);
    try { await File(path).delete(); } catch (_) {}
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.orange), title: Text('Take Photo', style: GoogleFonts.dmSans(color: AppTheme.textPrimary)), onTap: () { Navigator.pop(context); _addPhoto(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.photo_library_rounded, color: AppTheme.orange), title: Text('Choose from Gallery', style: GoogleFonts.dmSans(color: AppTheme.textPrimary)), onTap: () { Navigator.pop(context); _addPhoto(ImageSource.gallery); }),
        const SizedBox(height: 8),
      ])),
    );
  }

  Future<void> _shareActivity() async {
    await shareActivity(_activity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 280, pinned: true, backgroundColor: AppTheme.darkBg,
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
          actions: [
            IconButton(icon: const Icon(Icons.share_rounded, color: AppTheme.orange), onPressed: _shareActivity),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(children: [
              if (_activity.route.length > 1)
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _center, initialZoom: _calcZoom(),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', subdomains: const ['a','b','c','d'], userAgentPackageName: 'com.stravaclone.app'),
                    PolylineLayer(polylines: [Polyline(points: _activity.route, color: AppTheme.orange, strokeWidth: 5)]),
                    MarkerLayer(markers: [
                      Marker(point: _activity.route.first, width: 16, height: 16, child: Container(decoration: BoxDecoration(color: AppTheme.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                      Marker(point: _activity.route.last, width: 16, height: 16, child: Container(decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                    ]),
                  ],
                )
              else
                Container(color: AppTheme.cardBg, child: const Center(child: Icon(Icons.map_outlined, size: 60, color: AppTheme.textSecondary))),
              Positioned(bottom: 0, left: 0, right: 0, height: 60,
                  child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppTheme.darkBg.withOpacity(0.8)])))),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.directions_walk_rounded, color: AppTheme.orange, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_activity.name, style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                Text(DateFormat('EEEE, MMMM d, y · h:mm a').format(_activity.startTime), style: GoogleFonts.spaceGrotesk(fontSize: 13, color: AppTheme.textSecondary)),
              ])),
              GestureDetector(
                onTap: _shareActivity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.orange, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.share_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('Share', style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _bigStat('${(_activity.distanceMeters/1000).toStringAsFixed(2)}', 'km', 'Distance')),
              const SizedBox(width: 12),
              Expanded(child: _bigStat(_activity.durationString, '', 'Duration')),
            ]),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2,
              children: [
                StatCard(label: 'Pace', value: _activity.paceString, unit: '/km', icon: Icons.speed),
                StatCard(label: 'Steps', value: '${_activity.steps}', icon: Icons.directions_walk),
              ],
            ),
            const SizedBox(height: 24),
            Row(children: [
              _legendDot(AppTheme.green), const SizedBox(width: 6),
              Text('Start', style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(width: 20),
              _legendDot(Colors.red), const SizedBox(width: 6),
              Text('Finish', style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 13)),
            ]),
            const SizedBox(height: 32),
            Row(children: [
              Text('Photos', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: _showPhotoOptions,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.orange.withOpacity(0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_a_photo_rounded, color: AppTheme.orange, size: 16),
                    const SizedBox(width: 6),
                    Text('Add Photo', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.orange)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            if (_activity.photoPaths.isEmpty)
              Container(
                width: double.infinity, height: 100,
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.photo_camera_outlined, color: AppTheme.textMuted, size: 28),
                  const SizedBox(height: 8),
                  Text('No photos yet', style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textMuted)),
                ]),
              )
            else
              GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: _activity.photoPaths.length,
                itemBuilder: (_, i) {
                  final path = _activity.photoPaths[i];
                  return GestureDetector(
                    onTap: () => _viewPhoto(path),
                    onLongPress: () => _confirmDelete(path),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppTheme.cardBg, child: const Icon(Icons.broken_image, color: AppTheme.textMuted))),
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
          ]),
        )),
      ]),
    );
  }

  void _viewPhoto(String path) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: Center(child: InteractiveViewer(child: Image.file(File(path)))),
    )));
  }

  void _confirmDelete(String path) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: Text('Delete Photo?', style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary))),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); _deletePhoto(path); }, child: const Text('Delete')),
      ],
    ));
  }

  Widget _bigStat(String value, String unit, String label) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 0.8)),
      const SizedBox(height: 8),
      RichText(text: TextSpan(children: [
        TextSpan(text: value, style: GoogleFonts.spaceGrotesk(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1)),
        if (unit.isNotEmpty) TextSpan(text: ' $unit', style: GoogleFonts.spaceGrotesk(fontSize: 16, color: AppTheme.textSecondary)),
      ])),
    ]),
  );

  Widget _legendDot(Color color) => Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)));

  double _calcZoom() {
    if (_activity.route.length < 2) return 15;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final pt in _activity.route) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }
    final maxDiff = (maxLat - minLat) > (maxLng - minLng) ? (maxLat - minLat) : (maxLng - minLng);
    if (maxDiff < 0.002) return 16;
    if (maxDiff < 0.01)  return 15;
    if (maxDiff < 0.05)  return 13;
    if (maxDiff < 0.1)   return 12;
    return 11;
  }
}