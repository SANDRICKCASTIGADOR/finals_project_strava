import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/storage_provider.dart';
import '../utils/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);

    return Scaffold(
      body: SafeArea(
        child: activitiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.orange)),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (activities) {
            final totalKm    = activities.fold<double>(0, (s, a) => s + a.distanceMeters / 1000);
            final totalTime  = activities.fold<int>(0, (s, a) => s + a.durationSeconds);
            final totalSteps = activities.fold<int>(0, (s, a) => s + a.steps);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                Row(children: [
                  Container(width: 56, height: 56, decoration: const BoxDecoration(color: AppTheme.orange, shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 30)),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Athlete', style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    Text('${activities.length} activities', style: GoogleFonts.spaceGrotesk(fontSize: 14, color: AppTheme.textSecondary)),
                  ]),
                ]),
                const SizedBox(height: 24),
                _sectionTitle('All-Time Stats'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
                  children: [
                    _statCard('${totalKm.toStringAsFixed(1)}', 'km', 'Total Distance', Icons.straighten, AppTheme.orange),
                    _statCard(_formatTime(totalTime), '', 'Total Time', Icons.timer_outlined, AppTheme.blue),
                    _statCard('${(totalSteps / 1000).toStringAsFixed(1)}k', '', 'Total Steps', Icons.directions_walk, AppTheme.green),
                    _statCard('${activities.length}', '', 'Activities', Icons.bar_chart_rounded, Colors.purple),
                  ],
                ),
                const SizedBox(height: 24),
                _sectionTitle('Achievements'),
                const SizedBox(height: 12),
                _achievement('🏃 First Steps',   'Complete your first walk',      activities.isNotEmpty),
                _achievement('📍 Explorer',       'Walk 1km total',                totalKm >= 1),
                _achievement('🔥 Committed',      'Complete 5 activities',         activities.length >= 5),
                _achievement('🌟 Marathon',       'Walk 10km total',               totalKm >= 10),
                _achievement('👣 Step Master',    'Accumulate 10,000 steps',       totalSteps >= 10000),
                const SizedBox(height: 80),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary));

  Widget _statCard(String value, String unit, String label, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          RichText(text: TextSpan(children: [
            TextSpan(text: value, style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1)),
            if (unit.isNotEmpty) TextSpan(text: ' $unit', style: GoogleFonts.spaceGrotesk(fontSize: 13, color: AppTheme.textSecondary)),
          ])),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
      );

  Widget _achievement(String title, String desc, bool unlocked) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: unlocked ? AppTheme.orange.withOpacity(0.1) : AppTheme.cardBg,
      borderRadius: BorderRadius.circular(14),
      border: unlocked ? Border.all(color: AppTheme.orange.withOpacity(0.3)) : null,
    ),
    child: Row(children: [
      Text(title.split(' ').first, style: const TextStyle(fontSize: 28)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.split(' ').skip(1).join(' '), style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: unlocked ? AppTheme.textPrimary : AppTheme.textSecondary)),
        Text(desc, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppTheme.textSecondary)),
      ])),
      Icon(unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
          color: unlocked ? AppTheme.orange : AppTheme.textSecondary, size: unlocked ? 22 : 20),
    ]),
  );

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}