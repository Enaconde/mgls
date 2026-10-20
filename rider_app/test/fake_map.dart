import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/config.dart';
import 'package:rider_app/core/routing.dart';
import 'package:rider_app/core/pricing.dart';
import 'package:rider_app/features/booking/map_adapter.dart';

class FakeMapAdapter implements MapAdapter {
  @override
  LatLng center = startCenter;
  bool is3d = false;
  bool disposed = false;
  int locateCount = 0;
  int fitCount = 0;
  LatLng? drawnPickup;
  LatLng? drawnDropoff;
  RoadRoute? drawnRoute;
  List<FareZone> zones = [];
  bool _ready = false;

  @override
  Widget buildView({
    required VoidCallback onReady,
    required double devicePixelRatio,
  }) {
    if (!_ready) {
      _ready = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => onReady());
    }
    return const ColoredBox(key: ValueKey('fake-map'), color: Colors.grey);
  }

  @override
  Future<void> locate() async => locateCount++;

  @override
  Future<void> moveTo(LatLng point) async => center = point;

  @override
  Future<void> setFareZones(List<FareZone> zones) async => this.zones = zones;

  @override
  Future<bool> toggle3d() async => is3d = !is3d;

  @override
  Future<void> drawTrip({
    LatLng? pickup,
    LatLng? dropoff,
    RoadRoute? route,
  }) async {
    drawnPickup = pickup;
    drawnDropoff = dropoff;
    drawnRoute = route;
  }

  @override
  Future<void> fitTrip(List<LatLng> points) async {
    is3d = false;
    fitCount++;
  }

  @override
  void dispose() => disposed = true;
}
