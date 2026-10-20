import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/places.dart';
import '../core/pricing.dart';
import '../features/places/place_store.dart';
import 'repositories.dart';

const demoCompanyId = '11111111-1111-4111-8111-111111111111';

class MemoryZoneRepository implements ZoneRepository {
  MemoryZoneRepository([FareCatalog? catalog])
    : catalog =
          catalog ??
          FareCatalog(
            zones: fareZones,
            companies: [
              const CompanyTariff(
                id: demoCompanyId,
                name: 'MGLS',
                tariff: defaultTariff,
              ),
            ],
          );
  final FareCatalog catalog;
  @override
  Future<FareCatalog> load() async => catalog;
}

class MemoryRideRepository implements RideRepository {
  MemoryRideRepository(this.zones);
  final ZoneRepository zones;
  @override
  Future<Quote> quote({
    required LatLng pickup,
    required LatLng dropoff,
    required String companyId,
  }) async {
    final catalog = await zones.load();
    final company = catalog.companies
        .where((c) => c.id == companyId)
        .firstOrNull;
    if (company == null) throw const BackendUnavailable();
    return quoteTrip(
      pickup: pickup,
      dropoff: dropoff,
      zones: catalog.zones,
      tariff: company.tariff,
    );
  }
}

class MemoryPlaceRepository implements PlaceRepository {
  MemoryPlaceRepository({this.userId});
  @override
  final String? userId;
  final saved = <String, Map<SavedPlaceKind, Place>>{};
  final reports = <String, Map<String, PlaceReport>>{};
  @override
  Stream<String?> get userChanges => const Stream.empty();
  void _check(String ownerId) {
    if (userId == null || ownerId != userId) throw const BackendUnavailable();
  }

  @override
  Future<Map<SavedPlaceKind, Place>> savedPlaces(String ownerId) async {
    _check(ownerId);
    return Map.unmodifiable(saved[ownerId] ?? {});
  }

  @override
  Future<void> savePlace(
    String ownerId,
    SavedPlaceKind kind,
    Place place,
  ) async {
    _check(ownerId);
    (saved[ownerId] ??= {})[kind] = place;
  }

  @override
  Future<void> report(String ownerId, PlaceReport report) async {
    _check(ownerId);
    (reports[ownerId] ??=
            {})['${report.at.toIso8601String()}:${report.place.id}'] =
        report;
  }
}
