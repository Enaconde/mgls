import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import '../../core/routing.dart';
import '../../core/pricing.dart';

/// Booking widgets depend on this seam, never on a platform map controller.
abstract class MapAdapter {
  LatLng get center;

  Widget buildView({
    required VoidCallback onReady,
    required double devicePixelRatio,
  });

  Future<void> locate();
  Future<void> moveTo(LatLng point);
  Future<void> setFareZones(List<FareZone> zones);
  Future<bool> toggle3d();
  Future<void> drawTrip({LatLng? pickup, LatLng? dropoff, RoadRoute? route});
  Future<void> fitTrip(List<LatLng> points);
  void dispose();
}
