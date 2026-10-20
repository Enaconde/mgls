import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rider_app/core/places.dart';
import 'package:rider_app/features/places/geocoder.dart';

Map<String, Object> result({int id = 1}) => {
  'osm_type': 'node',
  'osm_id': id,
  'lat': '49.03',
  'lon': '104.05',
  'name': 'School',
  'display_name': 'School, Erdenet, Bayan-Undur',
  'type': 'school',
};

void main() {
  test(
    'concurrent requests start at least one second apart, including failures',
    () async {
      var now = DateTime.utc(2026, 10, 20);
      final starts = <DateTime>[];
      final geocoder = NominatimGeocoder(
        client: MockClient((request) async {
          starts.add(now);
          expect(request.headers['User-Agent'], contains('MGLS'));
          expect(request.url.queryParameters['bounded'], '1');
          expect(request.url.queryParameters['accept-language'], 'mn');
          if (request.url.queryParameters['q'] == 'fail') {
            return http.Response('', 429);
          }
          return http.Response(jsonEncode([result()]), 200);
        }),
        now: () => now,
        wait: (duration) async {
          now = now.add(duration);
        },
      );
      final fail = expectLater(
        geocoder.search('fail', language: 'mn'),
        throwsA(isA<GeocodingException>()),
      );
      final a = geocoder.search('school', language: 'mn');
      final b = geocoder.search('market', language: 'mn');
      await Future.wait([fail, a, b]);
      expect(starts, hasLength(3));
      for (var i = 1; i < starts.length; i++) {
        expect(
          starts[i].difference(starts[i - 1]),
          greaterThanOrEqualTo(const Duration(seconds: 1)),
        );
      }
    },
  );

  test('normalized concurrent and repeated searches use cache; locale has its own key', () async {
    var calls = 0;
    final geocoder = NominatimGeocoder(
      client: MockClient((_) async {
        calls++;
        return http.Response(jsonEncode([result()]), 200);
      }),
      wait: (_) async {},
    );
    await Future.wait([
      geocoder.search(' SCHOOL ', language: 'mn'),
      geocoder.search('school', language: 'mn'),
    ]);
    await geocoder.search('school', language: 'mn');
    expect(calls, 1);
    await geocoder.search('school', language: 'en');
    expect(calls, 2);
    expect(await geocoder.search(' ', language: 'mn'), isEmpty);
    expect(await geocoder.search('s', language: 'mn'), isEmpty);
    expect(calls, 2);
  });

  test(
    'network failures and malformed responses are retryable, never cached',
    () async {
      var calls = 0;
      final geocoder = NominatimGeocoder(
        client: MockClient((_) async {
          calls++;
          if (calls == 1) throw http.ClientException('offline');
          if (calls == 2) return http.Response('{}', 200);
          return http.Response('[]', 200);
        }),
        wait: (_) async {},
      );
      for (var i = 0; i < 2; i++) {
        await expectLater(
          geocoder.search('school', language: 'mn'),
          throwsA(isA<GeocodingException>()),
        );
      }
      expect(await geocoder.search('school', language: 'mn'), isEmpty);
      expect(await geocoder.search('school', language: 'mn'), isEmpty);
      expect(calls, 3);
    },
  );

  test(
    'parser requires name and area, rejects bad coordinates and deduplicates',
    () {
      final places = parseNominatimResults([
        result(),
        result(),
        {...result(id: 2), 'lat': 'NaN'},
        {...result(id: 3), 'lon': '106.9'},
        {...result(id: 4), 'display_name': 'School'},
        {...result(id: 5), 'name': ''},
        {...result(id: 6), 'lat': 'not a number'},
      ]);
      expect(places, hasLength(1));
      expect(places.single.name, 'School');
      expect(places.single.area, 'Erdenet, Bayan-Undur');
      expect(places.single.kind, PlaceKind.school);
      expect(
        () => parseNominatimResults(null),
        throwsA(isA<GeocodingException>()),
      );
    },
  );

  test('parser maps supported place kinds and uses display name fallback', () {
    final types = [
      'hospital',
      'marketplace',
      'supermarket',
      'station',
      'townhall',
      'unknown',
    ];
    final places = parseNominatimResults([
      for (var i = 0; i < types.length; i++)
        {...result(id: i), 'name': null, 'type': types[i]},
    ]);
    expect(places.map((p) => p.kind), [
      PlaceKind.hospital,
      PlaceKind.market,
      PlaceKind.shopping,
      PlaceKind.transport,
      PlaceKind.government,
      PlaceKind.other,
    ]);
    expect(places.every((p) => p.name.isNotEmpty && p.area.isNotEmpty), isTrue);
  });
}
