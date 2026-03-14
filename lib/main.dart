import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/tab_provider.dart';
import 'screens/tracking_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'utils/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    const ProviderScope(child: StepWalkingApp()),
  );
}

class StepWalkingApp extends StatelessWidget {
  const StepWalkingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StepWalking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const MainShell(),
    );
  }
}

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);

    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [
          TrackingScreen(),
          HistoryScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _NavBar(currentTab: tab),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────
class _NavBar extends ConsumerWidget {
  final int currentTab;
  const _NavBar({required this.currentTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: AppTheme.orange.withOpacity(0.15), width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            _NavItem(index: 0, icon: Icons.directions_walk_rounded, label: 'Track',   currentTab: currentTab),
            _NavItem(index: 1, icon: Icons.history_rounded,         label: 'History', currentTab: currentTab),
            _NavItem(index: 2, icon: Icons.person_rounded,          label: 'Profile', currentTab: currentTab),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  final int index;
  final IconData icon;
  final String label;
  final int currentTab;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.currentTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(tabProvider.notifier).state = index;
        },
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppTheme.orange.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: selected ? AppTheme.orange : AppTheme.textSecondary, size: 24),
          ),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? AppTheme.orange : AppTheme.textSecondary,
          )),
        ]),
      ),
    );
  }
}