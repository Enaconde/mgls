import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/config.dart';
import 'package:rider_app/core/places.dart';
import 'package:rider_app/core/pricing.dart';
import 'package:rider_app/data/backend.dart';
import 'package:rider_app/data/backend_config.dart';
import 'package:rider_app/data/memory_repositories.dart';
import 'package:rider_app/data/repositories.dart';
import 'package:rider_app/features/booking/booking_controller.dart';
import 'package:rider_app/features/booking/booking_provider.dart';
import 'package:rider_app/features/places/place_store.dart';
import 'package:rider_app/features/places/syncing_place_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ControlledRides implements RideRepository {
  final pending = <Completer<Quote>>[];
  @override
  Future<Quote> quote({
    required LatLng pickup,
    required LatLng dropoff,
    required String companyId,
  }) {
    final request = Completer<Quote>();
    pending.add(request);
    return request.future;
  }
}

class MutablePlaces extends MemoryPlaceRepository {
  String? currentUser = 'rider';
  bool fail = false;
  @override
  String? get userId => currentUser;
  @override
  Future<Map<SavedPlaceKind, Place>> savedPlaces(String ownerId) async {
    if (fail) throw const BackendUnavailable();
    return super.savedPlaces(ownerId);
  }

  @override
  Future<void> savePlace(
    String ownerId,
    SavedPlaceKind kind,
    Place place,
  ) async {
    if (fail) throw const BackendUnavailable();
    await super.savePlace(ownerId, kind, place);
  }

  @override
  Future<void> report(String ownerId, PlaceReport report) async {
    if (fail) throw const BackendUnavailable();
    await super.report(ownerId, report);
  }
}

