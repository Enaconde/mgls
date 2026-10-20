import 'package:latlong2/latlong.dart';

import '../core/pricing.dart';
import 'repositories.dart';

int _money(Object? value) {
  if (value is! int || value < 0 || value > 2147483647) {
    throw const FormatException('Invalid integer amount');
  }
  return value;
}

String _label(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Missing label or identifier');
  }
  return value;
}

List<LatLng> _ring(Object? value) {
  final coordinates = value as List;
  if (coordinates.length < 4) throw const FormatException('Invalid polygon');
  final points = coordinates.map((raw) {
    final pair = raw as List;
    final lon = (pair[0] as num).toDouble();
    final lat = (pair[1] as num).toDouble();
    if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
      throw const FormatException('Invalid coordinate');
    }
    return LatLng(lat, lon);
  }).toList();
  if (points.first != points.last) throw const FormatException('Open polygon');
  return List.unmodifiable(points.take(points.length - 1));
}

FareCatalog parseFareCatalog(Object? raw) {
  final data = raw as Map<String, dynamic>;
  final zoneIds = <String>{};
  final companyIds = <String>{};
  return FareCatalog(
    zones: [
      for (final z in data['zones'] as List)
        (() {
          final id = _label(z['id']);
          if (!zoneIds.add(id)) throw const FormatException('Duplicate zone');
          final polygon = z['area'] as Map<String, dynamic>;
          if (polygon['type'] != 'Polygon') {
            throw const FormatException('Invalid geometry type');
          }
          final rings = polygon['coordinates'] as List;
          if (rings.isEmpty) throw const FormatException('Empty polygon');
          final kind = ZoneKind.values.byName(z['kind'] as String);
          final flat = z['flat_price_mnt'] == null
              ? null
              : _money(z['flat_price_mnt']);
          if (kind == ZoneKind.center && flat != null) {
            throw const FormatException('Invalid center fare');
          }
          return FareZone(
            id: id,
            town: _label(z['town']),
            kind: kind,
            area: _ring(rings.first),
            holes: List.unmodifiable(rings.skip(1).map(_ring)),
            flatPriceMnt: flat,
          );
        })(),
    ],
    companies: [
      for (final c in data['companies'] as List)
        (() {
          final id = _label(c['id']);
          if (!companyIds.add(id)) {
            throw const FormatException('Duplicate company');
          }
          final min = _money(c['min_per_km_mnt']);
          final max = _money(c['max_per_km_mnt']);
          if (min > max) throw const FormatException('Invalid tariff range');
          return CompanyTariff(
            id: id,
            name: _label(c['name']),
            tariff: Tariff(
              baseFareMnt: _money(c['base_fare_mnt']),
              minPerKmMnt: min,
              maxPerKmMnt: max,
            ),
          );
        })(),
    ],
  );
}

Quote parseServerQuote(Object? raw) {
  final rows = raw as List;
  if (rows.length != 1) throw const FormatException('Expected one quote');
  final row = rows.single as Map<String, dynamic>;
  final type = RideType.values.byName(row['ride_type'] as String);
  final min = _money(row['min_price_mnt']);
  final max = _money(row['max_price_mnt']);
  final suggested = _money(row['suggested_price_mnt']);
  if (type == RideType.route ||
      min > max ||
      suggested < min ||
      suggested > max ||
      (type == RideType.flat && (min != max || suggested != min))) {
    throw const FormatException('Invalid server quote');
  }
  return Quote(
    type: type,
    distanceM: _money(row['distance_m']),
    minMnt: min,
    maxMnt: max,
    suggestedMnt: suggested,
  );
}
