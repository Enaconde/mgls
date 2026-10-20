import 'package:latlong2/latlong.dart';

/// A fare zone drawn on the map. A trip that starts and ends inside the same
/// town zone, with neither end inside a center zone, pays the flat price.
class FareZone {
  const FareZone({
    this.id = '',
    required this.town,
    required this.kind,
    required this.area,
    this.flatPriceMnt,
    this.holes = const [],
  });

  final String id;
  final String town;
  final ZoneKind kind;
  final List<LatLng> area;
  final int? flatPriceMnt;
  final List<List<LatLng>> holes;
}

enum ZoneKind { town, center }

/// A taxi company's tariff. Riders and drivers may only agree a price
/// between the min and max per km.
class Tariff {
  const Tariff({
    required this.baseFareMnt,
    required this.minPerKmMnt,
    required this.maxPerKmMnt,
  });

  final int baseFareMnt;
  final int minPerKmMnt;
  final int maxPerKmMnt;
}

enum RideType { normal, flat, route }

class Quote {
  const Quote({
    required this.type,
    required this.distanceM,
    required this.suggestedMnt,
    required this.minMnt,
    required this.maxMnt,
  });

  final RideType type;
  final int distanceM;
  final int suggestedMnt;
  final int minMnt;
  final int maxMnt;

  bool get isFlat => type == RideType.flat;
}

/// Straight-line distance times this factor estimates the road distance.
/// The same factor is used by quote_trip() in the database.
const double roadFactor = 1.3;

/// Prices the trip from [pickup] to [dropoff].
Quote quoteTrip({
  required LatLng pickup,
  required LatLng dropoff,
  required List<FareZone> zones,
  required Tariff tariff,
}) {
  // SQL uses the unrounded WGS84 distance too: round only after multiplying.
  final straightM = const Distance(roundResult: false)
      .as(LengthUnit.Meter, pickup, dropoff);
  final roadM = (straightM * roadFactor).round();

  final flatZone = _sharedFlatZone(pickup, dropoff, zones);
  if (flatZone != null) {
    final price = flatZone.flatPriceMnt!;
    return Quote(
      type: RideType.flat,
      distanceM: roadM,
      suggestedMnt: price,
      minMnt: price,
      maxMnt: price,
    );
  }

  final km = roadM / 1000;
  final min = _round100(tariff.baseFareMnt + km * tariff.minPerKmMnt);
  final max = _round100(tariff.baseFareMnt + km * tariff.maxPerKmMnt);
  return Quote(
    type: RideType.normal,
    distanceM: roadM,
    suggestedMnt: _round100((min + max) / 2),
    minMnt: min,
    maxMnt: max,
  );
}

FareZone? _sharedFlatZone(LatLng a, LatLng b, List<FareZone> zones) {
  final inCenter = zones.any(
    (z) => z.kind == ZoneKind.center && (zoneCovers(a, z) || zoneCovers(b, z)),
  );
  if (inCenter) return null;

  // Match SQL ST_Area(geometry), then UUID, for overlapping town zones.
  final ordered = zones.toList()
    ..sort((a, b) {
      final area = zoneArea(a).compareTo(zoneArea(b));
      return area == 0 ? a.id.compareTo(b.id) : area;
    });
  for (final z in ordered) {
    if (z.kind == ZoneKind.town &&
        z.flatPriceMnt != null &&
        zoneCovers(a, z) &&
        zoneCovers(b, z)) {
      return z;
    }
  }
  return null;
}

int _round100(num value) => (value / 100).round() * 100;

/// Polygon edges and vertices count as inside, matching ST_Covers(geometry).
bool pointInPolygon(LatLng p, List<LatLng> ring) {
  if (ring.length < 3) return false;
  if (_onBoundary(p, ring)) return true;
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final xi = ring[i].longitude, yi = ring[i].latitude;
    final xj = ring[j].longitude, yj = ring[j].latitude;
    final crosses =
        (yi > p.latitude) != (yj > p.latitude) &&
        p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi;
    if (crosses) inside = !inside;
  }
  return inside;
}

bool _onBoundary(LatLng p, List<LatLng> ring) {
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[j], b = ring[i];
    final cross =
        (p.longitude - a.longitude) * (b.latitude - a.latitude) -
        (p.latitude - a.latitude) * (b.longitude - a.longitude);
    if (cross.abs() <= 1e-14 &&
        p.latitude >= (a.latitude < b.latitude ? a.latitude : b.latitude) &&
        p.latitude <= (a.latitude > b.latitude ? a.latitude : b.latitude) &&
        p.longitude >=
            (a.longitude < b.longitude ? a.longitude : b.longitude) &&
        p.longitude <=
            (a.longitude > b.longitude ? a.longitude : b.longitude)) {
      return true;
    }
  }
  return false;
}

bool zoneCovers(LatLng point, FareZone zone) =>
    pointInPolygon(point, zone.area) &&
    !zone.holes.any(
      (ring) => pointInPolygon(point, ring) && !_onBoundary(point, ring),
    );

double _ringArea(List<LatLng> ring) {
  var sum = 0.0;
  if (ring.length < 3) return 0;
  // Translate to reduce cancellation on small polygons around longitude 104.
  final origin = ring.first;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    sum +=
        (ring[j].longitude - origin.longitude) *
            (ring[i].latitude - origin.latitude) -
        (ring[i].longitude - origin.longitude) *
            (ring[j].latitude - origin.latitude);
  }
  return sum.abs() / 2;
}

double zoneArea(FareZone zone) =>
    _ringArea(zone.area) -
    zone.holes.fold<double>(0, (sum, ring) => sum + _ringArea(ring));