const serverQuote = Quote(
  type: RideType.normal,
  distanceM: 9000,
  minMnt: 12000,
  maxMnt: 18000,
  suggestedMnt: 15000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('asynchronous controller blocks offers/requests before a quote and accepts current bounds', () {
    final controller = BookingController()
      ..confirmPoint(startCenter)
      ..confirmPoint(startCenter);
    expect(controller.state.quoting, isTrue);
    expect(controller.request().stage, BookingStage.review);
    expect(controller.setOffer(999999).offerMnt, isNull);
    final revision = controller.revision;
    controller.failQuote(revision);
    expect(controller.state.quoteFailed, isTrue);
    controller.startQuote(companyId: demoCompanyId);
    controller.applyQuote(serverQuote, revision, demoCompanyId);
    expect(controller.state.quote, isNull);
    controller.applyQuote(serverQuote, controller.revision, demoCompanyId);
    expect(controller.state.quoting, isFalse);
    expect(controller.state.quoteFailed, isFalse);
    expect(controller.setOffer(999999).offerMnt, 18000);
    expect(controller.request().stage, BookingStage.requested);
  });

  test(
    'late server quote cannot attach after restart and repeated endpoints',
    () async {
      final rides = ControlledRides();
      final backend = Backend(
        mode: BackendMode.supabase,
        zones: MemoryZoneRepository(),
        rides: rides,
        places: MemoryPlaceRepository(),
      );
      final container = ProviderContainer(
        overrides: [
          backendProvider.overrideWithValue(backend),
          routeLoaderProvider.overrideWithValue((_, _) async => null),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(bookingProvider, (_, _) {});
      addTearDown(subscription.close);
      final notifier = container.read(bookingProvider.notifier);
      notifier.confirmPoint(startCenter);
      notifier.confirmPoint(startCenter);
      await Future<void>.delayed(Duration.zero);
      expect(rides.pending, hasLength(1));
      notifier.restart();
      notifier.confirmPoint(startCenter);
      notifier.confirmPoint(startCenter);
      await Future<void>.delayed(Duration.zero);
      rides.pending.first.complete(serverQuote);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(bookingProvider).quote, isNull);
      rides.pending.last.complete(serverQuote);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(bookingProvider).quote!.minMnt, 12000);
    },
  );

  test(
    'server failures clear offers and retry obtains a new authoritative quote',
    () async {
      final rides = ControlledRides();
      final container = ProviderContainer(
        overrides: [
          backendProvider.overrideWithValue(
            Backend(
              mode: BackendMode.supabase,
              zones: MemoryZoneRepository(),
              rides: rides,
              places: MemoryPlaceRepository(),
            ),
          ),
          routeLoaderProvider.overrideWithValue((_, _) async => null),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(bookingProvider, (_, _) {});
      addTearDown(subscription.close);
      final notifier = container.read(bookingProvider.notifier);
      notifier.confirmPoint(startCenter);
      notifier.confirmPoint(startCenter);
      await Future<void>.delayed(Duration.zero);
      rides.pending.single.completeError(const BackendUnavailable());
      await Future<void>.delayed(Duration.zero);
      expect(container.read(bookingProvider).quoteFailed, isTrue);
      expect(container.read(bookingProvider).offerMnt, isNull);
      notifier.retryQuote();
      await Future<void>.delayed(Duration.zero);
      rides.pending.last.complete(serverQuote);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(bookingProvider).offerMnt, 15000);
      notifier.setOffer(1);
      expect(container.read(bookingProvider).offerMnt, 12000);
    },
  );

  test('quote completion after provider disposal is ignored', () async {
    final rides = ControlledRides();
    final container = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(
          Backend(
            mode: BackendMode.supabase,
            zones: MemoryZoneRepository(),
            rides: rides,
            places: MemoryPlaceRepository(),
          ),
        ),
        routeLoaderProvider.overrideWithValue((_, _) async => null),
      ],
    );
    final subscription = container.listen(bookingProvider, (_, _) {});
    final notifier = container.read(bookingProvider.notifier);
    notifier.confirmPoint(startCenter);
    notifier.confirmPoint(startCenter);
    await Future<void>.delayed(Duration.zero);
    subscription.close();
    container.dispose();
    rides.pending.single.complete(serverQuote);
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'local guest, user A and user B stores are isolated across reloads',
    () async {
      final place = erdenetPopularPlaces.first;
      await LocalPlaceStore().save(
        PlaceLibrary().saving(SavedPlaceKind.home, place),
      );
      expect((await LocalPlaceStore(ownerId: 'A').load()).saved, isEmpty);
      await LocalPlaceStore(ownerId: 'A')
          .save(PlaceLibrary().saving(SavedPlaceKind.work, place));
      expect((await LocalPlaceStore(ownerId: 'B').load()).saved, isEmpty);
      expect((await LocalPlaceStore(ownerId: 'A').load()).saved.keys, [
        SavedPlaceKind.work,
      ]);
      expect((await LocalPlaceStore().load()).saved.keys, [
        SavedPlaceKind.home,
      ]);
    },
  );

  test('offline sync keeps local drafts, retries idempotently and refuses a changed owner', () async {
    final remote = MutablePlaces()..fail = true;
    final local = LocalPlaceStore(ownerId: 'rider');
    final store = SyncingPlaceStore(
      local: local,
      remote: remote,
      ownerId: 'rider',
    );
    final report = PlaceReport(
      place: erdenetPopularPlaces.first,
      note: 'Wrong entrance',
      at: DateTime.utc(2026, 10, 20),
    );
    final library = PlaceLibrary()
        .saving(SavedPlaceKind.home, report.place)
        .reporting(report);
    await store.save(library);
    expect(store.syncPending, isTrue);
    expect((await store.load()).reports, hasLength(1));
    expect(remote.reports, isEmpty);
    remote.fail = false;
    await store.retrySync();
    await store.retrySync();
    expect(store.syncPending, isFalse);
    expect(remote.reports['rider'], hasLength(1));
    expect(remote.saved['rider']![SavedPlaceKind.home]!.id, report.place.id);
    remote.currentUser = 'other';
    await expectLater(store.save(library), throwsA(isA<BackendUnavailable>()));
    await expectLater(store.load(), throwsA(isA<BackendUnavailable>()));
    expect(remote.saved.containsKey('other'), isFalse);
  });

  test(
    'sync merges remote saved places with local drafts and retains recents',
    () async {
      final remote = MutablePlaces();
      final local = LocalPlaceStore(ownerId: 'rider');
      await remote.savePlace(
        'rider',
        SavedPlaceKind.home,
        erdenetPopularPlaces.first,
      );
      await remote.savePlace(
        'rider',
        SavedPlaceKind.work,
        erdenetPopularPlaces.last,
      );
      await local.save(
        PlaceLibrary()
            .saving(SavedPlaceKind.home, erdenetPopularPlaces[2])
            .visiting(erdenetPopularPlaces[3]),
      );
      final store = SyncingPlaceStore(
        local: local,
        remote: remote,
        ownerId: 'rider',
      );
      final merged = await store.load();
      expect(merged.saved[SavedPlaceKind.home]!.id, erdenetPopularPlaces[2].id);
      expect(
        merged.saved[SavedPlaceKind.work]!.id,
        erdenetPopularPlaces.last.id,
      );
      expect(merged.recent.single.id, erdenetPopularPlaces[3].id);
    },
  );
}
