import 'package:latlong2/latlong.dart';

import '../../core/pricing.dart';
import '../../core/routing.dart';

enum BookingStage { pickup, dropoff, review, requested }

class BookingState {
  const BookingState({
    this.stage = BookingStage.pickup,
    this.pickup,
    this.dropoff,
    this.quote,
    this.offerMnt,
    this.route,
    this.companyId,
    this.quoting = false,
    this.quoteFailed = false,
  });

  final BookingStage stage;
  final LatLng? pickup;
  final LatLng? dropoff;
  final Quote? quote;
  final int? offerMnt;
  final RoadRoute? route;
  final String? companyId;
  final bool quoting;
  final bool quoteFailed;

  bool get choosingPoint =>
      stage == BookingStage.pickup || stage == BookingStage.dropoff;

  BookingState withReview({
    int? offerMnt,
    RoadRoute? route,
    bool request = false,
    Quote? quote,
    String? companyId,
    bool? quoting,
    bool? quoteFailed,
  }) => BookingState(
    stage: request ? BookingStage.requested : stage,
    pickup: pickup,
    dropoff: dropoff,
    quote: quote ?? this.quote,
    offerMnt: offerMnt ?? this.offerMnt,
    route: route ?? this.route,
    companyId: companyId ?? this.companyId,
    quoting: quoting ?? this.quoting,
    quoteFailed: quoteFailed ?? this.quoteFailed,
  );
}

/// Booking rules only: no Flutter, Riverpod, geolocation or map SDK dependency.
/// The backend will replace the demo quote/request in later milestones.
class BookingController {
  // A supplied tariff is useful for pure rule tests. The running app obtains
  // quotes through RideRepository in both demo and live modes.
  BookingController({this.zones = const [], this.tariff});

  final List<FareZone> zones;
  final Tariff? tariff;
  BookingState _state = const BookingState();
  int _revision = 0;

  BookingState get state => _state;
  int get revision => _revision;

  BookingState confirmPoint(LatLng point) {
    switch (_state.stage) {
      case BookingStage.pickup:
        _state = BookingState(stage: BookingStage.dropoff, pickup: point);
      case BookingStage.dropoff:
        final quote = tariff == null
            ? null
            : quoteTrip(
                pickup: _state.pickup!,
                dropoff: point,
                zones: zones,
                tariff: tariff!,
              );
        _revision++;
        _state = BookingState(
          stage: BookingStage.review,
          pickup: _state.pickup,
          dropoff: point,
          quote: quote,
          offerMnt: quote?.suggestedMnt,
          quoting: quote == null,
        );
      case BookingStage.review:
      case BookingStage.requested:
        break;
    }
    return _state;
  }

  BookingState setOffer(int amount) {
    final quote = _state.quote;
    if (_state.choosingPoint || quote == null) return _state;
    _state = _state.withReview(
      offerMnt: amount.clamp(quote.minMnt, quote.maxMnt),
    );
    return _state;
  }

  BookingState request() {
    if (_state.stage == BookingStage.review &&
        _state.quote != null &&
        !_state.quoting) {
      _state = _state.withReview(request: true);
    }
    return _state;
  }

  BookingState restart() {
    // A revision also rejects stale routes when the same points are reselected.
    _revision++;
    return _state = const BookingState();
  }

  BookingState startQuote({String? companyId}) {
    if (_state.stage != BookingStage.review) return _state;
    _revision++;
    return _state = BookingState(
      stage: BookingStage.review,
      pickup: _state.pickup,
      dropoff: _state.dropoff,
      route: _state.route,
      companyId: companyId ?? _state.companyId,
      quoting: true,
    );
  }

  BookingState applyQuote(Quote quote, int revision, String companyId) {
    if (revision != _revision || _state.stage != BookingStage.review) {
      return _state;
    }
    return _state = _state.withReview(
      quote: quote,
      offerMnt: quote.suggestedMnt,
      companyId: companyId,
      quoting: false,
      quoteFailed: false,
    );
  }

  BookingState failQuote(int revision) {
    if (revision != _revision || _state.stage != BookingStage.review) {
      return _state;
    }
    return _state = _state.withReview(quoting: false, quoteFailed: true);
  }

  BookingState applyRoute(RoadRoute? route, int revision) {
    if (route != null && revision == _revision && !_state.choosingPoint) {
      _state = _state.withReview(route: route);
    }
    return _state;
  }
}
