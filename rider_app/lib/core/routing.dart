import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A driving route that follows the roads.
class RoadRoute {
  const RoadRoute({
    required this.points,
    required this.distanceM,
    required this.durationS,
  });

  final List<LatLng> points;
  final int distanceM;
  final int durationS;
}

/// DEV ONLY: the public OSRM demo server, which allows light testing only.
/// Before launch, run our own OSRM server or use a paid routing API.
const String _osrmBase = 'https://router.project-osrm.org';

/// Asks OSRM for the road route from [from] to [to]. Returns null when the
/// server can't be reached or finds no route, so callers can fall back to a
/// straight line.
Future<RoadRoute?> fetchRoadRoute(
  LatLng from,
  LatLng to, {
  http.Client? client,
}) async {
  // OSRM takes longitude before latitude.
  final uri = Uri.parse(
    '$_osrmBase/route/v1/driving/'
    '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
    '?overview=full&geometries=geojson',
  );
  try {
    final res = await (client ?? http.Client())
        .get(uri)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    return parseOsrmRoute(res.body);
  } catch (_) {
    return null;
  }
}

/// Reads the first route out of an OSRM `route` response body.
RoadRoute? parseOsrmRoute(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final routes = json['routes'] as List<dynamic>?;
  if (json['code'] != 'Ok' || routes == null || routes.isEmpty) return null;

  final route = routes.first as Map<String, dynamic>;
  final coords =
      (route['geometry'] as Map<String, dynamic>)['coordinates'] as List;
  return RoadRoute(
    points: [
      for (final c in coords)
        LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ],
    distanceM: (route['distance'] as num).round(),
    durationS: (route['duration'] as num).round(),
  );
}
