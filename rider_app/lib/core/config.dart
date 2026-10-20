import 'package:latlong2/latlong.dart';

import 'pricing.dart';

/// Map opens here until the rider's location is known: Erdenet's central
/// square (Найрамдлын талбай, from OpenStreetMap).
const LatLng startCenter = LatLng(49.0309, 104.0542);

/// PLACEHOLDER zones: rough boxes around Erdenet, not real boundaries.
/// DEMO FALLBACK ONLY. Live mode uses fare_catalog from Supabase.
const List<FareZone> fareZones = [
  FareZone(
    id: '22222222-2222-4222-8222-222222222222',
    town: 'Erdenet',
    kind: ZoneKind.town,
    flatPriceMnt: 3000,
    area: [
      LatLng(49.0630, 104.0230),
      LatLng(49.0630, 104.1430),
      LatLng(49.0030, 104.1430),
      LatLng(49.0030, 104.0230),
    ],
  ),
  // Box around the central square, markets, department store, bus station
  // and hospital. Still a guess at where the flat fare stops.
  FareZone(
    id: '33333333-3333-4333-8333-333333333333',
    town: 'Erdenet',
    kind: ZoneKind.center,
    area: [
      LatLng(49.0380, 104.0420),
      LatLng(49.0380, 104.0660),
      LatLng(49.0220, 104.0660),
      LatLng(49.0220, 104.0420),
    ],
  ),
];

/// PLACEHOLDER tariff until companies set their own.
const Tariff defaultTariff = Tariff(
  baseFareMnt: 1000,
  minPerKmMnt: 1000,
  maxPerKmMnt: 2000,
);
