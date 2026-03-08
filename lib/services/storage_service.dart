import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_model.dart';

class StorageService {
  static const _key = 'activities_v1';

  Future<List<ActivityModel>> loadActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) {
      try {
        return ActivityModel.fromJsonString(s);
      } catch (_) {
        return null;
      }
    })
        .whereType<ActivityModel>()
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Future<void> saveActivity(ActivityModel activity) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    // Prepend newest
    existing.insert(0, activity.toJsonString());
    // Keep max 200 activities
    if (existing.length > 200) existing.removeRange(200, existing.length);
    await prefs.setStringList(_key, existing);
  }

  Future<void> deleteActivity(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    existing.removeWhere((s) {
      try {
        final m = jsonDecode(s) as Map;
        return m['id'] == id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_key, existing);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}