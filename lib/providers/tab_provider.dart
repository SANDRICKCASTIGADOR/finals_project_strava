import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Current tab index ─────────────────────────────────────────────────────────
final tabProvider = StateProvider<int>((ref) => 0);