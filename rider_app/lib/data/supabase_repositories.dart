import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/places.dart';
import '../core/pricing.dart';
import '../features/places/place_store.dart';
import 'backend_codecs.dart';
import 'repositories.dart';

class SupabaseZoneRepository implements ZoneRepository {
  const SupabaseZoneRepository(this.client);
  final SupabaseClient client;
  @override
  Future<FareCatalog> load() async => parseFareCatalog(
    await client.rpc('fare_catalog').timeout(const Duration(seconds: 12)),
  );
}

class SupabaseRideRepository implements RideRepository {
  const SupabaseRideRepository(this.client);
  final SupabaseClient client;
  @override
  Future<Quote> quote({
    required LatLng pickup,
    required LatLng dropoff,
    required String companyId,
  }) async => parseServerQuote(
    await client
        .rpc(
          'fare_quote',
          params: {
            'p_lat': pickup.latitude,
            'p_lng': pickup.longitude,
            'd_lat': dropoff.latitude,
            'd_lng': dropoff.longitude,
            'p_company': companyId,
          },
        )
        .timeout(const Duration(seconds: 12)),
  );
}

class SupabasePlaceRepository implements PlaceRepository {
  const SupabasePlaceRepository(this.client);
  final SupabaseClient client;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Stream<String?> get userChanges =>
      client.auth.onAuthStateChange.map((event) => event.session?.user.id);

  void _owner(String ownerId) {
    if (userId == null || ownerId != userId) throw const BackendUnavailable();
  }

  @override
  Future<Map<SavedPlaceKind, Place>> savedPlaces(String ownerId) async {
    _owner(ownerId);
    final rows = await client
        .from('saved_places')
        .select('kind,place')
        .eq('owner_id', ownerId)
        .timeout(const Duration(seconds: 12));
    return {
      for (final row in rows)
        SavedPlaceKind.values.byName(row['kind'] as String): placeFromJson(
          row['place'],
        ),
    };
  }

  @override
  Future<void> savePlace(
    String ownerId,
    SavedPlaceKind kind,
    Place place,
  ) async {
    _owner(ownerId);
    await client
        .from('saved_places')
        .upsert({
          'owner_id': ownerId,
          'kind': kind.name,
          'place': placeToJson(place),
        }, onConflict: 'owner_id,kind')
        .timeout(const Duration(seconds: 12));
  }

  @override
  Future<void> report(String ownerId, PlaceReport report) async {
    _owner(ownerId);
    await client
        .from('place_reports')
        .upsert(
          {
            'owner_id': ownerId,
            'client_id': reportClientId(report),
            'place': placeToJson(report.place),
            'note': report.note,
            'reported_at': report.at.toUtc().toIso8601String(),
          },
          onConflict: 'owner_id,client_id',
          ignoreDuplicates: true,
        )
        .timeout(const Duration(seconds: 12));
  }
}
