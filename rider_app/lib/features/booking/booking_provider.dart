import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/routing.dart';
import '../../data/backend.dart';
import '../../data/repositories.dart';
import 'booking_controller.dart';

typedef RouteLoader = Future<RoadRoute?> Function(LatLng from, LatLng to);

final routeLoaderProvider = Provider<RouteLoader>((ref) => fetchRoadRoute);

final bookingProvider = NotifierProvider<BookingNotifier, BookingState>(
  BookingNotifier.new,
  isAutoDispose: true,
);

/// Publishes the pure controller's state; async IO stays outside its rules.
class BookingNotifier extends Notifier<BookingState> {
  late BookingController _controller;

  @override
  BookingState build() {
    ref.watch(backendProvider);
    _controller = BookingController();
    return _controller.state;
  }

  void confirmPoint(LatLng point) {
    final previous = state.stage;
    state = _controller.confirmPoint(point);
    if (previous == BookingStage.dropoff) {
      _loadRoute();
      _loadQuote();
    }
  }

  Future<void> _loadQuote() async {
    final controller = _controller;
    final revision = controller.revision;
    final pickup = state.pickup!, dropoff = state.dropoff!;
    final wantedCompany = state.companyId;
    try {
      final catalog = await ref.read(fareCatalogProvider.future);
      final company =
          catalog.companies.where((c) => c.id == wantedCompany).firstOrNull ??
          (wantedCompany == null ? catalog.companies.first : null);
      if (company == null) throw const BackendUnavailable();
      final quote = await ref
          .read(backendProvider)
          .rides
          .quote(pickup: pickup, dropoff: dropoff, companyId: company.id);
      if (!ref.mounted || !identical(_controller, controller)) return;
      state = controller.applyQuote(quote, revision, company.id);
    } catch (_) {
      if (ref.mounted && identical(_controller, controller)) {
        state = controller.failQuote(revision);
      }
    }
  }

  void retryQuote({String? companyId}) {
    if (state.stage != BookingStage.review || state.quoting) return;
    ref.invalidate(fareCatalogProvider);
    state = _controller.startQuote(companyId: companyId);
    _loadRoute();
    _loadQuote();
  }

  Future<void> _loadRoute() async {
    final controller = _controller;
    final revision = controller.revision;
    try {
      final route = await ref.read(routeLoaderProvider)(
        state.pickup!,
        state.dropoff!,
      );
      if (!ref.mounted || !identical(_controller, controller)) return;
      state = controller.applyRoute(route, revision);
    } catch (_) {
      /* Routing failure keeps the price-distance estimate. */
    }
  }

  void setOffer(int amount) => state = _controller.setOffer(amount);
  void request() => state = _controller.request();
  void restart() => state = _controller.restart();
}
