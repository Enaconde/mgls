// Coordinates are approximate and must be checked on the ground before use
// as taxi pickup or drop-off points; mapped centres may not be entrances.
// Coordinate data: © OpenStreetMap contributors (ODbL), via Mapcarta.
// https://www.openstreetmap.org/copyright
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_mn.dart';

enum PlaceKind {
  market,
  hospital,
  transport,
  school,
  government,
  shopping,
  other,
}

class Place {
  final String id;
  final String name;
  final String area;
  final LatLng point;
  final PlaceKind kind;

  const Place({
    required this.id,
    required this.name,
    required this.area,
    required this.point,
    required this.kind,
  });
}

final List<Place> erdenetPopularPlaces = popularPlaces(AppLocalizationsMn());

List<Place> popularPlaces(AppLocalizations l10n) => [
  // Source: https://mapcarta.com/W386120824 (OSM way 386120824).
  Place(
    id: 'dumug_market',
    name: l10n.dumugMarketName,
    area: l10n.dumugMarketArea,
    point: LatLng(49.02537, 104.06598),
    kind: PlaceKind.market,
  ),
  // Source: https://mapcarta.com/N11684685012 (OSM node 11684685012).
  Place(
    id: 'tsagaan_urguu_market',
    name: l10n.tsagaanUrguuMarketName,
    area: l10n.tsagaanUrguuMarketArea,
    point: LatLng(49.02463, 104.04659),
    kind: PlaceKind.market,
  ),
  // Source: https://mapcarta.com/W385993734 (OSM way 385993734).
  // Uses the mapped reception building beside the general hospital.
  Place(
    id: 'general_hospital_reception',
    name: l10n.generalHospitalReceptionName,
    area: l10n.generalHospitalReceptionArea,
    point: LatLng(49.03678, 104.05265),
    kind: PlaceKind.hospital,
  ),
  // Source: https://mapcarta.com/N10182540768 (OSM node 10182540768).
  Place(
    id: 'medipas_hospital',
    name: l10n.medipasHospitalName,
    area: l10n.medipasHospitalArea,
    point: LatLng(49.04164, 104.05071),
    kind: PlaceKind.hospital,
  ),
  // Source: https://mapcarta.com/W289066543 (OSM way 289066543).
  Place(
    id: 'erdenet_bus_station',
    name: l10n.erdenetBusStationName,
    area: l10n.erdenetBusStationArea,
    point: LatLng(49.03266, 104.06022),
    kind: PlaceKind.transport,
  ),
  // Source: https://mapcarta.com/N1885432107 (OSM node 1885432107).
  Place(
    id: 'erdenet_railway_station',
    name: l10n.erdenetRailwayStationName,
    area: l10n.erdenetRailwayStationArea,
    point: LatLng(49.05976, 104.16457),
    kind: PlaceKind.transport,
  ),
  // Source: https://mapcarta.com/W386661358 (OSM way 386661358).
  // Office identity/address: https://www.erdenetmc.mn/en/contact
  Place(
    id: 'erdenet_mining_office',
    name: l10n.erdenetMiningOfficeName,
    area: l10n.erdenetMiningOfficeArea,
    point: LatLng(49.03133, 104.05284),
    kind: PlaceKind.government,
  ),
  // Source: https://mapcarta.com/W852635357 (OSM way 852635357).
  Place(
    id: 'nairamdal_square',
    name: l10n.nairamdalSquareName,
    area: l10n.nairamdalSquareArea,
    point: LatLng(49.03093, 104.05414),
    kind: PlaceKind.other,
  ),
  // Source: https://mapcarta.com/N10185127815 (OSM node 10185127815).
  Place(
    id: 'must_erdenet_school',
    name: l10n.mustErdenetSchoolName,
    area: l10n.mustErdenetSchoolArea,
    point: LatLng(49.03122, 104.06259),
    kind: PlaceKind.school,
  ),
  // Source: https://mapcarta.com/W386182655 (OSM way 386182655).
  Place(
    id: 'num_orkhon_school',
    name: l10n.numOrkhonSchoolName,
    area: l10n.numOrkhonSchoolArea,
    point: LatLng(49.01216, 104.03894),
    kind: PlaceKind.school,
  ),
  // Source: https://mapcarta.com/N8221924328 (OSM node 8221924328).
  Place(
    id: 'erdenet_department_store',
    name: l10n.erdenetDepartmentStoreName,
    area: l10n.erdenetDepartmentStoreArea,
    point: LatLng(49.02473, 104.04740),
    kind: PlaceKind.shopping,
  ),
  // Source: https://mapcarta.com/N10175296615 (OSM node 10175296615).
  Place(
    id: 'minii_supermarket',
    name: l10n.miniiSupermarketName,
    area: l10n.miniiSupermarketArea,
    point: LatLng(49.02269, 104.04528),
    kind: PlaceKind.shopping,
  ),
  // OSM: https://www.openstreetmap.org/node/8236874887
  // Coordinates checked at https://mapcarta.com/N8236874887 (2026-10-20).
  Place(
    id: 'erdenet_polytechnic',
    name: l10n.erdenetPolytechnicName,
    area: l10n.erdenetPolytechnicArea,
    point: LatLng(49.02849, 104.06469),
    kind: PlaceKind.school,
  ),
  // OSM: https://www.openstreetmap.org/node/10182533043
  // Coordinates checked at https://mapcarta.com/N10182533043 (2026-10-20).
  Place(
    id: 'emodin_hospital',
    name: l10n.emodinHospitalName,
    area: l10n.emodinHospitalArea,
    point: LatLng(49.03337, 104.05326),
    kind: PlaceKind.hospital,
  ),
  // OSM: https://www.openstreetmap.org/way/387786680
  // Mapped as townhall, not assumed to be the provincial governor's office.
  // Approximate building centre: https://mapcarta.com/W387786680 (2026-10-20).
  Place(
    id: 'administration_building',
    name: l10n.administrationBuildingName,
    area: l10n.administrationBuildingArea,
    point: LatLng(49.02957, 104.06213),
    kind: PlaceKind.government,
  ),
  // OSM: https://www.openstreetmap.org/way/386659029
  // Approximate building centre: https://mapcarta.com/W386659029 (2026-10-20).
  Place(
    id: 'yeson_erdene_market',
    name: l10n.yesonErdeneMarketName,
    area: l10n.yesonErdeneMarketArea,
    point: LatLng(49.02719, 104.06432),
    kind: PlaceKind.market,
  ),
];

/// Matches Cyrillic names or areas, ignoring case and surrounding whitespace.
/// Name prefixes come first; ties retain the supplied list's order.
List<Place> searchPlaces(String query, {List<Place>? places}) {
  places ??= erdenetPopularPlaces;
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return places.toList();

  final prefixes = <Place>[];
  final otherMatches = <Place>[];
  for (final place in places) {
    final name = place.name.toLowerCase();
    if (name.startsWith(normalizedQuery)) {
      prefixes.add(place);
    } else if (name.contains(normalizedQuery) ||
        place.area.toLowerCase().contains(normalizedQuery)) {
      otherMatches.add(place);
    }
  }
  return [...prefixes, ...otherMatches];
}
