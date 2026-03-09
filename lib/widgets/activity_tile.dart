// ─────────────────────────────────────────────────────────────────────────────
// activity_tile.dart
// List item widget for the History screen representing a single activity.
// Shows the activity name, date/time, key metrics (distance, time, pace, steps),
// a horizontal photo strip if photos are attached, and a more options menu
// that allows the user to delete the activity.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/activity_model.dart';
import '../utils/app_theme.dart';

class ActivityTile extends StatelessWidget {
  final ActivityModel activity;     // The activity data to display
  final VoidCallback onTap;         // Called when user taps the tile
  final VoidCallback? onDelete;     // Called when user confirms delete

  const ActivityTile({
    super.key,
    required this.activity,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = activity.photoPaths.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Photo Strip ───────────────────────────────────────────────
            // Shows horizontally scrollable photo thumbnails if photos exist
            if (hasPhoto)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: activity.photoPaths.length,
                    itemBuilder: (_, i) => Image.file(
                      File(activity.photoPaths[i]),
                      width: 120, height: 120, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 120, color: AppTheme.surfaceBg,
                        child: const Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Activity Info ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Activity icon + name + date + options menu
                  Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.directions_walk_rounded, color: AppTheme.orange, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(activity.name,
                            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        Text(DateFormat('EEE, MMM d · h:mm a').format(activity.startTime),
                            style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    )),
                    // Three-dot options button
                    if (onDelete != null)
                      GestureDetector(
                        onTap: () => _showOptions(context),
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: AppTheme.surfaceBg, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.more_horiz, color: AppTheme.textSecondary, size: 16),
                        ),
                      ),
                  ]),

                  const SizedBox(height: 12),
                  Container(height: 1, color: AppTheme.divider), // Divider line
                  const SizedBox(height: 12),

                  // ── Metrics Row ─────────────────────────────────────────
                  // Distance | Time | Pace | Steps
                  Row(children: [
                    _metric('${(activity.distanceMeters / 1000).toStringAsFixed(2)}', 'km'),
                    _vline(),
                    _metric(activity.durationString, 'time'),
                    _vline(),
                    _metric(activity.paceString, '/km'),
                    _vline(),
                    _metric('${activity.steps}', 'steps'),
                  ]),

                  // ── Photo Count Badge ───────────────────────────────────
                  if (hasPhoto) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.photo_library_outlined, size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${activity.photoPaths.length} photo${activity.photoPaths.length > 1 ? 's' : ''}',
                        style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Single metric column: value on top, unit below
  Widget _metric(String val, String unit) => Expanded(
    child: Column(children: [
      Text(val, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      Text(unit, style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.textSecondary)),
    ]),
  );

  // Vertical divider between metrics
  Widget _vline() => Container(width: 1, height: 24, color: AppTheme.divider);

  // Bottom sheet with delete option
  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 32, height: 3,
              decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppTheme.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.delete_outline_rounded, color: AppTheme.red, size: 18),
            ),
            title: Text('Delete Activity', style: GoogleFonts.dmSans(color: AppTheme.red, fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); onDelete?.call(); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}