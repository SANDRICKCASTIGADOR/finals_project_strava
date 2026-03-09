// ─────────────────────────────────────────────────────────────────────────────
// storage_service.dart
// Handles persistent local storage of activity data using SharedPreferences.
// Activities are stored as a JSON string list, sorted newest-first.
// Supports save, load, update (for adding photos), and delete operations.
// Max 200 activities are retained to avoid excessive storage usage.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_model.dart';

class StorageService {
  // SharedPreferences key for the activities list
  static const _key = 'activities_v1';

  // ── Load ──────────────────────────────────────────────────────────────────
  // Fetches all saved activities, sorted by start time (newest first).
  // Corrupted entries are silently skipped.
  Future<List<ActivityModel>> loadActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) { try { return ActivityModel.fromJsonString(s); } catch (_) { return null; } })
        .whereType<ActivityModel>()
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  // Saves a new activity. Inserts at position 0 (newest first).
  // Trims the list to a maximum of 200 entries.
  Future<void> saveActivity(ActivityModel activity) async {
    final prefs    = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    existing.insert(0, activity.toJsonString());
    if (existing.length > 200) existing.removeRange(200, existing.length);
    await prefs.setStringList(_key, existing);
  }

  // ── Update ────────────────────────────────────────────────────────────────
  // Replaces an existing activity entry in-place (used for adding/removing photos).
  // Matches by activity ID.
  Future<void> updateActivity(ActivityModel activity) async {
    final prefs    = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    final idx = existing.indexWhere((s) {
      try { return (jsonDecode(s) as Map)['id'] == activity.id; }
      catch (_) { return false; }
    });
    if (idx != -1) {
      existing[idx] = activity.toJsonString();
      await prefs.setStringList(_key, existing);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  // Removes a single activity by its ID.
  Future<void> deleteActivity(String id) async {
    final prefs    = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    existing.removeWhere((s) {
      try { return (jsonDecode(s) as Map)['id'] == id; }
      catch (_) { return false; }
    });
    await prefs.setStringList(_key, existing);
  }

  // ── Clear All ─────────────────────────────────────────────────────────────
  // Deletes all saved activities (used for reset/debug purposes).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}