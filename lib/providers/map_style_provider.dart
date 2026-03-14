import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Map Style Model ───────────────────────────────────────────────────────────
class MapStyle {
  final String name;
  final String url;
  final List<String>? subdomains;
  final bool isDark;

  const MapStyle({
    required this.name,
    required this.url,
    this.subdomains,
    this.isDark = false,
  });
}

// ── All Map Styles ────────────────────────────────────────────────────────────
const List<MapStyle> kMapStyles = [
  MapStyle(name: 'OSM Standard',    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
  MapStyle(name: 'OSM Germany',     url: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png'),
  MapStyle(name: 'OSM France',      url: 'https://tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png'),
  MapStyle(name: 'OSM Hot',         url: 'https://tile.openstreetmap.fr/hot/{z}/{x}/{y}.png'),
  MapStyle(name: 'Dark (CartoDB)',  url: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',       subdomains: ['a','b','c','d'], isDark: true),
  MapStyle(name: 'Dark No Labels',  url: 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png', subdomains: ['a','b','c','d'], isDark: true),
  MapStyle(name: 'Light (CartoDB)', url: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',     subdomains: ['a','b','c','d']),
  MapStyle(name: 'Light No Labels', url: 'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png',subdomains: ['a','b','c','d']),
  MapStyle(name: 'Stadia Dark',     url: 'https://tiles.stadiamaps.com/tiles/alidade_dark/{z}/{x}/{y}.png',    isDark: true),
  MapStyle(name: 'Topo Map',        url: 'https://tile.opentopomap.org/{z}/{x}/{y}.png'),
  MapStyle(name: 'Black & White',   url: 'https://tiles.wmflabs.org/bw-mapnik/{z}/{x}/{y}.png',               isDark: true),
  MapStyle(name: 'CyclOSM',         url: 'https://tile.cyclosm.org/{z}/{x}/{y}.png'),
  MapStyle(name: 'Wikimedia',       url: 'https://maps.wikimedia.org/osm-intl/{z}/{x}/{y}.png'),
  MapStyle(name: 'Google Satellite',url: 'https://mt0.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',               isDark: true),
  MapStyle(name: 'Google Hybrid',   url: 'https://mt0.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',               isDark: true),
  MapStyle(name: 'Google Terrain',  url: 'https://mt0.google.com/vt/lyrs=p&x={x}&y={y}&z={z}'),
];

// ── Map Style Provider ────────────────────────────────────────────────────────
final mapStyleProvider = StateProvider<MapStyle>((ref) => kMapStyles[4]); // Default: Dark CartoDB