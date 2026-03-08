import 'dart:convert';
import 'package:latlong2/latlong.dart';

class ActivityModel {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final List<LatLng> route;
  final double distanceMeters;
  final int durationSeconds;
  final int steps;
  final List<double> elevations;
  final String type; // 'walking', 'running'

  ActivityModel({
    required this.id,
    required this.name,
    required this.startTime,
    this.endTime,
    required this.route,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    this.elevations = const [],
    this.type = 'walking',
  });

  double get distanceKm => distanceMeters / 1000;
  double get distanceMiles => distanceMeters * 0.000621371;

  /// Pace in minutes per km
  double get paceMinPerKm {
    if (distanceKm <= 0) return 0;
    return (durationSeconds / 60) / distanceKm;
  }

  String get paceString {
    if (paceMinPerKm <= 0 || paceMinPerKm.isInfinite || paceMinPerKm.isNaN) {
      return '--:--';
    }
    final mins = paceMinPerKm.floor();
    final secs = ((paceMinPerKm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String get durationString {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'route': route.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
    'steps': steps,
    'elevations': elevations,
    'type': type,
  };

  factory ActivityModel.fromJson(Map<String, dynamic> json) => ActivityModel(
    id: json['id'],
    name: json['name'],
    startTime: DateTime.parse(json['startTime']),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    route: (json['route'] as List)
        .map((p) => LatLng(p['lat'], p['lng']))
        .toList(),
    distanceMeters: (json['distanceMeters'] as num).toDouble(),
    durationSeconds: json['durationSeconds'],
    steps: json['steps'],
    elevations: (json['elevations'] as List?)
        ?.map((e) => (e as num).toDouble())
        .toList() ??
        [],
    type: json['type'] ?? 'walking',
  );

  String toJsonString() => jsonEncode(toJson());

  factory ActivityModel.fromJsonString(String s) =>
      ActivityModel.fromJson(jsonDecode(s));
}