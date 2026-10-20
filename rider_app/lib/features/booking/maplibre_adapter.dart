import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../core/config.dart';
import '../../core/geo.dart';
import '../../core/pricing.dart';
import '../../core/routing.dart';
import '../../theme/app_theme.dart';
import 'map_adapter.dart';

/// Original OpenFreeMap style and rendering, isolated from the booking widgets.
class MapLibreAdapter implements MapAdapter {
  ml.MapLibreMapController? _map;
  bool _ready = false;
  bool _disposed = false;
  bool _is3d = false;
  double _iconScale = 0.5;
  Future<void> _drawing = Future.value();
  List<FareZone> _zones = const [];

  @override
  LatLng get center {
    final target = _map?.cameraPosition?.target;
    return target == null ? startCenter : fromMapLatLng(target);
  }

  @override
  Widget buildView({
    required VoidCallback onReady,
    required double devicePixelRatio,
  }) {
    _iconScale = kIsWeb ? 0.5 : devicePixelRatio / 2;
    return ml.MapLibreMap(
      styleString: 'assets/map_style/mgls_light.json',
      initialCameraPosition: ml.CameraPosition(
        target: toMapLatLng(startCenter),
        zoom: 14.5,
      ),
      trackCameraPosition: true,
      compassEnabled: false,
      // The bottom booking card must never cover OpenStreetMap attribution.
      attributionButtonPosition: ml.AttributionButtonPosition.topLeft,
      onMapCreated: (controller) => _map = controller,
      onStyleLoadedCallback: () async {
        final map = _map;
        if (map == null || _disposed) return;
        await map.addImage('stop-pickup', await _stopIcon(BoxShape.circle));
        if (_disposed) return;
        await map.addImage('stop-dropoff', await _stopIcon(BoxShape.rectangle));
        if (_disposed) return;
        _ready = true;
        await setFareZones(_zones);
        onReady();
        await locate();
      },
    );
  }

  @override
  Future<void> setFareZones(List<FareZone> zones) {
    _zones = zones;
    if (!_ready || _disposed) return Future.value();
    _drawing = _drawing.then((_) async {
      final map = _map;
      if (map == null || _disposed) return;
      await map.clearFills();
      for (final zone in zones.where((z) => z.kind == ZoneKind.center)) {
        if (_disposed) return;
        await map.addFill(
          ml.FillOptions(
            geometry: [
              zone.area.map(toMapLatLng).toList(),
              ...zone.holes.map((ring) => ring.map(toMapLatLng).toList()),
            ],
            fillColor: '#FF9800',
            fillOpacity: 0.06,
            fillOutlineColor: '#FFB74D',
          ),
        );
      }
    });
    return _drawing;
  }

  @override
  Future<void> moveTo(LatLng point) async {
    if (_disposed) return;
    await _map?.animateCamera(ml.CameraUpdate.newLatLng(toMapLatLng(point)));
  }

  @override
  Future<void> locate() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (_disposed) return;
      await _map?.animateCamera(
        ml.CameraUpdate.newLatLngZoom(
          ml.LatLng(position.latitude, position.longitude),
          16,
        ),
      );
    } catch (_) {
      // Location unavailable: stay on the default town.
    }
  }

  @override
  Future<bool> toggle3d() async {
    final camera = _map?.cameraPosition;
    if (camera == null || _disposed) return _is3d;
    _is3d = !_is3d;
    await _map!.animateCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: camera.target,
          zoom: _is3d && camera.zoom < 16 ? 16 : camera.zoom,
          tilt: _is3d ? 55 : 0,
          bearing: camera.bearing,
        ),
      ),
    );
    return _is3d;
  }

  @override
  Future<void> drawTrip({LatLng? pickup, LatLng? dropoff, RoadRoute? route}) {
    // Serial redraws prevent late route responses from leaving duplicate marks.
    _drawing = _drawing.then((_) => _drawTrip(pickup, dropoff, route));
    return _drawing;
  }

  Future<void> _drawTrip(
    LatLng? pickup,
    LatLng? dropoff,
    RoadRoute? route,
  ) async {
    final map = _map;
    if (map == null || !_ready || _disposed) return;
    await map.clearLines();
    if (_disposed) return;
    await map.clearSymbols();
    if (_disposed) return;
    if (pickup != null && dropoff != null) {
      final line = (route?.points ?? [pickup, dropoff])
          .map(toMapLatLng)
          .toList();
      await map.addLine(
        ml.LineOptions(
          geometry: line,
          lineColor: '#FFFFFF',
          lineWidth: 9,
          lineJoin: 'round',
        ),
      );
      if (_disposed) return;
      await map.addLine(
        ml.LineOptions(
          geometry: line,
          lineColor: '#111111',
          lineWidth: 5,
          lineJoin: 'round',
        ),
      );
    }
    if (_disposed) return;
    if (pickup != null) {
      await map.addSymbol(
        ml.SymbolOptions(
          geometry: toMapLatLng(pickup),
          iconImage: 'stop-pickup',
          iconSize: _iconScale,
        ),
      );
    }
    if (_disposed) return;
    if (dropoff != null) {
      await map.addSymbol(
        ml.SymbolOptions(
          geometry: toMapLatLng(dropoff),
          iconImage: 'stop-dropoff',
          iconSize: _iconScale,
        ),
      );
    }
  }

  @override
  Future<void> fitTrip(List<LatLng> points) async {
    if (points.isEmpty || _disposed) return;
    _is3d = false;
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    await _map?.animateCamera(
      ml.CameraUpdate.newLatLngBounds(
        ml.LatLngBounds(
          southwest: ml.LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
          northeast: ml.LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
        ),
        left: 48,
        top: 96,
        right: 48,
        bottom: 340,
      ),
    );
  }

  @override
  void dispose() {
    // MapLibreMap owns and disposes its platform controller.
    _disposed = true;
    _map = null;
  }
}

/// Draws a pickup (circle) or dropoff (square) mark as a PNG for the map:
/// dark fill, white border and a small white center.
Future<Uint8List> _stopIcon(BoxShape shape) async {
  const size = 44.0; // 2x for sharp edges; the map shows it at about 22px.
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final outer = Rect.fromLTWH(4, 4, size - 8, size - 8);
  final white = Paint()..color = Colors.white;
  final dark = Paint()..color = AppColors.ink;
  void draw(Rect r, Paint p) =>
      shape == BoxShape.circle ? canvas.drawOval(r, p) : canvas.drawRect(r, p);
  draw(outer, white);
  draw(outer.deflate(4), dark);
  draw(Rect.fromCenter(center: outer.center, width: 12, height: 12), white);
  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
