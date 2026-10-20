import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/places.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'place_providers.dart';
import 'place_store.dart';
import 'syncing_place_store.dart';

class PlaceSelection {
  const PlaceSelection({this.place, this.saveOnMap});
  final Place? place;
  final SavedPlaceKind? saveOnMap;
}

class PlaceSearchScreen extends ConsumerStatefulWidget {
  const PlaceSearchScreen({super.key, required this.isPickup});
  final bool isPickup;

  @override
  ConsumerState<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends ConsumerState<PlaceSearchScreen> {
  final _text = TextEditingController();
  Timer? _debounce;
  PlaceLibrary _library = PlaceLibrary();
  String _query = '';
  List<Place> _online = const [];
  SavedPlaceKind? _saving;
  bool _loading = true;
  bool _loadError = false;
  bool _busy = false;
  bool _searching = false;
  bool _searchError = false;
  bool _searched = false;
  int _generation = 0;
  int _libraryGeneration = 0;

  bool get _ready => !_loading && !_loadError && !_busy;
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_libraryGeneration;
    final store = ref.read(placeStoreProvider);
    setState(() {
      _library = PlaceLibrary();
      _loading = true;
      _loadError = false;
    });
    try {
      final library = await store.load();
      if (mounted && generation == _libraryGeneration) {
        setState(() => _library = library);
      }
    } catch (_) {
      if (mounted && generation == _libraryGeneration) {
        setState(() => _loadError = true);
      }
    } finally {
      if (mounted && generation == _libraryGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _generation++;
    setState(() {
      _online = const [];
      _searching = false;
      _searchError = false;
      _searched = false;
    });
    // Only offline filtering is debounced. Nominatim must never autocomplete.
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value);
    });
  }

  Future<void> _searchOnline() async {
    final geocoder = ref.read(geocoderProvider);
    final query = _text.text.trim();
    if (geocoder == null || query.length < 2 || _searching) return;
    final generation = ++_generation;
    setState(() {
      _searching = true;
      _searchError = false;
      _searched = false;
      _online = [];
    });
    try {
      final places = await geocoder.search(query, language: _l10n.localeName);
      if (mounted && generation == _generation) {
        setState(() {
          _online = places;
          _searched = true;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _searchError = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _searching = false);
      }
    }
  }

  Future<bool> _persist(PlaceLibrary next) async {
    if (!_ready) return false;
    final generation = _libraryGeneration;
    setState(() => _busy = true);
    try {
      await ref.read(placeStoreProvider).save(next);
      if (!mounted || generation != _libraryGeneration) return false;
      setState(() => _library = next);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_l10n.placeStorageError)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose(Place place) async {
    if (_saving case final kind?) {
      if (await _persist(_library.saving(kind, place)) && mounted) {
        setState(() => _saving = null);
      }
    } else if (await _persist(_library.visiting(place)) && mounted) {
      Navigator.pop(context, PlaceSelection(place: place));
    }
  }

  Future<void> _report(Place place) async {
    final generation = _libraryGeneration;
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _ReportDialog(place: place),
    );
    if (note == null || !mounted || generation != _libraryGeneration) return;
    final saved = await _persist(
      _library.reporting(
        PlaceReport(place: place, note: note, at: DateTime.now().toUtc()),
      ),
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_l10n.reportStored)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(placeStoreProvider);
    ref.listen(placeStoreProvider, (previous, next) {
      if (!identical(previous, next)) _load();
    });
    final l10n = _l10n;
    final theme = Theme.of(context);
    final catalog = popularPlaces(l10n);
    final byId = {for (final p in catalog) p.id: p};
    Place localized(Place p) => byId[p.id] ?? p;
    final popular = searchPlaces(_query, places: catalog);
    final recent = searchPlaces(
      _query,
      places: _library.recent.map(localized).toList(),
    );
    final saved = _library.saved.map((k, v) => MapEntry(k, localized(v)));
    final localIds = {...popular.map((p) => p.id), ...recent.map((p) => p.id)};
    final online = _online.where((p) => !localIds.contains(p.id)).toList();
    final canOnline = ref.watch(geocoderProvider) != null;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    Widget row(Place place) => PlaceResultRow(
      place: place,
      onTap: _ready ? () => _choose(place) : null,
      onReport: _ready ? () => _report(place) : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPickup ? l10n.searchPickup : l10n.searchDropoff),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: TextField(
                controller: _text,
                decoration: InputDecoration(
                  labelText: l10n.searchPlaces,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: l10n.clearSearch,
                    onPressed: () {
                      _text.clear();
                      _changed('');
                    },
                    icon: const Icon(Icons.clear),
                  ),
                ),
                onChanged: _changed,
                onSubmitted: (_) => _searchOnline(),
                textInputAction: TextInputAction.search,
              ),
            ),
            if (_loading || _busy) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                children: [
                  if (store is SyncingPlaceStore)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.syncPending
                                ? l10n.placesSyncPending
                                : l10n.placesSyncReady,
                          ),
                          TextButton(
                            onPressed: !_ready
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    try {
                                      await store.retrySync();
                                    } catch (_) {
                                      // A changed account invalidates the old
                                      // store; its drafts remain in its key.
                                    } finally {
                                      if (mounted) {
                                        setState(() => _busy = false);
                                      }
                                    }
                                  },
                            child: Text(l10n.syncPlaces),
                          ),
                        ],
                      ),
                    ),
                  if (_loadError)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.placeStorageError),
                          TextButton(onPressed: _load, child: Text(l10n.retry)),
                        ],
                      ),
                    ),
                  if (_saving != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _saving == SavedPlaceKind.home
                                ? l10n.chooseHome
                                : l10n.chooseWork,
                            style: theme.textTheme.titleMedium,
                          ),
                          TextButton(
                            onPressed: () => setState(() => _saving = null),
                            child: Text(l10n.cancel),
                          ),
                        ],
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.pin_drop),
                    title: Text(l10n.setOnMap),
                    subtitle: Text(l10n.moveMapHint),
                    onTap: _busy
                        ? null
                        : () => Navigator.pop(
                            context,
                            PlaceSelection(saveOnMap: _saving),
                          ),
                  ),
                  heading(l10n.savedPlaces),
                  for (final kind in SavedPlaceKind.values)
                    ListTile(
                      leading: Icon(
                        kind == SavedPlaceKind.home ? Icons.home : Icons.work,
                      ),
                      title: Text(
                        kind == SavedPlaceKind.home ? l10n.home : l10n.work,
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        saved[kind] == null
                            ? l10n.notSet
                            : '${saved[kind]!.name}\n${saved[kind]!.area}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      isThreeLine: saved[kind] != null,
                      onTap: !_ready
                          ? null
                          : saved[kind] == null
                          ? () => setState(() => _saving = kind)
                          : () => _choose(saved[kind]!),
                      trailing: IconButton(
                        tooltip: kind == SavedPlaceKind.home
                            ? l10n.editHome
                            : l10n.editWork,
                        icon: const Icon(Icons.edit_location_alt),
                        onPressed: _ready
                            ? () => setState(() => _saving = kind)
                            : null,
                      ),
                    ),
                  heading(l10n.popularPlaces),
                  for (final p in popular) row(p),
                  heading(l10n.recentPlaces),
                  for (final p in recent) row(p),
                  if (recent.isEmpty && _query.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(l10n.noRecentPlaces),
                    ),
                  if (popular.isEmpty &&
                      recent.isEmpty &&
                      _query.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.noLocalPlaces),
                    ),
                  heading(l10n.onlinePlaces),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          canOnline
                              ? l10n.devGeocoderNotice
                              : l10n.offlinePlacesNotice,
                        ),
                        if (canOnline)
                          FilledButton.tonalIcon(
                            onPressed:
                                _text.text.trim().length < 2 || _searching
                                ? null
                                : _searchOnline,
                            icon: const Icon(Icons.travel_explore),
                            label: Text(l10n.searchOnline),
                          ),
                        if (_searching) ...[
                          const LinearProgressIndicator(),
                          Text(l10n.searchingPlaces),
                        ],
                        if (_searchError) Text(l10n.geocoderError),
                        if (_searched && online.isEmpty)
                          Text(l10n.noOnlinePlaces),
                      ],
                    ),
                  ),
                  for (final p in online) row(p),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.osmAttribution,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceResultRow extends StatelessWidget {
  const PlaceResultRow({
    super.key,
    required this.place,
    this.onTap,
    this.onReport,
  });
  final Place place;
  final VoidCallback? onTap;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(placeIcon(place.kind)),
    title: Text(
      place.name,
      style: Theme.of(context).textTheme.titleMedium!
          .copyWith(fontWeight: FontWeight.bold),
    ),
    subtitle: Text(
      place.area,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
    onTap: onTap,
    trailing: IconButton(
      tooltip: AppLocalizations.of(context)!.locationWrong,
      onPressed: onReport,
      icon: const Icon(Icons.wrong_location_outlined),
    ),
  );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.place});
  final Place place;
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.locationWrong),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.place.name),
          Text(l10n.reportLocalNotice),
          const SizedBox(height: AppSpacing.unit),
          Text(l10n.reportDetails),
          Semantics(
            label: l10n.reportDetails,
            child: TextField(
              controller: _note,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _note.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _note.text.trim()),
          child: Text(l10n.saveReport),
        ),
      ],
    );
  }
}

IconData placeIcon(PlaceKind kind) => switch (kind) {
  PlaceKind.market => Icons.storefront,
  PlaceKind.hospital => Icons.local_hospital,
  PlaceKind.transport => Icons.directions_bus,
  PlaceKind.school => Icons.school,
  PlaceKind.government => Icons.account_balance,
  PlaceKind.shopping => Icons.shopping_bag,
  PlaceKind.other => Icons.place,
};
