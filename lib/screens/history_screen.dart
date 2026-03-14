import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/activity_model.dart';
import '../providers/storage_provider.dart';
import '../utils/app_theme.dart';
import '../utils/share_helper.dart';
import '../widgets/activity_tile.dart';
import 'activity_detail_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(child: activitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.orange, strokeWidth: 2)),
        error: (e, _) => Center(child: Text('Error: $e', style: GoogleFonts.dmSans(color: AppTheme.textSecondary))),
        data: (activities) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Activities', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                Text('Your walking history', style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textSecondary)),
              ]),
              const Spacer(),
              if (activities.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.orange.withOpacity(0.2))),
                  child: Text('${activities.length}', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.orange)),
                ),
            ]),
          ),
          if (activities.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SummaryBar(activities: activities),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: activities.isEmpty
                ? _EmptyState()
                : RefreshIndicator(
              color: AppTheme.orange, backgroundColor: AppTheme.cardBg,
              onRefresh: () => ref.refresh(activitiesProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 90, top: 4),
                itemCount: activities.length,
                itemBuilder: (_, i) => ActivityTile(
                  activity: activities[i],
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ActivityDetailScreen(activity: activities[i]),
                  )).then((_) => ref.invalidate(activitiesProvider)),
                  onDelete: () => ref.read(activitiesProvider.notifier).delete(activities[i].id),
                  onShare: () {
                    final photo = activities[i].photoPaths.isNotEmpty ? activities[i].photoPaths.first : null;
                    shareActivity(activities[i], photoPath: photo);
                  },
                ),
              ),
            ),
          ),
        ]),
      )),
    );
  }
}

// ── Summary Bar ───────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<ActivityModel> activities;
  const _SummaryBar({required this.activities});

  @override
  Widget build(BuildContext context) {
    final totalKm    = activities.fold<double>(0, (s, a) => s + a.distanceMeters / 1000);
    final totalTime  = activities.fold<int>(0, (s, a) => s + a.durationSeconds);
    final totalSteps = activities.fold<int>(0, (s, a) => s + a.steps);
    final h = totalTime ~/ 3600;
    final m = (totalTime % 3600) ~/ 60;
    final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _item('${totalKm.toStringAsFixed(1)}', 'Total km'),
        Container(width: 1, height: 28, color: AppTheme.divider),
        _item(timeStr, 'Total time'),
        Container(width: 1, height: 28, color: AppTheme.divider),
        _item('${(totalSteps/1000).toStringAsFixed(1)}k', 'Steps'),
      ]),
    );
  }

  Widget _item(String val, String label) => Column(children: [
    Text(val, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.orange)),
    Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.textSecondary)),
  ]);
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 64, height: 64, decoration: BoxDecoration(color: AppTheme.cardBg, shape: BoxShape.circle, border: Border.all(color: AppTheme.divider)),
        child: Icon(Icons.directions_walk_rounded, size: 28, color: AppTheme.textMuted)),
    const SizedBox(height: 16),
    Text('No activities yet', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
    const SizedBox(height: 6),
    Text('Start your first walk to see it here', style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textMuted)),
  ]));
}