import '../../data/repositories.dart';
import 'place_store.dart';

/// Guest data is never silently uploaded on login. Each signed-in user has a
/// separate local key; an outage retains their drafts for explicit retry.
class SyncingPlaceStore implements PlaceStore {
  SyncingPlaceStore({
    required this.local,
    required this.remote,
    required this.ownerId,
  });
  final PlaceStore local;
  final PlaceRepository remote;
  final String ownerId;
  bool syncPending = true;

  void _checkOwner() {
    if (remote.userId != ownerId) throw const BackendUnavailable();
  }

  @override
  Future<PlaceLibrary> load() async {
    _checkOwner();
    final library = await local.load();
    try {
      final saved = await remote.savedPlaces(ownerId);
      _checkOwner();
      final merged = PlaceLibrary(
        saved: {...saved, ...library.saved},
        recent: library.recent,
        reports: library.reports,
      );
      await local.save(merged);
      return merged;
    } catch (_) {
      _checkOwner();
      syncPending = true;
      return library;
    }
  }

  @override
  Future<void> save(PlaceLibrary library) async {
    _checkOwner();
    await local.save(library);
    await _sync(library);
    _checkOwner();
  }

  Future<void> retrySync() async {
    _checkOwner();
    await _sync(await local.load());
    _checkOwner();
  }

  Future<void> _sync(PlaceLibrary library) async {
    syncPending = true;
    try {
      for (final entry in library.saved.entries) {
        _checkOwner();
        await remote.savePlace(ownerId, entry.key, entry.value);
      }
      for (final report in library.reports) {
        _checkOwner();
        await remote.report(ownerId, report);
      }
      _checkOwner();
      syncPending = false;
    } catch (_) {
      /* Local drafts stay available for explicit retry. */
    }
  }
}
