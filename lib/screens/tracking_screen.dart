import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_model.dart';
import '../services/gps_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../widgets/stat_card.dart';

class MapStyle {
  final String name;
  final String url;
  final List<String>? subdomains;
  final String emoji;
  final bool isDark;

  const MapStyle({
    required this.name,
    required this.url,
    this.subdomains,
    required this.emoji,
    this.isDark = false,
  });
}

const List<MapStyle> kMapStyles = [
  MapStyle(name: 'OSM Standard',    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',                                          emoji: ''),
  MapStyle(name: 'OSM Germany',     url: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',                                           emoji: ''),
  MapStyle(name: 'OSM France',      url: 'https://tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',                                     emoji: ''),
  MapStyle(name: 'OSM Hot',         url: 'https://tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',                                       emoji: ''),
  MapStyle(name: 'Dark (CartoDB)',  url: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',       subdomains: ['a','b','c','d'], emoji: '', isDark: true),
  MapStyle(name: 'Dark No Labels',  url: 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png', subdomains: ['a','b','c','d'], emoji: '', isDark: true),
  MapStyle(name: 'Light (CartoDB)', url: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',      subdomains: ['a','b','c','d'], emoji: ''),
  MapStyle(name: 'Light No Labels', url: 'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png',subdomains: ['a','b','c','d'], emoji: ''),
  MapStyle(name: 'Stadia Dark',     url: 'https://tiles.stadiamaps.com/tiles/alidade_dark/{z}/{x}/{y}.png',                         emoji: '', isDark: true),
  MapStyle(name: 'Topo Map',        url: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',                                            emoji: ''),
  MapStyle(name: 'Hillshading',     url: 'https://tiles.wmflabs.org/hillshading/{z}/{x}/{y}.png',                                   emoji: ''),
  MapStyle(name: 'Black & White',   url: 'https://tiles.wmflabs.org/bw-mapnik/{z}/{x}/{y}.png',                                     emoji: '', isDark: true),
  MapStyle(name: 'CyclOSM',         url: 'https://tile.cyclosm.org/{z}/{x}/{y}.png',                                                emoji: ''),
  MapStyle(name: 'Wikimedia',       url: 'https://maps.wikimedia.org/osm-intl/{z}/{x}/{y}.png',                                     emoji: ''),
  MapStyle(name: 'Google Satellite',url: 'https://mt0.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',                                     emoji: '', isDark: true),
  MapStyle(name: 'Google Hybrid',   url: 'https://mt0.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',                                     emoji: '', isDark: true),
  MapStyle(name: 'Google Terrain',  url: 'https://mt0.google.com/vt/lyrs=p&x={x}&y={y}&z={z}',                                     emoji: ''),
];

class TrackingScreen extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onActivitySaved;

  const TrackingScreen({
    super.key,
    required this.storageService,
    required this.onActivitySaved,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with TickerProviderStateMixin {
  final _gps = GpsService();
  final _mapController = MapController();

  TrackingState _trackingState = TrackingState.idle;
  LatLng? _currentPosition;
  List<LatLng> _route = [];
  double _distance = 0;
  int _seconds = 0;
  double _speed = 0;
  int _steps = 0;
  bool _followUser = true;
  bool _permissionsGranted = false;
  bool _checkingPermissions = true;
  MapStyle _selectedStyle = kMapStyles[4];

  StreamSubscription? _updateSub;
  StreamSubscription? _stateSub;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _initGps();
  }

  Future<void> _initGps() async {
    final granted = await _gps.requestPermissions();
    if (!mounted) return;
    setState(() { _permissionsGranted = granted; _checkingPermissions = false; });
    if (granted) {
      final pos = await _gps.getCurrentLocation();
      if (mounted && pos != null) { setState(() => _currentPosition = pos); _mapController.move(pos, 16.5); }
    }
    _stateSub = _gps.stateStream.listen((s) { if (mounted) setState(() => _trackingState = s); });
    _updateSub = _gps.updates.listen((update) {
      if (!mounted) return;
      setState(() {
        _currentPosition = update.position; _distance = update.totalDistanceMeters;
        _seconds = update.totalSeconds; _speed = update.speedMps;
        _steps = update.steps; _route = List.from(_gps.route);
      });
      if (_followUser && _trackingState == TrackingState.active) {
        _mapController.move(update.position, _mapController.camera.zoom);
      }
    });
  }

  void _startActivity()  { HapticFeedback.mediumImpact(); _route=[]; _distance=0; _seconds=0; _steps=0; _gps.reset(); _gps.startTracking(); setState(() => _followUser = true); }
  void _pauseActivity()  { HapticFeedback.lightImpact(); _gps.pauseTracking(); }
  void _resumeActivity() { HapticFeedback.lightImpact(); _gps.resumeTracking(); }
  void _stopActivity()   { HapticFeedback.heavyImpact(); _gps.stopTracking(); _showSaveDialog(); }

  void _showMapStylePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
        builder: (_, scrollCtrl) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Icon(Icons.layers_rounded, color: AppTheme.orange, size: 22),
              const SizedBox(width: 10),
              Text('Map Style', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(child: ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: kMapStyles.length,
            itemBuilder: (_, i) {
              final style = kMapStyles[i];
              final isSelected = style.name == _selectedStyle.name;
              return GestureDetector(
                onTap: () { setState(() => _selectedStyle = style); Navigator.pop(context); HapticFeedback.selectionClick(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.orange.withOpacity(0.15) : AppTheme.surfaceBg,
                    borderRadius: BorderRadius.circular(14),
                    border: isSelected ? Border.all(color: AppTheme.orange.withOpacity(0.6), width: 1.5) : null,
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(style.name, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w600, color: isSelected ? AppTheme.orange : AppTheme.textPrimary)),
                      Text(style.isDark ? 'Dark theme' : 'Light theme', style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppTheme.textSecondary)),
                    ])),
                    if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.orange, size: 22),
                  ]),
                ),
              );
            },
          )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _showSaveDialog() {
    final hour = DateTime.now().hour;
    final nameCtrl = TextEditingController(
      text: 'Morning Walk ${hour < 12 ? '🌅' : hour < 17 ? '☀️' : '🌙'}',
    );
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Save Activity', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _summaryRow('Distance', '${(_distance/1000).toStringAsFixed(2)} km'),
          _summaryRow('Duration', FormatUtils.duration(_seconds)),
          _summaryRow('Pace', FormatUtils.pace(_distance, _seconds)),
          _summaryRow('Steps', '$_steps'),
          const SizedBox(height: 16),
          TextField(
            controller: nameCtrl,
            style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Activity Name',
              labelStyle: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary),
              filled: true, fillColor: AppTheme.surfaceBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _gps.reset(); setState(() { _route=[]; _distance=0; _seconds=0; _steps=0; }); },
            child: Text('Discard', style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final activity = ActivityModel(
                id: const Uuid().v4(),
                name: nameCtrl.text.trim().isEmpty ? 'Walking Activity' : nameCtrl.text.trim(),
                startTime: DateTime.now().subtract(Duration(seconds: _seconds)),
                endTime: DateTime.now(),
                route: _gps.route, distanceMeters: _distance,
                durationSeconds: _seconds, steps: _steps,
              );
              await widget.storageService.saveActivity(activity);
              widget.onActivitySaved();
              if (ctx.mounted) Navigator.pop(ctx);
              _gps.reset();
              setState(() { _route=[]; _distance=0; _seconds=0; _steps=0; });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary)),
      Text(value, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
    ]),
  );

  @override
  void dispose() { _updateSub?.cancel(); _stateSub?.cancel(); _gps.dispose(); _pulseController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_checkingPermissions) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.orange)));
    if (!_permissionsGranted) return _buildPermissionDenied();

    return Scaffold(
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition ?? const LatLng(14.5995, 120.9842),
                initialZoom: 16.5,
                onPositionChanged: (_, hasGesture) { if (hasGesture) setState(() => _followUser = false); },
              ),
              children: [
                TileLayer(urlTemplate: _selectedStyle.url, subdomains: _selectedStyle.subdomains ?? const <String>[], userAgentPackageName: 'com.stravaclone.app'),
                if (_route.length > 1) PolylineLayer(polylines: [Polyline(points: _route, color: AppTheme.orange, strokeWidth: 5)]),
                if (_route.isNotEmpty) MarkerLayer(markers: [
                  Marker(point: _route.first, width: 20, height: 20,
                      child: Container(decoration: BoxDecoration(color: AppTheme.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)))),
                ]),
                if (_currentPosition != null) MarkerLayer(markers: [
                  Marker(point: _currentPosition!, width: 60, height: 60,
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Stack(alignment: Alignment.center, children: [
                          if (_trackingState == TrackingState.active)
                            Transform.scale(scale: _pulseAnim.value,
                                child: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.orange.withOpacity(0.2), shape: BoxShape.circle))),
                          Container(width: 22, height: 22, decoration: BoxDecoration(
                            color: AppTheme.orange, shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: AppTheme.orange.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)],
                          )),
                        ]),
                      )),
                ]),
              ],
            ),
            Positioned(top: 0, left: 0, right: 0, height: 100,
                child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [AppTheme.darkBg.withOpacity(0.8), Colors.transparent])))),
            SafeArea(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Text('Track', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: _showMapStylePicker,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.orange.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.layers_rounded, color: AppTheme.orange, size: 14),
                      const SizedBox(width: 5),
                      Flexible(child: Text(_selectedStyle.name, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 3),
                      const Icon(Icons.expand_more_rounded, color: AppTheme.textSecondary, size: 14),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                if (!_followUser) ...[
                  _mapButton(Icons.my_location, () {
                    setState(() => _followUser = true);
                    if (_currentPosition != null) _mapController.move(_currentPosition!, _mapController.camera.zoom);
                  }),
                  const SizedBox(width: 8),
                ],
                _mapButton(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                const SizedBox(width: 8),
                _mapButton(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
              ]),
            )),
          ]),
        ),
        _buildBottomPanel(),
      ]),
    );
  }

  Widget _mapButton(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppTheme.cardBg.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: AppTheme.textPrimary, size: 20),
    ),
  );

  Widget _buildBottomPanel() {
    final isActive = _trackingState == TrackingState.active;
    final isPaused = _trackingState == TrackingState.paused;
    final isIdle   = _trackingState == TrackingState.idle || _trackingState == TrackingState.stopped;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)],
      ),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppTheme.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          if (!isIdle) ...[
            Row(children: [
              Expanded(child: StatCard(label: 'Distance', value: (_distance/1000).toStringAsFixed(2), unit: 'km', icon: Icons.straighten)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Time', value: FormatUtils.duration(_seconds), icon: Icons.timer_outlined, valueColor: isActive ? AppTheme.orange : AppTheme.textPrimary)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: StatCard(label: 'Pace', value: FormatUtils.pace(_distance, _seconds), unit: '/km', icon: Icons.speed)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Steps', value: '$_steps', icon: Icons.directions_walk)),
            ]),
            const SizedBox(height: 16),
          ] else ...[
            Column(children: [
              Icon(Icons.directions_walk_rounded, size: 48, color: AppTheme.orange.withOpacity(0.8)),
              const SizedBox(height: 8),
              Text('Ready to walk?', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text('Press Start to begin tracking your route', style: GoogleFonts.spaceGrotesk(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
            ]),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (isIdle)
              _bigButton(label: 'Start', icon: Icons.play_arrow_rounded, color: AppTheme.orange, onTap: _startActivity, size: 72)
            else if (isActive) ...[
              _smallButton(icon: Icons.pause_rounded, color: AppTheme.blue, onTap: _pauseActivity),
              const SizedBox(width: 20),
              _smallButton(icon: Icons.stop_rounded, color: Colors.red, onTap: _stopActivity),
            ] else if (isPaused) ...[
              _smallButton(icon: Icons.play_arrow_rounded, color: AppTheme.green, onTap: _resumeActivity),
              const SizedBox(width: 20),
              _smallButton(icon: Icons.stop_rounded, color: Colors.red, onTap: _stopActivity),
            ],
          ]),
        ]),
      )),
    );
  }

  Widget _bigButton({required String label, required IconData icon, required Color color, required VoidCallback onTap, double size = 64}) =>
      GestureDetector(onTap: onTap, child: Column(children: [
        Container(width: size, height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)]),
            child: Icon(icon, color: Colors.white, size: size * 0.5)),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      ]));

  Widget _smallButton({required IconData icon, required Color color, required VoidCallback onTap}) =>
      GestureDetector(onTap: onTap, child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
        child: Icon(icon, color: color, size: 28),
      ));

  Widget _buildPermissionDenied() => Scaffold(body: SafeArea(child: Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.location_off_rounded, size: 80, color: AppTheme.textSecondary),
      const SizedBox(height: 24),
      Text('Location Access Required', textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      const SizedBox(height: 12),
      Text('StrideTrack needs location access to track your walking route. Please enable it in Settings.',
          textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(fontSize: 15, color: AppTheme.textSecondary)),
      const SizedBox(height: 32),
      ElevatedButton.icon(
        onPressed: () async { setState(() => _checkingPermissions = true); await _initGps(); },
        icon: const Icon(Icons.refresh), label: const Text('Try Again'),
      ),
    ]),
  ))));
}