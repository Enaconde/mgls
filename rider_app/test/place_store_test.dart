import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/places.dart';
import 'package:rider_app/features/places/place_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('recent places keep last ten unique selections, most recent first', () {
    var library = PlaceLibrary();
    for (final p in erdenetPopularPlaces) {
      library = library.visiting(p);
    }
    expect(library.recent, hasLength(10));
    expect(library.recent.first, erdenetPopularPlaces.last);
    final selected = library.recent[5];
    library = library.visiting(selected);
    expect(library.recent.first, selected);
    expect(library.recent.where((p) => p.id == selected.id), hasLength(1));
    expect(() => library.recent.clear(), throwsUnsupportedError);
  });

  test(
    'Home, Work, recents, reports and coordinates survive a store reload',
    () async {
      final home = erdenetPopularPlaces.first;
      final work = erdenetPopularPlaces.last;
      final at = DateTime.utc(2026, 10, 20);
      final library = PlaceLibrary()
          .saving(SavedPlaceKind.home, home)
          .saving(SavedPlaceKind.work, work)
          .visiting(work)
          .reporting(PlaceReport(place: home, note: 'Wrong entrance', at: at));
      await LocalPlaceStore().save(library);
      final restored = await LocalPlaceStore().load();
      expect(restored.saved[SavedPlaceKind.home]!.point, home.point);
      expect(restored.saved[SavedPlaceKind.work]!.name, work.name);
      expect(restored.recent.single.id, work.id);
      expect(restored.reports.single.place.area, home.area);
      expect(restored.reports.single.note, 'Wrong entrance');
      expect(restored.reports.single.at, at);
      final changed = restored.saving(SavedPlaceKind.home, work);
      expect(restored.saved[SavedPlaceKind.home]!.id, home.id);
      expect(changed.saved[SavedPlaceKind.home]!.id, work.id);
    },
  );

  test(
    'empty store loads; corrupt data fails visibly without overwriting',
    () async {
      expect((await LocalPlaceStore().load()).recent, isEmpty);
      SharedPreferences.setMockInitialValues({
        LocalPlaceStore.storageKey: '{broken',
      });
      await expectLater(LocalPlaceStore().load(), throwsFormatException);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocalPlaceStore.storageKey), '{broken');
    },
  );

  test('codec rejects invalid stored coordinates and blank result labels', () {
    final raw = encodePlaceLibrary(
      PlaceLibrary().visiting(erdenetPopularPlaces.first),
    );
    expect(
      () => decodePlaceLibrary(raw.replaceFirst('49.02537', '999')),
      throwsFormatException,
    );
    expect(() => decodePlaceLibrary('{}'), throwsA(isA<TypeError>()));
  });
}
