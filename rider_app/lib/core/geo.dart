import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

ml.LatLng toMapLatLng(LatLng point) =>
    ml.LatLng(point.latitude, point.longitude);

LatLng fromMapLatLng(ml.LatLng point) =>
    LatLng(point.latitude, point.longitude);
