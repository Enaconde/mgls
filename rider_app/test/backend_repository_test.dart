import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/config.dart';
import 'package:rider_app/core/places.dart';
import 'package:rider_app/core/pricing.dart';
import 'package:rider_app/data/backend.dart';
import 'package:rider_app/data/backend_codecs.dart';
import 'package:rider_app/data/backend_config.dart';
import 'package:rider_app/data/memory_repositories.dart';
import 'package:rider_app/data/repositories.dart';
import 'package:rider_app/data/supabase_repositories.dart';
import 'package:rider_app/features/places/place_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String fakeJwt(String role, {String? userId}) {
  String encode(Object data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'role': role, 'sub': userId, 'exp': DateTime.utc(2100).millisecondsSinceEpoch ~/ 1000})}.test-signature';
}

Map<String, dynamic> fixtureCatalog() {
  final sql = File('../supabase/tests/pricing_parity.sql').readAsStringSync();
  final fixture = jsonDecode(sql.split(r'$fixture$')[1]);
  return {
    'zones': fixture['zoneSets']['seed'],
    'companies': [
      {
        'id': demoCompanyId,
        'name': 'Fixture taxi',
        'base_fare_mnt': 1000,
        'min_per_km_mnt': 1000,
        'max_per_km_mnt': 2000,
      },
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'configuration is demo only with both values absent; invalid is closed',
    () async {
      const empty = BackendConfig(url: '', anonKey: '');
      expect(empty.mode, BackendMode.demo);
      expect((await initializeBackend(empty)).mode, BackendMode.demo);
      for (final config in [
        const BackendConfig(url: 'https://mgls.example.test', anonKey: ''),
        const BackendConfig(url: '', anonKey: 'bad'),
        const BackendConfig(
          url: 'http://remote.example.test',
          anonKey: 'sb_publishable_test_only_key',
        ),
        const BackendConfig(
          url: 'https://person:password@mgls.example.test',
          anonKey: 'sb_publishable_test_only_key',
        ),
        BackendConfig(
          url: 'https://mgls.example.test',
          anonKey: fakeJwt('service_role'),
        ),
        const BackendConfig(
          url: 'https://mgls.example.test',
          anonKey: 'sb_secret_test_only_key',
        ),
      ]) {
        expect(config.mode, BackendMode.unavailable);
        final backend = await initializeBackend(config);
        expect(backend.mode, BackendMode.unavailable);
        await expectLater(
          backend.zones.load(),
          throwsA(isA<BackendUnavailable>()),
        );
      }
      expect(
        BackendConfig(
          url: 'https://mgls.example.test',
          anonKey: fakeJwt('anon'),
        ).mode,
        BackendMode.supabase,
      );
      expect(
        const BackendConfig(
          url: 'http://127.0.0.1:54321',
          anonKey: 'sb_publishable_test_only_key',
        ).mode,
        BackendMode.supabase,
      );
    },
  );

  test(
    'catalog codec preserves database coordinates, holes and tariff fields',
    () {
      final catalog = parseFareCatalog(fixtureCatalog());
      expect(catalog.zones.first.area.first, const LatLng(49.063, 104.023));
      expect(catalog.zones.first.id, fareZones.first.id);
      expect(catalog.companies.single.tariff.maxPerKmMnt, 2000);
      expect(() => catalog.zones.clear(), throwsUnsupportedError);
      expect(() => catalog.zones.first.area.clear(), throwsUnsupportedError);
      final sql = File('../supabase/tests/pricing_parity.sql')
          .readAsStringSync();
      final data = jsonDecode(sql.split(r'$fixture$')[1]);
      final holes = parseFareCatalog({
        ...fixtureCatalog(),
        'zones': data['zoneSets']['hole'],
      });
      expect(holes.zones.single.holes, hasLength(1));
      expect(zoneArea(holes.zones.single), greaterThan(0));
    },
  );

  test(
    'catalog codec rejects missing labels, invalid polygon or reversed tariff',
    () {
      final reversed = fixtureCatalog();
      reversed['companies'][0]['min_per_km_mnt'] = 3000;
      final blank = fixtureCatalog();
      blank['companies'][0]['name'] = ' ';
      final geometry = fixtureCatalog();
      geometry['zones'][0]['area']['type'] = 'LineString';
      final badPoint = fixtureCatalog();
      badPoint['zones'][0]['area']['coordinates'][0][0][1] = 999;
      final open = fixtureCatalog();
      open['zones'][0]['area']['coordinates'][0].removeLast();
      final duplicate = fixtureCatalog();
      duplicate['companies'].add(duplicate['companies'].first);
      for (final data in [
        reversed,
        blank,
        geometry,
        badPoint,
        open,
        duplicate,
      ]) {
        expect(() => parseFareCatalog(data), throwsA(isA<FormatException>()));
      }
    },
  );

  test('server quote codec uses server values and rejects missing or unsafe bounds', () {
    final row = {
      'ride_type': 'normal',
      'distance_m': 7777,
      'min_price_mnt': 12000,
      'max_price_mnt': 18000,
      'suggested_price_mnt': 15000,
    };
    final quote = parseServerQuote([row]);
    expect(quote.distanceM, 7777);
    expect(quote.suggestedMnt, 15000);
    for (final data in [
      [],
      [row, row],
      [
        {...row, 'suggested_price_mnt': 999999},
      ],
      [
        {...row, 'ride_type': 'route'},
      ],
      [
        {...row, 'ride_type': 'flat'},
      ],
      [
        {...row, 'distance_m': -1},
      ],
      [
        {...row, 'min_price_mnt': 12.5},
      ],
    ]) {
      expect(() => parseServerQuote(data), throwsA(isA<FormatException>()));
    }
  });

  test('Supabase catalog and quote traverse real SDK HTTP and never calculate local fares', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://mgls.example.test',
      'sb_publishable_test_only_key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/fare_catalog')) {
          return http.Response(
            jsonEncode(fixtureCatalog()),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'ride_type': 'normal',
              'distance_m': 7777,
              'min_price_mnt': 12000,
              'max_price_mnt': 18000,
              'suggested_price_mnt': 15000,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final backend = Backend.live(client);
    expect(backend.mode, BackendMode.supabase);
    expect((await backend.zones.load()).companies.single.id, demoCompanyId);
    final quote = await backend.rides.quote(
      pickup: startCenter,
      dropoff: const LatLng(49.01, 104.13),
      companyId: demoCompanyId,
    );
    expect(quote.suggestedMnt, 15000);
    expect(requests.map((r) => r.url.path), [
      '/rest/v1/rpc/fare_catalog',
      '/rest/v1/rpc/fare_quote',
    ]);
    expect(jsonDecode(requests.last.body), {
      'p_lat': startCenter.latitude,
      'p_lng': startCenter.longitude,
      'd_lat': 49.01,
      'd_lng': 104.13,
      'p_company': demoCompanyId,
    });
    expect(requests.first.headers['apikey'], 'sb_publishable_test_only_key');
  });

  test('Supabase errors propagate; there is no demo-price fallback', () async {
    final client = SupabaseClient(
      'https://mgls.example.test',
      'sb_publishable_test_only_key',
      httpClient: MockClient(
        (request) async => http.Response(
          '{"message":"offline"}',
          503,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseZoneRepository(client).load(),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      SupabaseRideRepository(client).quote(
        pickup: startCenter,
        dropoff: startCenter,
        companyId: demoCompanyId,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'demo repositories use injected company tariff; unknown companies fail',
    () async {
      final zones = MemoryZoneRepository(
        FareCatalog(
          zones: [],
          companies: [
            const CompanyTariff(
              id: 'custom',
              name: 'Fixture',
              tariff: Tariff(baseFareMnt: 4200, minPerKmMnt: 0, maxPerKmMnt: 0),
            ),
          ],
        ),
      );
      final rides = MemoryRideRepository(zones);
      expect(
        (await rides.quote(
          pickup: startCenter,
          dropoff: startCenter,
          companyId: 'custom',
        )).suggestedMnt,
        4200,
      );
      await expectLater(
        rides.quote(
          pickup: startCenter,
          dropoff: startCenter,
          companyId: 'missing',
        ),
        throwsA(isA<BackendUnavailable>()),
      );
      final places = MemoryPlaceRepository(userId: 'rider');
      await places.savePlace('rider', SavedPlaceKind.home, fixturePlace());
      expect(
        (await places.savedPlaces('rider'))[SavedPlaceKind.home]!.id,
        'fixture',
      );
      await expectLater(
        places.savedPlaces('other'),
        throwsA(isA<BackendUnavailable>()),
      );
    },
  );

  test(
    'unsigned place operations do not send HTTP or create an auth session',
    () async {
      var requests = 0;
      final client = SupabaseClient(
        'https://mgls.example.test',
        'sb_publishable_test_only_key',
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('[]', 200);
        }),
      );
      addTearDown(client.dispose);
      final repo = SupabasePlaceRepository(client);
      expect(repo.userId, isNull);
      await expectLater(
        repo.savedPlaces('other'),
        throwsA(isA<BackendUnavailable>()),
      );
      expect(requests, 0);
      expect(client.auth.currentSession, isNull);
    },
  );

  test('signed-in saved places and retryable reports use owner filters and idempotency', () async {
    const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    final writes = <http.Request>[];
    final client = SupabaseClient(
      'https://mgls.example.test',
      'sb_publishable_test_only_key',
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode({
              'access_token': fakeJwt('authenticated', userId: owner),
              'refresh_token': 'test-only-refresh',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': {
                'id': owner,
                'aud': 'authenticated',
                'email': 'rider@example.test',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-10-20T00:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        writes.add(request);
        return http.Response(
          request.method == 'GET'
              ? jsonEncode([
                  {'kind': 'home', 'place': placeToJson(fixturePlace())},
                ])
              : '',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    // This is a mocked Auth response; no external account or request exists.
    await client.auth.signInWithPassword(
      email: 'rider@example.test',
      password: 'test-only-password',
    );
    final repo = SupabasePlaceRepository(client);
    expect(
      (await repo.savedPlaces(owner))[SavedPlaceKind.home]!.area,
      'Erdenet',
    );
    expect(writes.single.url.queryParameters['owner_id'], 'eq.$owner');
    await repo.savePlace(owner, SavedPlaceKind.work, fixturePlace());
    final report = PlaceReport(
      place: fixturePlace(),
      note: 'Wrong entrance',
      at: DateTime.utc(2026, 10, 20),
    );
    await repo.report(owner, report);
    await repo.report(owner, report);
    expect(jsonDecode(writes.last.body)['client_id'], reportClientId(report));
    expect(writes.last.headers['Prefer'], contains('ignore-duplicates'));
    expect(jsonDecode(writes.last.body)['owner_id'], owner);
    expect(
      jsonDecode(writes.last.body)['client_id'],
      jsonDecode(writes[writes.length - 2].body)['client_id'],
    );
    await expectLater(
      repo.savedPlaces('another'),
      throwsA(isA<BackendUnavailable>()),
    );
  });
}

// External place data, rather than fixed application copy.
Place fixturePlace() => placeFromJson({
  'id': 'fixture',
  'name': 'Fixture school',
  'area': 'Erdenet',
  'lat': 49.03,
  'lon': 104.05,
  'kind': 'school',
});
