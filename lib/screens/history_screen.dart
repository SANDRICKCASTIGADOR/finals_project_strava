import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/activity_model.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../widgets/activity_tile.dart';
import 'activity_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final StorageService storageService;
  final int refreshKey;

  const HistoryScreen({
    super.key,
    required this.storageService,
    required this.refreshKey,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ActivityModel> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HistoryScreen old) {
    super.didUpdateWidget(old);
    if (old.refreshKey != widget.refreshKey) _load();
  }

  Future<void> _load() async {
    final list = await widget.storageService.loadActivities();
    if (mounted) setState(() {
      _activities = list;
      _loading = false;
    });
  }

  Future<void> _delete(String id) async {
    await widget.storageService.deleteActivity(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'My Activities',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_activities.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_activities.length}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.orange,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Summary stats
            if (_activities.isNotEmpty) _buildSummaryBar(),

            Expanded(
              child: _loading
                  ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.orange))
                  : _activities.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                color: AppTheme.orange,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80, top: 8),
                  itemCount: _activities.length,
                  itemBuilder: (_, i) => ActivityTile(
                    activity: _activities[i],
                    onTap: () => _openDetail(_activities[i]),
                    onDelete: () => _delete(_activities[i].id),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    final totalKm = _activities.fold<double>(
        0, (s, a) => s + a.distanceMeters / 1000);
    final totalTime = _activities.fold<int>(0, (s, a) => s + a.durationSeconds);
    final totalSteps = _activities.fold<int>(0, (s, a) => s + a.steps);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.orange.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('${totalKm.toStringAsFixed(1)}', 'Total km'),
          _vDivider(),
          _summaryItem(_formatHours(totalTime), 'Total time'),
          _vDivider(),
          _summaryItem('${(totalSteps / 1000).toStringAsFixed(1)}k', 'Steps'),
        ],
      ),
    );
  }

  Widget _summaryItem(String val, String label) => Column(
    children: [
      Text(
        val,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.orange,
        ),
      ),
      Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          color: AppTheme.textSecondary,
        ),
      ),
    ],
  );

  Widget _vDivider() => Container(
    width: 1,
    height: 30,
    color: AppTheme.orange.withOpacity(0.2),
  );

  String _formatHours(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.directions_walk_rounded,
          size: 72,
          color: AppTheme.textSecondary.withOpacity(0.3),
        ),
        const SizedBox(height: 16),
        Text(
          'No activities yet',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Start your first walk to see it here',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            color: AppTheme.textSecondary.withOpacity(0.6),
          ),
        ),
      ],
    ),
  );

  void _openDetail(ActivityModel activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(activity: activity),
      ),
    );
  }
}