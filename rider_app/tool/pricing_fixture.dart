// Explicit fixture regeneration tool. Review changes against real PostGIS:
// dart run tool/pricing_fixture.dart, then replace the SQL $fixture$ JSON.
import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/config.dart';
import 'package:rider_app/core/pricing.dart';

void main() {
  const west = LatLng(49.01, 104.04), east = LatLng(49.01, 104.13);
  const center = startCenter, outside = LatLng(49.15, 104.0833);
  final small = FareZone(
    id: '44444444-4444-4444-8444-444444444444',
    town: 'Small',
    kind: ZoneKind.town,
    flatPriceMnt: 3500,
    area: const [
      LatLng(49.005, 104.03),
      LatLng(49.015, 104.03),
      LatLng(49.015, 104.06),
      LatLng(49.005, 104.06),
    ],
  );
  final sets = <String, List<FareZone>>{
    'seed': fareZones,
    'none': [],
    'twoTowns': [
      fareZones.first,
      const FareZone(
        id: '55555555-5555-4555-8555-555555555555',
        town: 'Other',
        kind: ZoneKind.town,
        flatPriceMnt: 4000,
        area: [
          LatLng(49.1, 104),
          LatLng(49.2, 104),
          LatLng(49.2, 104.2),
          LatLng(49.1, 104.2),
        ],
      ),
    ],
    'overlap': [fareZones.first, small],
    'tie': [
      FareZone(
        id: '66666666-6666-4666-8666-666666666666',
        town: 'Tie',
        kind: ZoneKind.town,
        flatPriceMnt: 5000,
        area: small.area,
      ),
      small,
    ],
    'hole': [
      FareZone(
        id: small.id,
        town: small.town,
        kind: ZoneKind.town,
        flatPriceMnt: 3500,
        area: small.area,
        holes: const [
          [
            LatLng(49.009, 104.039),
            LatLng(49.011, 104.039),
            LatLng(49.011, 104.041),
            LatLng(49.009, 104.041),
          ],
        ],
      ),
    ],
  };
  final cases = <Map<String, Object>>[];
  void add(
    String name,
    LatLng p,
    LatLng d, {
    String set = 'seed',
    int base = 1000,
    int min = 1000,
    int max = 2000,
  }) {
    final q = quoteTrip(
      pickup: p,
      dropoff: d,
      zones: sets[set]!,
      tariff: Tariff(baseFareMnt: base, minPerKmMnt: min, maxPerKmMnt: max),
    );
    cases.add({
      'name': name,
      'set': set,
      'p': [p.latitude, p.longitude],
      'd': [d.latitude, d.longitude],
      'tariff': [base, min, max],
      'expected': [
        q.type.name,
        q.distanceM,
        q.minMnt,
        q.maxMnt,
        q.suggestedMnt,
      ],
    });
  }

  add('town flat', west, east);
  add('center dropoff', west, center);
  add('center pickup', center, west);
  add('outside dropoff', west, outside);
  add('outside pickup', outside, west);
  add('zero distance flat', west, west);
  add('zero distance center', center, center);
  final townEdges = [
    const LatLng(49.063, 104.08),
    const LatLng(49.003, 104.08),
    const LatLng(49.01, 104.023),
    const LatLng(49.01, 104.143),
  ];
  final centerEdges = [
    const LatLng(49.038, 104.05),
    const LatLng(49.022, 104.05),
    const LatLng(49.03, 104.042),
    const LatLng(49.03, 104.066),
  ];
  for (var i = 0; i < 4; i++) {
    final t = townEdges[i], c = centerEdges[i];
    add('town edge $i', west, t);
    add('center edge $i', west, c);
    final delta = i < 2 ? const LatLng(0.000001, 0) : const LatLng(0, 0.000001);
    for (final direction in [-1, 1]) {
      add(
        'town edge $i side $direction',
        west,
        LatLng(
          t.latitude + delta.latitude * direction,
          t.longitude + delta.longitude * direction,
        ),
      );
      add(
        'center edge $i side $direction',
        west,
        LatLng(
          c.latitude + delta.latitude * direction,
          c.longitude + delta.longitude * direction,
        ),
      );
    }
  }
  for (final corner in fareZones.first.area) {
    add('town corner ${corner.latitude}/${corner.longitude}', west, corner);
  }
  for (final base in [1049, 1050, 1051]) {
    add('round base $base', center, center, set: 'none', base: base);
  }
  add('different towns', west, outside, set: 'twoTowns');
  add(
    'smallest overlapping zone',
    west,
    const LatLng(49.012, 104.05),
    set: 'overlap',
  );
  add('equal area uses id', west, const LatLng(49.012, 104.05), set: 'tie');
  add('hole interior', west, const LatLng(49.012, 104.05), set: 'hole');
  add(
    'hole boundary covered',
    const LatLng(49.009, 104.04),
    const LatLng(49.012, 104.05),
    set: 'hole',
  );
  add(
    'suggested half up',
    center,
    const LatLng(49.0319, 104.0542),
    set: 'none',
    min: 0,
    max: 500,
  );
  add(
    'submetre below round',
    center,
    const LatLng(49.030903, 104.0542),
    set: 'none',
  );
  add(
    'submetre above round',
    center,
    const LatLng(49.030904, 104.0542),
    set: 'none',
  );
  List<List<double>> ring(List<LatLng> points) =>
      [...points, points.first].map((p) => [p.longitude, p.latitude]).toList();
  Map<String, Object?> zone(FareZone z) => {
    'id': z.id,
    'town': z.town,
    'kind': z.kind.name,
    'flat_price_mnt': z.flatPriceMnt,
    'area': {
      'type': 'Polygon',
      'coordinates': [ring(z.area), ...z.holes.map(ring)],
    },
  };
  stdout.writeln(
    jsonEncode({
      'zoneSets': sets.map(
        (key, zones) => MapEntry(key, zones.map(zone).toList()),
      ),
      'cases': cases,
    }),
  );
}
