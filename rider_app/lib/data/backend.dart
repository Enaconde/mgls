import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/pricing.dart';
import 'backend_config.dart';
import 'memory_repositories.dart';
import 'repositories.dart';
import 'supabase_repositories.dart';

class Backend {
  const Backend({
    required this.mode,
    required this.zones,
    required this.rides,
    required this.places,
  });
  factory Backend.demo() {
    final zones = MemoryZoneRepository();
    return Backend(
      mode: BackendMode.demo,
      zones: zones,
      rides: MemoryRideRepository(zones),
      places: MemoryPlaceRepository(),
    );
  }
  factory Backend.live(SupabaseClient client) => Backend(
    mode: BackendMode.supabase,
    zones: SupabaseZoneRepository(client),
    rides: SupabaseRideRepository(client),
    places: SupabasePlaceRepository(client),
  );
  factory Backend.unavailable() => Backend(
    mode: BackendMode.unavailable,
    zones: const _UnavailableZones(),
    rides: const _UnavailableRides(),
    places: MemoryPlaceRepository(),
  );

  final BackendMode mode;
  final ZoneRepository zones;
  final RideRepository rides;
  final PlaceRepository places;
}

Future<Backend> initializeBackend(BackendConfig config) async {
  switch (config.mode) {
    case BackendMode.demo:
      return Backend.demo();
    case BackendMode.unavailable:
      return Backend.unavailable();
    case BackendMode.supabase:
      try {
        final supabase = await Supabase.initialize(
          url: config.url,
          publishableKey: config.anonKey,
          debug: false,
        );
        return Backend.live(supabase.client);
      } catch (_) {
        // A configured backend must never silently fall back to demo prices.
        return Backend.unavailable();
      }
  }
}

final backendProvider = Provider<Backend>((ref) => Backend.demo());
final fareCatalogProvider = FutureProvider<FareCatalog>((ref) async {
  final catalog = await ref.watch(backendProvider).zones.load();
  if (catalog.companies.isEmpty) throw const BackendUnavailable();
  return catalog;
});

final placeUserProvider = StreamProvider<String?>((ref) async* {
  final repository = ref.watch(backendProvider).places;
  yield repository.userId;
  yield* repository.userChanges;
});

class _UnavailableZones implements ZoneRepository {
  const _UnavailableZones();
  @override
  Future<FareCatalog> load() async => throw const BackendUnavailable();
}

class _UnavailableRides implements RideRepository {
  const _UnavailableRides();
  @override
  Future<Quote> quote({
    required LatLng pickup,
    required LatLng dropoff,
    required String companyId,
  }) async => throw const BackendUnavailable();
}
