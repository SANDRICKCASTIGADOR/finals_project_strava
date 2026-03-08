import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum TrackingState { idle, active, paused, stopped }

class TrackingUpdate {
  final LatLng position;
  final double speedMps;
  final double totalDistanceMeters;
  final int totalSeconds;
  final int steps;
  final double? heading;
  final double? accuracy;

  const TrackingUpdate({
    required this.position,
    required this.speedMps,
    required this.totalDistanceMeters,
    required this.totalSeconds,
    required this.steps,
    this.heading,
    this.accuracy,
  });
}

class GpsService {
  static const _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 3, // minimum 3 meters between updates
  );

  StreamSubscription<Position>? _positionSub;
  Timer? _clockTimer;

  final _updateController = StreamController<TrackingUpdate>.broadcast();
  final _stateController = StreamController<TrackingState>.broadcast();

  Stream<TrackingUpdate> get updates => _updateController.stream;
  Stream<TrackingState> get stateStream => _stateController.stream;

  TrackingState _state = TrackingState.idle;
  TrackingState get state => _state;

  final List<LatLng> _route = [];
  List<LatLng> get route => List.unmodifiable(_route);

  double _totalDistance = 0;
  int _totalSeconds = 0;
  int _steps = 0;
  LatLng? _lastPosition;
  Position? _currentPosition;

  /// Request and verify location permissions
  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<LatLng?> getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> startTracking() async {
    if (_state == TrackingState.active) return;

    _state = TrackingState.active;
    _stateController.add(_state);

    if (_route.isEmpty) {
      // Fresh start — reset everything
      _totalDistance = 0;
      _totalSeconds = 0;
      _steps = 0;
      _lastPosition = null;
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(_onPosition);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == TrackingState.active) {
        _totalSeconds++;
        if (_currentPosition != null) {
          _emit(_currentPosition!);
        }
      }
    });
  }

  void _onPosition(Position pos) {
    _currentPosition = pos;
    final current = LatLng(pos.latitude, pos.longitude);

    if (_lastPosition != null) {
      final dist = _haversineDistance(_lastPosition!, current);
      // Filter jitter: only count if moved > 2m and accuracy < 30m
      if (dist > 2 && (pos.accuracy < 30 || pos.accuracy == 0)) {
        _totalDistance += dist;
        _steps += _estimateSteps(dist);
        _route.add(current);
        _lastPosition = current;
      }
    } else {
      _route.add(current);
      _lastPosition = current;
    }

    _emit(pos);
  }

  void _emit(Position pos) {
    if (_updateController.isClosed) return;
    _updateController.add(TrackingUpdate(
      position: LatLng(pos.latitude, pos.longitude),
      speedMps: pos.speed < 0 ? 0 : pos.speed,
      totalDistanceMeters: _totalDistance,
      totalSeconds: _totalSeconds,
      steps: _steps,
      heading: pos.heading,
      accuracy: pos.accuracy,
    ));
  }

  void pauseTracking() {
    if (_state != TrackingState.active) return;
    _state = TrackingState.paused;
    _stateController.add(_state);
    _positionSub?.pause();
    _clockTimer?.cancel();
  }

  void resumeTracking() {
    if (_state != TrackingState.paused) return;
    startTracking();
  }

  void stopTracking() {
    _state = TrackingState.stopped;
    _stateController.add(_state);
    _positionSub?.cancel();
    _clockTimer?.cancel();
    _positionSub = null;
    _clockTimer = null;
  }

  void reset() {
    stopTracking();
    _route.clear();
    _totalDistance = 0;
    _totalSeconds = 0;
    _steps = 0;
    _lastPosition = null;
    _currentPosition = null;
    _state = TrackingState.idle;
    _stateController.add(_state);
  }

  double get totalDistance => _totalDistance;
  int get totalSeconds => _totalSeconds;
  int get steps => _steps;

  /// Haversine formula for distance in meters between two points
  static double _haversineDistance(LatLng a, LatLng b) {
    const R = 6371000.0; // Earth radius in meters
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);

    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * R * asin(sqrt(h));
  }

  static double _deg2rad(double deg) => deg * pi / 180;

  /// Rough step estimation: ~1320 steps per km for walking
  static int _estimateSteps(double meters) => (meters * 1.32).round();

  void dispose() {
    _positionSub?.cancel();
    _clockTimer?.cancel();
    _updateController.close();
    _stateController.close();
  }
}