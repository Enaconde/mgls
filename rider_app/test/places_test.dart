import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/places.dart';
import 'package:rider_app/l10n/app_localizations_en.dart';

void main() {
  test('empty query returns all popular places in their original order', () {
    expect(searchPlaces(''), orderedEquals(erdenetPopularPlaces));
    expect(searchPlaces('   '), orderedEquals(erdenetPopularPlaces));
    expect(erdenetPopularPlaces.length, greaterThanOrEqualTo(16));
  });

  test('search is case-insensitive for Cyrillic names and areas', () {
    expect(searchPlaces('цАГААН өРГӨӨ').map((place) => place.id), [
      'tsagaan_urguu_market',
    ]);
    expect(searchPlaces('кУВЕЙТИЙН').map((place) => place.id), [
      'tsagaan_urguu_market',
      'erdenet_department_store',
    ]);
  });

  test('name prefix matches precede name substrings and area matches', () {
    const places = [
      Place(
        id: 'substring',
        name: 'Төв зах',
        area: 'Төв',
        point: LatLng(49.03, 104.05),
        kind: PlaceKind.market,
      ),
      Place(
        id: 'area',
        name: 'Дэлгүүр',
        area: 'Захын дэргэд',
        point: LatLng(49.03, 104.05),
        kind: PlaceKind.shopping,
      ),
      Place(
        id: 'prefix',
        name: 'Зах нэг',
        area: 'Төв',
        point: LatLng(49.03, 104.05),
        kind: PlaceKind.market,
      ),
      Place(
        id: 'second_prefix',
        name: 'Зах хоёр',
        area: 'Төв',
        point: LatLng(49.03, 104.05),
        kind: PlaceKind.market,
      ),
    ];

    expect(searchPlaces(' ЗАХ ', places: places).map((place) => place.id), [
      'prefix',
      'second_prefix',
      'substring',
      'area',
    ]);
    expect(searchPlaces('', places: places), orderedEquals(places));
    expect(places.first.id, 'substring');
  });

  test('unmatched query and an empty supplied list return no places', () {
    expect(searchPlaces('Олдохгүй газар'), isEmpty);
    expect(searchPlaces('зах', places: const []), isEmpty);
  });

  test('every place lies within the Erdenet bounding box', () {
    for (final place in erdenetPopularPlaces) {
      expect(
        place.point.latitude,
        inInclusiveRange(48.95, 49.10),
        reason: '${place.id} latitude',
      );
      expect(
        place.point.longitude,
        inInclusiveRange(103.95, 104.20),
        reason: '${place.id} longitude',
      );
    }
  });

  test('place ids are unique', () {
    final ids = erdenetPopularPlaces.map((place) => place.id);
    expect(ids.toSet(), hasLength(erdenetPopularPlaces.length));
  });

  test(
    'English catalog preserves IDs, coordinates and kinds and can be searched',
    () {
      final english = popularPlaces(AppLocalizationsEn());
      expect(
        english.map((place) => place.id),
        orderedEquals(erdenetPopularPlaces.map((place) => place.id)),
      );
      for (var i = 0; i < english.length; i++) {
        expect(english[i].point, erdenetPopularPlaces[i].point);
        expect(english[i].kind, erdenetPopularPlaces[i].kind);
        expect(english[i].area, isNotEmpty);
      }
      expect(searchPlaces('DUMUG', places: english).single.id, 'dumug_market');
    },
  );
}
