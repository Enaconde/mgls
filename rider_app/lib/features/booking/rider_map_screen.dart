import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/places.dart';
import '../../data/backend.dart';
import '../../data/backend_config.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../places/place_providers.dart';
import '../places/place_search_screen.dart';
import '../places/place_store.dart';
import 'booking_controller.dart';
import 'booking_provider.dart';
import 'map_adapter.dart';
import 'maplibre_adapter.dart';
import 'widgets/center_pin.dart';
import 'widgets/map_controls.dart';
import 'widgets/map_view.dart';
import 'widgets/point_steps.dart';
import 'widgets/quote_panel.dart';

class RiderMapScreen extends ConsumerStatefulWidget {
  const RiderMapScreen({super.key, this.mapAdapter});

  final MapAdapter? mapAdapter;

  @override
  ConsumerState<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends ConsumerState<RiderMapScreen> {
  late final MapAdapter _map = widget.mapAdapter ?? MapLibreAdapter();
  bool _is3d = false;
  SavedPlaceKind? _saveOnMap;
  bool _savingPoint = false;

  Future<void> _search() async {
    final selection = await Navigator.of(context).push<PlaceSelection>(
      MaterialPageRoute(
        builder: (_) => PlaceSearchScreen(
          isPickup: ref.read(bookingProvider).stage == BookingStage.pickup,
        ),
      ),
    );
    if (!mounted || selection == null) return;
    setState(() => _saveOnMap = selection.saveOnMap);
    if (selection.place case final place?) {
      if (ref.read(bookingProvider).stage == BookingStage.pickup) {
        _map.moveTo(place.point);
      }
      ref.read(bookingProvider.notifier).confirmPoint(place.point);
    }
  }

  Future<void> _confirmMapPoint([Place? chosen]) async {
    if (_savingPoint) return;
    final point = chosen?.point ?? _map.center;
    if (_saveOnMap != null || chosen != null) {
      setState(() => _savingPoint = true);
      final l10n = AppLocalizations.of(context)!;
      final store = ref.read(placeStoreProvider);
      try {
        final library = await store.load();
        final place =
            chosen ??
            Place(
              id: 'pin_${point.latitude}_${point.longitude}',
              name: l10n.mapPinName,
              area: l10n.erdenetArea,
              point: point,
              kind: PlaceKind.other,
            );
        final next = _saveOnMap == null
            ? library
            : library.saving(_saveOnMap!, place);
        await store.save(next.visiting(place));
        if (!mounted) return;
        setState(() => _saveOnMap = null);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.placeStorageError)));
        }
        return;
      } finally {
        if (mounted) setState(() => _savingPoint = false);
      }
    }
    if (mounted) ref.read(bookingProvider.notifier).confirmPoint(point);
  }

  void _restart() {
    setState(() => _saveOnMap = null);
    ref.read(bookingProvider.notifier).restart();
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _draw(BookingState booking) async {
    await _map.setFareZones(
      ref.read(fareCatalogProvider).asData?.value.zones ?? [],
    );
    if (!mounted) return;
    await _map.drawTrip(
      pickup: booking.pickup,
      dropoff: booking.dropoff,
      route: booking.route,
    );
  }

  void _syncMap(BookingState? previous, BookingState booking) {
    if (previous?.pickup == booking.pickup &&
        previous?.dropoff == booking.dropoff &&
        previous?.route == booking.route) {
      return;
    }
    _draw(booking);
    if (booking.dropoff != null) {
      // Fitting bounds resets tilt in MapLibre; keep the button in sync.
      setState(() => _is3d = false);
      _map.fitTrip(
        booking.route?.points ?? [booking.pickup!, booking.dropoff!],
      );
    }
  }

  Future<void> _toggle3d() async {
    final is3d = await _map.toggle3d();
    if (mounted) setState(() => _is3d = is3d);
  }

  void _order() {
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(backendProvider).mode != BackendMode.demo) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.liveQuoteNotice)));
      return;
    }
    ref.read(bookingProvider.notifier).request();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.requestSent(
            formatMnt(ref.read(bookingProvider).offerMnt!, l10n: l10n),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider);
    ref.listen(bookingProvider, _syncMap);
    final backend = ref.watch(backendProvider);
    ref.listen(fareCatalogProvider, (_, next) {
      _map.setFareZones(next.asData?.value.zones ?? []);
    });
    ref.watch(fareCatalogProvider);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: BookingMapView(
                  adapter: _map,
                  onReady: () => _draw(ref.read(bookingProvider)),
                ),
              ),
              if (booking.choosingPoint)
                CenterPin(isPickup: booking.stage == BookingStage.pickup),
              if (booking.choosingPoint)
                Positioned(
                  left: AppSpacing.page,
                  right: 80,
                  top: MediaQuery.paddingOf(context).top + 48,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 3,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    child: Semantics(
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadius,
                        ),
                        onTap: _savingPoint ? null : _search,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.search),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)!.searchPlaces,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: AppSpacing.page,
                top: MediaQuery.paddingOf(context).top + AppSpacing.page,
                child: MapControls(
                  is3d: _is3d,
                  onToggle3d: _toggle3d,
                  onLocate: _map.locate,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.72,
                    ),
                    child: Card(
                      child: AbsorbPointer(
                        absorbing: _savingPoint,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.page),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                backend.mode == BackendMode.demo
                                    ? AppLocalizations.of(context)!
                                          .demoModeNotice
                                    : backend.mode == BackendMode.unavailable
                                    ? AppLocalizations.of(context)!
                                          .backendUnavailable
                                    : AppLocalizations.of(context)!
                                          .serverFareNotice,
                              ),
                              const SizedBox(height: AppSpacing.unit),
                              if (_savingPoint) const LinearProgressIndicator(),
                              if (_saveOnMap != null) ...[
                                Text(
                                  _saveOnMap == SavedPlaceKind.home
                                      ? AppLocalizations.of(context)!.chooseHome
                                      : AppLocalizations.of(context)!
                                            .chooseWork,
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _saveOnMap = null),
                                  child: Text(
                                    AppLocalizations.of(context)!.cancel,
                                  ),
                                ),
                              ],
                              switch (booking.stage) {
                                BookingStage.pickup => PickupStep(
                                  onConfirm: _confirmMapPoint,
                                ),
                                BookingStage.dropoff => DropoffStep(
                                  onConfirm: _confirmMapPoint,
                                  onRestart: _restart,
                                  onPlace: _confirmMapPoint,
                                ),
                                BookingStage.review ||
                                BookingStage.requested => QuotePanel(
                                  booking: booking,
                                  onOrder: _order,
                                  onRestart: _restart,
                                ),
                              },
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
