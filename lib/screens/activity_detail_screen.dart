import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/activity_model.dart';
import '../utils/app_theme.dart';
import '../widgets/stat_card.dart';

class ActivityDetailScreen extends StatelessWidget {
  final ActivityModel activity;

  const ActivityDetailScreen({super.key, required this.activity});

  LatLng get _center {
    if (activity.route.isEmpty) return const LatLng(14.5995, 120.9842);
    double lat = 0, lng = 0;
    for (final p in activity.route) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / activity.route.length, lng / activity.route.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.darkBg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  if (activity.route.length > 1)
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _calcZoom(),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.stravaclone.app',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: activity.route,
                              color: AppTheme.orange,
                              strokeWidth: 5,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: activity.route.first,
                              width: 16,
                              height: 16,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                            Marker(
                              point: activity.route.last,
                              width: 16,
                              height: 16,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Container(
                      color: AppTheme.cardBg,
                      child: const Center(
                        child: Icon(
                          Icons.map_outlined,
                          size: 60,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppTheme.darkBg.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.directions_walk_rounded,
                          color: AppTheme.orange,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.name,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE, MMMM d, y · h:mm a')
                                  .format(activity.startTime),
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Primary stats
                  Row(
                    children: [
                      Expanded(
                        child: _bigStat(
                          '${(activity.distanceMeters / 1000).toStringAsFixed(2)}',
                          'km',
                          'Distance',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _bigStat(
                          activity.durationString,
                          '',
                          'Duration',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                    children: [
                      StatCard(
                        label: 'Pace',
                        value: activity.paceString,
                        unit: '/km',
                        icon: Icons.speed,
                      ),
                      StatCard(
                        label: 'Steps',
                        value: '${activity.steps}',
                        icon: Icons.directions_walk,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Legend
                  Row(
                    children: [
                      _legendDot(AppTheme.green),
                      const SizedBox(width: 6),
                      Text(
                        'Start',
                        style: GoogleFonts.spaceGrotesk(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(width: 20),
                      _legendDot(Colors.red),
                      const SizedBox(width: 6),
                      Text(
                        'Finish',
                        style: GoogleFonts.spaceGrotesk(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigStat(String value, String unit, String label) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(children: [
            TextSpan(
              text: value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                height: 1,
              ),
            ),
            if (unit.isNotEmpty)
              TextSpan(
                text: ' $unit',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
          ]),
        ),
      ],
    ),
  );

  Widget _legendDot(Color color) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
    ),
  );

  double _calcZoom() {
    if (activity.route.length < 2) return 15;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in activity.route) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    if (maxDiff < 0.002) return 16;
    if (maxDiff < 0.01) return 15;
    if (maxDiff < 0.05) return 13;
    if (maxDiff < 0.1) return 12;
    return 11;
  }
}