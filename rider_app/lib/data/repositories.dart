import 'package:latlong2/latlong.dart';

import '../core/places.dart';
import '../core/pricing.dart';
import '../features/places/place_store.dart';

class CompanyTariff {
  const CompanyTariff({
    required this.id,
    required this.name,
    required this.tariff,
  });
  final String id;
  final String name;
  final Tariff tariff;
}

class FareCatalog {
  FareCatalog({
    required List<FareZone> zones,
    required List<CompanyTariff> companies,
  }) : zones = List.unmodifiable(zones),
       companies = List.unmodifiable(companies);
  final List<FareZone> zones;
  final List<CompanyTariff> companies;
}

abstract interface class ZoneRepository {
  Future<FareCatalog> load();
}

/// M3 previews prices only. Ride creation and realtime lifecycle belong to M5.
abstract interface class RideRepository {
  Future<Quote> quote({
    required LatLng pickup,
    required LatLng dropoff,
    required String companyId,
  });
}

abstract interface class PlaceRepository {
  String? get userId;
  Stream<String?> get userChanges;
  Future<Map<SavedPlaceKind, Place>> savedPlaces(String ownerId);
  Future<void> savePlace(String ownerId, SavedPlaceKind kind, Place place);
  Future<void> report(String ownerId, PlaceReport report);
}

class BackendUnavailable implements Exception {
  const BackendUnavailable();
}
