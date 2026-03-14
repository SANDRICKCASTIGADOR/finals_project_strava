import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../models/activity_model.dart';

// ── Storage Service Provider ──────────────────────────────────────────────────
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

// ── Activities Notifier ───────────────────────────────────────────────────────
class ActivitiesNotifier extends AsyncNotifier<List<ActivityModel>> {
  @override
  Future<List<ActivityModel>> build() async {
    return ref.read(storageServiceProvider).loadActivities();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
          () => ref.read(storageServiceProvider).loadActivities(),
    );
  }

  Future<void> save(ActivityModel activity) async {
    await ref.read(storageServiceProvider).saveActivity(activity);
    await reload();
  }

  Future<void> updateActivity(ActivityModel activity) async {
    await ref.read(storageServiceProvider).updateActivity(activity);
    await reload();
  }

  Future<void> delete(String id) async {
    await ref.read(storageServiceProvider).deleteActivity(id);
    await reload();
  }
}

final activitiesProvider =
AsyncNotifierProvider<ActivitiesNotifier, List<ActivityModel>>(
  ActivitiesNotifier.new,
);