import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/activity_model.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../utils/share_helper.dart';
import '../widgets/activity_tile.dart';
import 'activity_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final StorageService storageService;
  final int refreshKey;
  const HistoryScreen({super.key, required this.storageService, required this.refreshKey});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ActivityModel> _activities = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(covariant HistoryScreen old) {
    super.didUpdateWidget(old);
    if (old.refreshKey != widget.refreshKey) _load();
  }

  Future<void> _load() async {
    final list = await widget.storageService.loadActivities();
    if (mounted) setState(() { _activities = list; _loading = false; });
  }

  Future<void> _delete(String id) async {
    await widget.storageService.deleteActivity(id);
    await _load();
  }

  Future<void> _shareActivity(ActivityModel activity) async {
    await shareActivity(activity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Activities', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              Text('Your walking history', style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textSecondary)),
            ]),
            const Spacer(),
            if (_activities.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.orange.withOpacity(0.2))),
                child: Text('${_activities.length}', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.orange)),
              ),
          ]),
        ),
        if (_activities.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSummaryBar(),
        ],
        const SizedBox(height: 8),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.orange, strokeWidth: 2))
            : _activities.isEmpty ? _buildEmpty()
            : RefreshIndicator(
          color: AppTheme.orange, backgroundColor: AppTheme.cardBg,
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 90, top: 4),
            itemCount: _activities.length,
            itemBuilder: (_, i) => ActivityTile(
              activity: _activities[i],
              onTap: () => _openDetail(_activities[i]),
              onDelete: () => _delete(_activities[i].id),
              onShare: () => _shareActivity(_activities[i]),
            ),
          ),
        )),
      ])),
    );
  }

  Widget _buildSummaryBar() {
    final totalKm    = _activities.fold<double>(0, (s, a) => s + a.distanceMeters / 1000);
    final totalTime  = _activities.fold<int>(0, (s, a) => s + a.durationSeconds);
    final totalSteps = _activities.fold<int>(0, (s, a) => s + a.steps);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _summaryItem('${totalKm.toStringAsFixed(1)}', 'Total km'),
        _vDiv(),
        _summaryItem(_fmtHours(totalTime), 'Total time'),
        _vDiv(),
        _summaryItem('${(totalSteps/1000).toStringAsFixed(1)}k', 'Steps'),
      ]),
    );
  }

  Widget _summaryItem(String val, String label) => Column(children: [
    Text(val, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.orange)),
    Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.textSecondary)),
  ]);

  Widget _vDiv() => Container(width: 1, height: 28, color: AppTheme.divider);

  String _fmtHours(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 64, height: 64, decoration: BoxDecoration(color: AppTheme.cardBg, shape: BoxShape.circle, border: Border.all(color: AppTheme.divider)),
        child: Icon(Icons.directions_walk_rounded, size: 28, color: AppTheme.textMuted)),
    const SizedBox(height: 16),
    Text('No activities yet', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
    const SizedBox(height: 6),
    Text('Start your first walk to see it here', style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textMuted)),
  ]));

  void _openDetail(ActivityModel activity) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ActivityDetailScreen(activity: activity, storageService: widget.storageService),
    )).then((_) => _load());
  }
}