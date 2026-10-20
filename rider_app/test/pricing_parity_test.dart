import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/pricing.dart';
import 'package:rider_app/data/backend_codecs.dart';

void main() {
  final sql = File('../supabase/tests/pricing_parity.sql').readAsStringSync();
  final payload = sql.split(r'$fixture$')[1];
  final fixture = jsonDecode(payload) as Map<String, dynamic>;
  final cases = fixture['cases'] as List;
  test('shared SQL pricing fixture has the reviewed 46 cases', () {
    expect(cases, hasLength(46));
  });
  for (final c in cases) {
    test('SQL/Dart pricing fixture: ${c['name']}', () {
      final tariff = (c['tariff'] as List).cast<int>();
      final catalog = parseFareCatalog({
        'zones': fixture['zoneSets'][c['set']],
        'companies': [
          {
            'id': 'fixture',
            'name': 'Fixture',
            'base_fare_mnt': tariff[0],
            'min_per_km_mnt': tariff[1],
            'max_per_km_mnt': tariff[2],
          },
        ],
      });
      final p = c['p'] as List, d = c['d'] as List;
      final quote = quoteTrip(
        pickup: LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        dropoff: LatLng((d[0] as num).toDouble(), (d[1] as num).toDouble()),
        zones: catalog.zones,
        tariff: catalog.companies.single.tariff,
      );
      expect([
        quote.type.name,
        quote.distanceM,
        quote.minMnt,
        quote.maxMnt,
        quote.suggestedMnt,
      ], c['expected']);
    });
  }
}
