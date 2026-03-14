import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../models/activity_model.dart';
import '../providers/map_style_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/tab_provider.dart';
import '../providers/tracking_provider.dart';
import '../services/gps_service.dart';
import '../utils/app_theme.dart';
import '../widgets/stat_card.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});
  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen>
    with TickerProviderStateMixin {
  final _mapController = MapController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseController.dispose(); super.dispose(); }

  void _start()  { HapticFeedback.mediumImpact(); ref.read(trackingProvider.notifier).start(); }
  void _pause()  { HapticFeedback.lightImpact();  ref.read(trackingProvider.notifier).pause(); }
  void _resume() { HapticFeedback.lightImpact();  ref.read(trackingProvider.notifier).resume(); }
  void _stop()   { HapticFeedback.heavyImpact();  ref.read(trackingProvider.notifier).stop(); _showSaveDialog(); }

  void _showMapStylePicker() {
    final current = ref.read(mapStyleProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
        builder: (_, ctrl) => Column(children: [
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
            controller: ctrl,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: kMapStyles.length,
            itemBuilder: (_, i) {
              final style = kMapStyles[i];
              final isSelected = style.name == current.name;
              return GestureDetector(
                onTap: () {
                  ref.read(mapStyleProvider.notifier).state = style;
                  Navigator.pop(context);
                  HapticFeedback.selectionClick();
                },
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
    final data = ref.read(trackingProvider);
    final notifier = ref.read(trackingProvider.notifier);
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
          _summaryRow('Distance', '${(data.distance/1000).toStringAsFixed(2)} km'),
          _summaryRow('Duration', FormatUtils.duration(data.seconds)),
          _summaryRow('Pace', FormatUtils.pace(data.distance, data.seconds)),
          _summaryRow('Steps', '${data.steps}'),
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
            onPressed: () { Navigator.pop(ctx); notifier.reset(); },
            child: Text('Discard', style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final activity = ActivityModel(
                id: const Uuid().v4(),
                name: nameCtrl.text.trim().isEmpty ? 'Walking Activity' : nameCtrl.text.trim(),
                startTime: DateTime.now().subtract(Duration(seconds: data.seconds)),
                endTime: DateTime.now(),
                route: notifier.gps.route,
                distanceMeters: data.distance,
                durationSeconds: data.seconds,
                steps: data.steps,
              );
              await ref.read(activitiesProvider.notifier).save(activity);
              notifier.reset();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ref.read(tabProvider.notifier).state = 1;
              }
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
  Widget build(BuildContext context) {
    final data      = ref.watch(trackingProvider);
    final mapStyle  = ref.watch(mapStyleProvider);

    if (data.checkingPermissions) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.orange)));
    }
    if (!data.permissionsGranted) return _buildPermissionDenied();

    final isActive = data.state == TrackingState.active;
    final isPaused = data.state == TrackingState.paused;
    final isIdle   = data.state == TrackingState.idle || data.state == TrackingState.stopped;

    // Move map when following
    if (data.followUser && isActive && data.currentPosition != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(data.currentPosition!, _mapController.camera.zoom);
      });
    }

    return Scaffold(
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: data.currentPosition ?? const LatLng(14.5995, 120.9842),
                initialZoom: 16.5,
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture) ref.read(trackingProvider.notifier).setFollowUser(false);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: mapStyle.url,
                  subdomains: mapStyle.subdomains ?? const [],
                  userAgentPackageName: 'com.stravaclone.app',
                ),
                if (data.route.length > 1)
                  PolylineLayer(polylines: [Polyline(points: data.route, color: AppTheme.orange, strokeWidth: 5)]),
                if (data.route.isNotEmpty)
                  MarkerLayer(markers: [
                    Marker(point: data.route.first, width: 20, height: 20,
                        child: Container(decoration: BoxDecoration(color: AppTheme.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)))),
                  ]),
                if (data.currentPosition != null)
                  MarkerLayer(markers: [
                    Marker(point: data.currentPosition!, width: 60, height: 60,
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Stack(alignment: Alignment.center, children: [
                            if (isActive) Transform.scale(scale: _pulseAnim.value,
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
            // Gradient top
            Positioned(top: 0, left: 0, right: 0, height: 100,
                child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [AppTheme.darkBg.withOpacity(0.8), Colors.transparent])))),
            // Top bar
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
                      Flexible(child: Text(mapStyle.name, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 3),
                      const Icon(Icons.expand_more_rounded, color: AppTheme.textSecondary, size: 14),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                if (!data.followUser) ...[
                  _mapBtn(Icons.my_location, () {
                    ref.read(trackingProvider.notifier).setFollowUser(true);
                    if (data.currentPosition != null) {
                      _mapController.move(data.currentPosition!, _mapController.camera.zoom);
                    }
                  }),
                  const SizedBox(width: 8),
                ],
                _mapBtn(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                const SizedBox(width: 8),
                _mapBtn(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
              ]),
            )),
          ]),
        ),
        // Bottom panel
        Container(
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
                  Expanded(child: StatCard(label: 'Distance', value: (data.distance/1000).toStringAsFixed(2), unit: 'km', icon: Icons.straighten)),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(label: 'Time', value: FormatUtils.duration(data.seconds), icon: Icons.timer_outlined, valueColor: isActive ? AppTheme.orange : AppTheme.textPrimary)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: StatCard(label: 'Pace', value: FormatUtils.pace(data.distance, data.seconds), unit: '/km', icon: Icons.speed)),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(label: 'Steps', value: '${data.steps}', icon: Icons.directions_walk)),
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
                  _bigBtn('Start', Icons.play_arrow_rounded, AppTheme.orange, _start, 72)
                else if (isActive) ...[
                  _smallBtn(Icons.pause_rounded, AppTheme.blue, _pause),
                  const SizedBox(width: 20),
                  _smallBtn(Icons.stop_rounded, Colors.red, _stop),
                ] else if (isPaused) ...[
                  _smallBtn(Icons.play_arrow_rounded, AppTheme.green, _resume),
                  const SizedBox(width: 20),
                  _smallBtn(Icons.stop_rounded, Colors.red, _stop),
                ],
              ]),
            ]),
          )),
        ),
      ]),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppTheme.cardBg.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20)),
  );

  Widget _bigBtn(String label, IconData icon, Color color, VoidCallback onTap, double size) =>
      GestureDetector(onTap: onTap, child: Column(children: [
        Container(width: size, height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)]),
            child: Icon(icon, color: Colors.white, size: size * 0.5)),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      ]));

  Widget _smallBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: Container(width: 60, height: 60,
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
          child: Icon(icon, color: color, size: 28)));

  Widget _buildPermissionDenied() => Scaffold(body: SafeArea(child: Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.location_off_rounded, size: 80, color: AppTheme.textSecondary),
      const SizedBox(height: 24),
      Text('Location Access Required', textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      const SizedBox(height: 12),
      Text('StepWalking needs location access to track your route.', textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(fontSize: 15, color: AppTheme.textSecondary)),
      const SizedBox(height: 32),
      ElevatedButton.icon(
        onPressed: () => ref.invalidate(trackingProvider),
        icon: const Icon(Icons.refresh),
        label: const Text('Try Again'),
      ),
    ]),
  ))));
}