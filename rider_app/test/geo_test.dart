import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/geo.dart';

void main() {
  test(
    'MapLibre conversion preserves latitude and longitude in both directions',
    () {
      for (final point in [
        const LatLng(49.0309, 104.0542),
        const LatLng(-45, -179.9),
        const LatLng(0, 0),
      ]) {
        // MapLibre's LatLng normalises longitude with float maths, so allow
        // a rounding error far below a millimetre.
        final mapPoint = toMapLatLng(point);
        expect(mapPoint.latitude, closeTo(point.latitude, 1e-9));
        expect(mapPoint.longitude, closeTo(point.longitude, 1e-9));
        final back = fromMapLatLng(mapPoint);
        expect(back.latitude, closeTo(point.latitude, 1e-9));
        expect(back.longitude, closeTo(point.longitude, 1e-9));
      }
    },
  );
}
