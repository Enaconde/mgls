import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/config.dart';
import 'package:rider_app/core/pricing.dart';
import 'package:rider_app/core/routing.dart';
import 'package:rider_app/features/booking/booking_controller.dart';

void main() {
  const pickup = startCenter;
  const dropoff = LatLng(49.01, 104.13);
  const route = RoadRoute(
    points: [pickup, dropoff],
    distanceM: 5000,
    durationS: 301,
  );

  BookingController review() =>
      BookingController(zones: fareZones, tariff: defaultTariff)
        ..confirmPoint(pickup)
        ..confirmPoint(dropoff);

  test(
    'pickup → dropoff → review → requested preserves the trip and quote',
    () {
      final controller = BookingController(
        zones: fareZones,
        tariff: defaultTariff,
      );
      final initial = controller.state;
      expect(initial.stage, BookingStage.pickup);
      expect(initial.choosingPoint, isTrue);
      expect(initial.pickup, isNull);
      expect(initial.dropoff, isNull);
      expect(initial.quote, isNull);
      expect(initial.offerMnt, isNull);
      expect(initial.route, isNull);

      final selecting = controller.confirmPoint(pickup);
      expect(selecting.stage, BookingStage.dropoff);
      expect(selecting.pickup, pickup);
      expect(selecting.choosingPoint, isTrue);
      expect(selecting.dropoff, isNull);
      final quoted = controller.confirmPoint(dropoff);
      final expected = quoteTrip(
        pickup: pickup,
        dropoff: dropoff,
        zones: fareZones,
        tariff: defaultTariff,
      );
      expect(quoted.stage, BookingStage.review);
      expect(quoted.choosingPoint, isFalse);
      expect(quoted.pickup, pickup);
      expect(quoted.dropoff, dropoff);
      expect(quoted.quote!.distanceM, expected.distanceM);
      expect(quoted.quote!.minMnt, expected.minMnt);
      expect(quoted.quote!.maxMnt, expected.maxMnt);
      expect(quoted.offerMnt, expected.suggestedMnt);

      final requested = controller.request();
      expect(requested.stage, BookingStage.requested);
      expect(requested.quote, same(quoted.quote));
      expect(requested.offerMnt, quoted.offerMnt);
      expect(initial.stage, BookingStage.pickup);
      expect(selecting.stage, BookingStage.dropoff);
      expect(quoted.stage, BookingStage.review);
    },
  );

  test('premature requests and offers leave point selection untouched', () {
    final controller = BookingController(
      zones: fareZones,
      tariff: defaultTariff,
    );
    for (final point in [null, pickup]) {
      if (point != null) controller.confirmPoint(point);
      final before = controller.state;
      expect(controller.request(), same(before));
      expect(controller.setOffer(900000), same(before));
    }
  });

  test('offers clamp to both tariff limits and allow an in-range amount', () {
    final controller = review();
    final quote = controller.state.quote!;
    expect(controller.setOffer(-1).offerMnt, quote.minMnt);
    expect(controller.setOffer(99999999).offerMnt, quote.maxMnt);
    expect(
      controller.setOffer(quote.suggestedMnt).offerMnt,
      quote.suggestedMnt,
    );
    controller.request();
    // Requests are still demo notices, so retain the prototype's editable offer.
    expect(controller.setOffer(quote.minMnt).offerMnt, quote.minMnt);
    final requested = controller.state;
    expect(requested.stage, BookingStage.requested);
    expect(controller.request(), same(requested));
  });

  test('flat fare cannot be changed by an offer', () {
    final controller =
        BookingController(zones: fareZones, tariff: defaultTariff)
          ..confirmPoint(const LatLng(49.01, 104.04))
          ..confirmPoint(dropoff);
    expect(controller.state.quote!.isFlat, isTrue);
    expect(controller.setOffer(0).offerMnt, 3000);
    expect(controller.setOffer(9000).offerMnt, 3000);
  });

  test('confirmations after review never alter the trip', () {
    final controller = review();
    final before = controller.state;
    expect(controller.confirmPoint(pickup), same(before));
    controller.request();
    final requested = controller.state;
    expect(controller.confirmPoint(dropoff), same(requested));
  });

  test('route updates keep quote and offer; missing route keeps fallback', () {
    final controller = review();
    final quote = controller.state.quote;
    final offer = controller.state.offerMnt;
    final before = controller.state;
    expect(controller.applyRoute(null, controller.revision), same(before));
    final routed = controller.applyRoute(route, controller.revision);
    expect(routed.route, route);
    expect(routed.quote, same(quote));
    expect(routed.offerMnt, offer);
    controller.request();
    expect(
      controller.applyRoute(route, controller.revision).stage,
      BookingStage.requested,
    );
  });

  test('restart clears every stage and invalidates late routes', () {
    for (final stage in BookingStage.values) {
      final controller = BookingController(
        zones: fareZones,
        tariff: defaultTariff,
      );
      if (stage.index >= BookingStage.dropoff.index) {
        controller.confirmPoint(pickup);
      }
      if (stage.index >= BookingStage.review.index) {
        controller.confirmPoint(dropoff);
      }
      if (stage == BookingStage.requested) controller.request();
      final revision = controller.revision;
      controller.restart();
      expect(controller.state.stage, BookingStage.pickup);
      expect(controller.state.pickup, isNull);
      expect(controller.state.dropoff, isNull);
      expect(controller.state.quote, isNull);
      expect(controller.state.offerMnt, isNull);
      expect(controller.state.route, isNull);
      expect(controller.revision, greaterThan(revision));
      controller.applyRoute(route, revision);
      expect(controller.state.route, isNull);
      controller.confirmPoint(pickup);
      controller.confirmPoint(dropoff);
      controller.applyRoute(route, revision);
      expect(controller.state.route, isNull);
    }
  });

  test('injected zones and tariff are used without demo configuration', () {
    final controller =
        BookingController(
            zones: const [],
            tariff: const Tariff(
              baseFareMnt: 4200,
              minPerKmMnt: 0,
              maxPerKmMnt: 0,
            ),
          )
          ..confirmPoint(pickup)
          ..confirmPoint(pickup);
    expect(controller.state.quote!.type, RideType.normal);
    expect(controller.state.offerMnt, 4200);
  });
}
