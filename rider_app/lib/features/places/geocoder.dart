import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/places.dart';

abstract interface class Geocoder {
  Future<List<Place>> search(String query, {required String language});
}

class GeocodingException implements Exception {
  const GeocodingException();
}

/// DEV ONLY, single developer instance. Never call while typing.
/// https://operations.osmfoundation.org/policies/nominatim/
/// Public Nominatim forbids autocomplete; its 1 req/s cap is application-wide.
/// Production needs a shared proxy/alternative, not per-device rate limiting.
class NominatimGeocoder implements Geocoder {
  NominatimGeocoder({
    required this.client,
    DateTime Function()? now,
    Future<void> Function(Duration)? wait,
  }) : _now = now ?? DateTime.now,
       _wait = wait ?? Future<void>.delayed;

  final http.Client client;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _wait;
  final _cache = <String, List<Place>>{};
  Future<void> _queue = Future.value();
  DateTime? _lastStart;

  @override
  Future<List<Place>> search(String query, {required String language}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return Future.value(const []);
    final key = '$language:$normalized';
    // Serialize even failed requests and concurrent callers. Recheck the cache
    // inside the queue so duplicate submissions only send one request.
    final result = _queue.then((_) async {
      if (_cache.containsKey(key)) return _cache[key]!;
      if (_lastStart != null) {
        final remaining =
            const Duration(seconds: 1) - _now().difference(_lastStart!);
        if (remaining > Duration.zero) await _wait(remaining);
      }
      _lastStart = _now();
      try {
        final response = await client
            .get(
              Uri.https('nominatim.openstreetmap.org', '/search', {
                'q': normalized,
                'format': 'jsonv2',
                'addressdetails': '1',
                'accept-language': language,
                'countrycodes': 'mn',
                'viewbox': '103.95,49.10,104.20,48.95',
                'bounded': '1',
                'limit': '10',
              }),
              // Native requests identify the app. Browsers supply their own UA
              // and Referer; never disable browser privacy/header protections.
              headers: {
                'User-Agent': 'MGLS-Erdenet-Dev/0.1 (local taxi prototype)',
              },
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) throw const GeocodingException();
        final places = parseNominatimResults(jsonDecode(response.body));
        if (_cache.length >= 100) _cache.remove(_cache.keys.first);
        return _cache[key] = List.unmodifiable(places);
      } catch (_) {
        throw const GeocodingException();
      }
    });
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

List<Place> parseNominatimResults(Object? data) {
  if (data is! List) throw const GeocodingException();
  final places = <Place>[];
  final seen = <String>{};
  for (final row in data.whereType<Map<String, dynamic>>()) {
    final lat = double.tryParse('${row['lat']}');
    final lon = double.tryParse('${row['lon']}');
    final display = (row['display_name'] as String? ?? '').split(',');
    final name = (row['name'] as String? ?? display.first).trim();
    final area = display.skip(1).map((p) => p.trim()).join(', ');
    final id = 'osm_${row['osm_type']}_${row['osm_id']}';
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < 48.95 ||
        lat > 49.10 ||
        lon < 103.95 ||
        lon > 104.20 ||
        name.isEmpty ||
        area.isEmpty ||
        row['osm_id'] == null ||
        !seen.add(id)) {
      continue;
    }
    final type = row['type'];
    final kind = switch (type) {
      'hospital' || 'clinic' => PlaceKind.hospital,
      'school' || 'university' || 'college' => PlaceKind.school,
      'marketplace' => PlaceKind.market,
      'supermarket' || 'mall' || 'department_store' => PlaceKind.shopping,
      'bus_station' || 'station' => PlaceKind.transport,
      'townhall' || 'government' => PlaceKind.government,
      _ => PlaceKind.other,
    };
    places.add(
      Place(
        id: id,
        name: name,
        area: area,
        point: LatLng(lat, lon),
        kind: kind,
      ),
    );
  }
  return places;
}
