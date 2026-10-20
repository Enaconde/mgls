import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/places.dart';

enum SavedPlaceKind { home, work }

class PlaceReport {
  const PlaceReport({
    required this.place,
    required this.note,
    required this.at,
  });
  final Place place;
  final String note;
  final DateTime at;
}

class PlaceLibrary {
  PlaceLibrary({
    Map<SavedPlaceKind, Place> saved = const {},
    List<Place> recent = const [],
    List<PlaceReport> reports = const [],
  }) : saved = Map.unmodifiable(saved),
       recent = List.unmodifiable(recent),
       reports = List.unmodifiable(reports);

  final Map<SavedPlaceKind, Place> saved;
  final List<Place> recent;
  final List<PlaceReport> reports;

  PlaceLibrary saving(SavedPlaceKind kind, Place place) => PlaceLibrary(
    saved: {...saved, kind: place},
    recent: recent,
    reports: reports,
  );

  PlaceLibrary visiting(Place place) => PlaceLibrary(
    saved: saved,
    recent: [place, ...recent.where((p) => p.id != place.id)].take(10).toList(),
    reports: reports,
  );

  PlaceLibrary reporting(PlaceReport report) =>
      PlaceLibrary(saved: saved, recent: recent, reports: [...reports, report]);
}

abstract interface class PlaceStore {
  Future<PlaceLibrary> load();
  Future<void> save(PlaceLibrary library);
}

/// Device-local only. Reports are intentionally retained for M3 sync; no
/// address, note or saved home/work is sent to the geocoder automatically.
class LocalPlaceStore implements PlaceStore {
  LocalPlaceStore({String? ownerId})
    : _key = ownerId == null ? storageKey : '$storageKey.user.$ownerId';
  static const storageKey = 'mgls.places.v1';
  final String _key;

  @override
  Future<PlaceLibrary> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return PlaceLibrary();
    return decodePlaceLibrary(raw);
  }

  @override
  Future<void> save(PlaceLibrary library) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, encodePlaceLibrary(library))) {
      throw StateError('Could not persist place library');
    }
  }
}

Map<String, Object> placeToJson(Place p) => {
  'id': p.id,
  'name': p.name,
  'area': p.area,
  'lat': p.point.latitude,
  'lon': p.point.longitude,
  'kind': p.kind.name,
};

Place placeFromJson(Object? raw) {
  final p = raw as Map<String, dynamic>;
  final lat = (p['lat'] as num).toDouble();
  final lon = (p['lon'] as num).toDouble();
  final name = p['name'] as String;
  final area = p['area'] as String;
  if (!lat.isFinite ||
      !lon.isFinite ||
      lat.abs() > 90 ||
      lon.abs() > 180 ||
      name.trim().isEmpty ||
      area.trim().isEmpty) {
    throw const FormatException('Invalid stored place');
  }
  return Place(
    id: p['id'] as String,
    name: name,
    area: area,
    point: LatLng(lat, lon),
    kind: PlaceKind.values.byName(p['kind'] as String),
  );
}

String encodePlaceLibrary(PlaceLibrary library) => jsonEncode({
  'saved': {
    for (final e in library.saved.entries) e.key.name: placeToJson(e.value),
  },
  'recent': library.recent.map(placeToJson).toList(),
  'reports': [
    for (final r in library.reports)
      {
        'place': placeToJson(r.place),
        'note': r.note,
        'at': r.at.toIso8601String(),
      },
  ],
});

PlaceLibrary decodePlaceLibrary(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final recent = (json['recent'] as List).map(placeFromJson);
  final ids = <String>{};
  return PlaceLibrary(
    saved: {
      for (final e in (json['saved'] as Map<String, dynamic>).entries)
        SavedPlaceKind.values.byName(e.key): placeFromJson(e.value),
    },
    recent: recent.where((p) => ids.add(p.id)).take(10).toList(),
    reports: [
      for (final r in json['reports'] as List)
        PlaceReport(
          place: placeFromJson(r['place']),
          note: r['note'] as String,
          at: DateTime.parse(r['at'] as String),
        ),
    ],
  );
}

String reportClientId(PlaceReport report) =>
    '${report.at.toUtc().toIso8601String()}:${report.place.id}';
