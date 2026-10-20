import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/backend.dart';
import 'geocoder.dart';
import 'place_store.dart';
import 'syncing_place_store.dart';

final placeStoreProvider = Provider<PlaceStore>((ref) {
  final remote = ref.watch(backendProvider).places;
  final user =
      ref.watch(placeUserProvider.select((state) => state.asData?.value)) ??
      remote.userId;
  final local = LocalPlaceStore(ownerId: user);
  if (user == null) return local;
  return SyncingPlaceStore(local: local, remote: remote, ownerId: user);
});

// Explicit opt-in for one local developer. Release builds always stay offline
// until a production provider with an application-wide limit is configured.
final geocoderProvider = Provider<Geocoder?>((ref) {
  if (!kDebugMode || !const bool.fromEnvironment('MGLS_DEV_NOMINATIM')) {
    return null;
  }
  final client = http.Client();
  ref.onDispose(client.close);
  return NominatimGeocoder(client: client);
});
