import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/config.dart';
import 'package:rider_app/core/pricing.dart';

void main() {
  // Both inside the Erdenet town box, outside the center box.
  const westTown = LatLng(49.0100, 104.0400);
  const eastTown = LatLng(49.0100, 104.1300);
  // Central square, inside the center box.
  const center = LatLng(49.0309, 104.0542);
  // Outside the town box.
  const outside = LatLng(49.1500, 104.0833);

  Quote quote(LatLng a, LatLng b) =>
      quoteTrip(pickup: a, dropoff: b, zones: fareZones, tariff: defaultTariff);

  test('trip inside the town, away from the center, is a flat 3000', () {
    final q = quote(westTown, eastTown);
    expect(q.type, RideType.flat);
    expect(q.suggestedMnt, 3000);
    expect(q.minMnt, 3000);
    expect(q.maxMnt, 3000);
  });

  test('trip touching the center is priced from the tariff range', () {
    final q = quote(westTown, center);
    expect(q.type, RideType.normal);
    expect(q.minMnt, lessThan(q.maxMnt));
    expect(q.suggestedMnt, inInclusiveRange(q.minMnt, q.maxMnt));
  });

  test('trip leaving the town is priced from the tariff range', () {
    final q = quote(westTown, outside);
    expect(q.type, RideType.normal);
    // About 15.5 km straight, 20 km by road: 1000 + 20 * 1000..2000.
    expect(q.minMnt, closeTo(21000, 1500));
    expect(q.maxMnt, closeTo(41000, 3000));
  });

  test('prices are rounded to 100', () {
    final q = quote(westTown, outside);
    expect(q.minMnt % 100, 0);
    expect(q.maxMnt % 100, 0);
    expect(q.suggestedMnt % 100, 0);
  });

  test('pointInPolygon', () {
    final box = fareZones.first.area;
    expect(pointInPolygon(westTown, box), isTrue);
    expect(pointInPolygon(outside, box), isFalse);
  });

  test('points immediately across each town edge switch off the flat fare', () {
    const pairs = [
      [LatLng(49.063 - 0.000001, 104.08), LatLng(49.063 + 0.000001, 104.08)],
      [LatLng(49.003 + 0.000001, 104.08), LatLng(49.003 - 0.000001, 104.08)],
      [LatLng(49.01, 104.023 + 0.000001), LatLng(49.01, 104.023 - 0.000001)],
      [LatLng(49.01, 104.143 - 0.000001), LatLng(49.01, 104.143 + 0.000001)],
    ];
    for (final pair in pairs) {
      expect(quote(westTown, pair.first).isFlat, isTrue);
      expect(quote(westTown, pair.last).isFlat, isFalse);
      expect(quote(pair.last, westTown).isFlat, isFalse);
    }
  });

  test(
    'either endpoint immediately inside any center edge prevents flat fare',
    () {
      const pairs = [
        [LatLng(49.038 - 0.000001, 104.05), LatLng(49.038 + 0.000001, 104.05)],
        [LatLng(49.022 + 0.000001, 104.05), LatLng(49.022 - 0.000001, 104.05)],
        [LatLng(49.03, 104.042 + 0.000001), LatLng(49.03, 104.042 - 0.000001)],
        [LatLng(49.03, 104.066 - 0.000001), LatLng(49.03, 104.066 + 0.000001)],
      ];
      for (final pair in pairs) {
        expect(quote(westTown, pair.first).isFlat, isFalse);
        expect(quote(pair.first, westTown).isFlat, isFalse);
        expect(quote(westTown, pair.last).isFlat, isTrue);
      }
    },
  );

  test(
    'flat fare requires the same town zone, not just any two town zones',
    () {
      final zones = [
        fareZones.first,
        const FareZone(
          town: 'other',
          kind: ZoneKind.town,
          flatPriceMnt: 3000,
          area: [
            LatLng(49.1, 104),
            LatLng(49.2, 104),
            LatLng(49.2, 104.2),
            LatLng(49.1, 104.2),
          ],
        ),
      ];
      expect(
        quoteTrip(
          pickup: westTown,
          dropoff: outside,
          zones: zones,
          tariff: defaultTariff,
        ).isFlat,
        isFalse,
      );
    },
  );

  test('zero-distance tariffs round below, at and above the 50 tugrik tie', () {
    for (final base in [1049, 1050, 1051]) {
      final q = quoteTrip(
        pickup: center,
        dropoff: center,
        zones: const [],
        tariff: Tariff(baseFareMnt: base, minPerKmMnt: 1000, maxPerKmMnt: 2000),
      );
      expect(q.distanceM, 0);
      expect(q.minMnt, base < 1050 ? 1000 : 1100);
      expect(q.maxMnt, q.minMnt);
      expect(q.suggestedMnt, q.minMnt);
    }
  });

  test(
    'distance is multiplied before metre rounding and prices use that metre',
    () {
      final straight = const Distance(roundResult: false)
          .as(LengthUnit.Meter, westTown, outside);
      final distance = (straight * 1.3).round();
      final q = quote(westTown, outside);
      expect(q.distanceM, distance);
      expect(q.minMnt, ((1000 + distance) / 100).round() * 100);
      expect(q.maxMnt, ((1000 + distance * 2) / 100).round() * 100);
      expect(q.suggestedMnt, (((q.minMnt + q.maxMnt) / 2) / 100).round() * 100);
    },
  );
}
