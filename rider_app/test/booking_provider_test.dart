import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/config.dart';
import 'package:rider_app/core/routing.dart';
import 'package:rider_app/features/booking/booking_controller.dart';
import 'package:rider_app/features/booking/booking_provider.dart';

void main() {
  const dropoff = LatLng(49.01, 104.13);
  const route = RoadRoute(
    points: [startCenter, dropoff],
    distanceM: 6000,
    durationS: 360,
  );

  test(
    'Riverpod publishes route updates and every controller action',
    () async {
      final pending = Completer<RoadRoute?>();
      final container = ProviderContainer(
        overrides: [
          routeLoaderProvider.overrideWithValue((from, to) {
            expect(from, startCenter);
            expect(to, dropoff);
            return pending.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(bookingProvider, (_, _) {});
      addTearDown(subscription.close);
      final notifier = container.read(bookingProvider.notifier);
      notifier.confirmPoint(startCenter);
      expect(container.read(bookingProvider).stage, BookingStage.dropoff);
      notifier.confirmPoint(dropoff);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(bookingProvider).stage, BookingStage.review);
      notifier.setOffer(0);
      expect(
        container.read(bookingProvider).offerMnt,
        container.read(bookingProvider).quote!.minMnt,
      );
      pending.complete(route);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(bookingProvider).route, route);
      notifier.request();
      expect(container.read(bookingProvider).stage, BookingStage.requested);
      notifier.restart();
      expect(container.read(bookingProvider).stage, BookingStage.pickup);
      expect(container.read(bookingProvider).route, isNull);
    },
  );

  test('late route does not attach to a repeated trip after restart', () async {
    final first = Completer<RoadRoute?>();
    final second = Completer<RoadRoute?>();
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        routeLoaderProvider.overrideWithValue(
          (from, to) => ++calls == 1 ? first.future : second.future,
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(bookingProvider, (_, _) {});
    addTearDown(subscription.close);
    final notifier = container.read(bookingProvider.notifier);
    notifier.confirmPoint(startCenter);
    notifier.confirmPoint(dropoff);
    notifier.restart();
    notifier.confirmPoint(startCenter);
    notifier.confirmPoint(dropoff);
    first.complete(route);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(bookingProvider).route, isNull);
    second.complete(null);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(bookingProvider).route, isNull);
  });

  test('route completion after provider disposal is ignored', () async {
    final pending = Completer<RoadRoute?>();
    final container = ProviderContainer(
      overrides: [
        routeLoaderProvider.overrideWithValue((from, to) => pending.future),
      ],
    );
    final subscription = container.listen(bookingProvider, (_, _) {});
    final notifier = container.read(bookingProvider.notifier);
    notifier.confirmPoint(startCenter);
    notifier.confirmPoint(dropoff);
    subscription.close();
    container.dispose();
    pending.complete(route);
    await Future<void>.delayed(Duration.zero);
  });
}
