import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/routing.dart';

void main() {
  test('parses the first OSRM route, flipping lng,lat to lat,lng', () {
    const body = '''
{"code":"Ok","routes":[{"distance":6286.5,"duration":561.5,
 "geometry":{"type":"LineString","coordinates":[[104.04,49.03],[104.07,49.025],[104.10,49.02]]}}]}
''';
    final route = parseOsrmRoute(body)!;
    expect(route.distanceM, 6287);
    expect(route.durationS, 562);
    expect(route.points, hasLength(3));
    expect(route.points.first.latitude, 49.03);
    expect(route.points.first.longitude, 104.04);
  });

  test('returns null when OSRM finds no route', () {
    expect(parseOsrmRoute('{"code":"NoRoute","routes":[]}'), isNull);
  });
}
