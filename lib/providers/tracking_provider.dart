import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/gps_service.dart';

// ── Tracking State Model ──────────────────────────────────────────────────────
class TrackingData {
  final TrackingState state;
  final LatLng? currentPosition;
  final List<LatLng> route;
  final double distance;
  final int seconds;
  final double speed;
  final int steps;
  final bool followUser;
  final bool permissionsGranted;
  final bool checkingPermissions;

  const TrackingData({
    this.state = TrackingState.idle,
    this.currentPosition,
    this.route = const [],
    this.distance = 0,
    this.seconds = 0,
    this.speed = 0,
    this.steps = 0,
    this.followUser = true,
    this.permissionsGranted = false,
    this.checkingPermissions = true,
  });

  TrackingData copyWith({
    TrackingState? state,
    LatLng? currentPosition,
    List<LatLng>? route,
    double? distance,
    int? seconds,
    double? speed,
    int? steps,
    bool? followUser,
    bool? permissionsGranted,
    bool? checkingPermissions,
  }) {
    return TrackingData(
      state: state ?? this.state,
      currentPosition: currentPosition ?? this.currentPosition,
      route: route ?? this.route,
      distance: distance ?? this.distance,
      seconds: seconds ?? this.seconds,
      speed: speed ?? this.speed,
      steps: steps ?? this.steps,
      followUser: followUser ?? this.followUser,
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      checkingPermissions: checkingPermissions ?? this.checkingPermissions,
    );
  }
}

// ── Tracking Notifier ─────────────────────────────────────────────────────────
class TrackingNotifier extends StateNotifier<TrackingData> {
  final GpsService _gps;
  StreamSubscription? _updateSub;
  StreamSubscription? _stateSub;

  TrackingNotifier(this._gps) : super(const TrackingData()) {
    _init();
  }

  Future<void> _init() async {
    final granted = await _gps.requestPermissions();
    state = state.copyWith(
      permissionsGranted: granted,
      checkingPermissions: false,
    );

    if (granted) {
      final pos = await _gps.getCurrentLocation();
      if (pos != null) state = state.copyWith(currentPosition: pos);
    }

    _stateSub = _gps.stateStream.listen((s) {
      state = state.copyWith(state: s);
    });

    _updateSub = _gps.updates.listen((update) {
      state = state.copyWith(
        currentPosition: update.position,
        distance: update.totalDistanceMeters,
        seconds: update.totalSeconds,
        speed: update.speedMps,
        steps: update.steps,
        route: List.from(_gps.route),
      );
    });
  }

  void start() {
    _gps.reset();
    _gps.startTracking();
    state = state.copyWith(
      route: [],
      distance: 0,
      seconds: 0,
      steps: 0,
      followUser: true,
    );
  }

  void pause() => _gps.pauseTracking();
  void resume() => _gps.resumeTracking();
  void stop() => _gps.stopTracking();
  void reset() {
    _gps.reset();
    state = state.copyWith(route: [], distance: 0, seconds: 0, steps: 0);
  }

  void setFollowUser(bool val) => state = state.copyWith(followUser: val);

  GpsService get gps => _gps;

  @override
  void dispose() {
    _updateSub?.cancel();
    _stateSub?.cancel();
    _gps.dispose();
    super.dispose();
  }
}

// ── GPS Service Provider ──────────────────────────────────────────────────────
final gpsServiceProvider = Provider<GpsService>((ref) {
  final gps = GpsService();
  ref.onDispose(gps.dispose);
  return gps;
});

// ── Tracking Provider ─────────────────────────────────────────────────────────
final trackingProvider =
StateNotifierProvider<TrackingNotifier, TrackingData>((ref) {
  return TrackingNotifier(ref.read(gpsServiceProvider));
});