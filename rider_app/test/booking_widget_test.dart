import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/config.dart';
import 'package:rider_app/core/routing.dart';
import 'package:rider_app/features/booking/booking_controller.dart';
import 'package:rider_app/features/booking/booking_provider.dart';
import 'package:rider_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_map.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<FakeMapAdapter> start(
    WidgetTester tester, {
    Locale locale = const Locale('mn'),
    RouteLoader? loader,
  }) async {
    final map = FakeMapAdapter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routeLoaderProvider.overrideWithValue(
            loader ?? (from, to) async => null,
          ),
        ],
        child: RiderApp(mapAdapter: map, locale: locale),
      ),
    );
    await tester.pumpAndSettle();
    return map;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('pickup step uses fake map, labelled controls and center pin', (
    tester,
  ) async {
    // Disposed at the end of the body: Flutter checks for live handles before
    // tear-downs run, so addTearDown would be too late.
    final semantics = tester.ensureSemantics();
    final map = await start(tester);
    expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);
    expect(find.text('Хаанаас суух вэ?'), findsOneWidget);
    expect(find.bySemanticsLabel('Суух цэгийн зүү'), findsOneWidget);
    expect(find.bySemanticsLabel('Миний байршил'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Миний байршил')),
      matchesSemantics(
        label: 'Миний байршил',
        isButton: true,
        hasTapAction: true,
        tooltip: 'Миний байршил',
      ),
    );
    await tester.tap(find.byTooltip('Миний байршил'));
    await tester.pumpAndSettle();
    expect(map.locateCount, 1);
    expect(
      tester.getSize(find.byTooltip('Миний байршил')).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byTooltip('Гурван хэмжээст зураг харах'));
    await tester.pumpAndSettle();
    expect(find.text('2D'), findsOneWidget);
    expect(map.is3d, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(map.disposed, isTrue);
    semantics.dispose();
  });

  testWidgets(
    'dropoff step shows popular places and restart clears the pickup',
    (tester) async {
      final map = await start(tester);
      await tap(tester, 'Энд суух');
      expect(find.text('Хаашаа явах вэ?'), findsOneWidget);
      expect(find.text('Түгээмэл газрууд'), findsOneWidget);
      expect(find.text('Дөмөг хүнсний зах'), findsOneWidget);
      expect(map.drawnPickup, startCenter);
      await tap(tester, 'Дахин эхлэх');
      expect(find.text('Хаанаас суух вэ?'), findsOneWidget);
      expect(map.drawnPickup, isNull);
    },
  );

  testWidgets(
    'review shows tariff offer, road route, and resets 3D after fit',
    (tester) async {
      final pending = Completer<RoadRoute?>();
      final map = await start(tester, loader: (from, to) => pending.future);
      await tap(tester, 'Энд суух');
      await tap(tester, 'Дөмөг хүнсний зах');
      expect(find.text('Энгийн такси'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(map.drawnDropoff, const LatLng(49.02537, 104.06598));
      await tester.tap(find.byTooltip('Гурван хэмжээст зураг харах'));
      await tester.pumpAndSettle();
      pending.complete(
        const RoadRoute(
          points: [startCenter, LatLng(49.02537, 104.06598)],
          distanceM: 4700,
          durationS: 301,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4.7 км · 6 мин'), findsOneWidget);
      expect(find.text('3D'), findsOneWidget);
      expect(map.drawnRoute!.distanceM, 4700);
      expect(map.fitCount, 2);
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(slider.min);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RiderApp)),
      );
      expect(container.read(bookingProvider).offerMnt, slider.min.toInt());
    },
  );

  testWidgets('flat review has fixed price, requested state and demo notice', (
    tester,
  ) async {
    final map = await start(tester);
    map.center = const LatLng(49.01, 104.04);
    await tap(tester, 'Энд суух');
    map.center = const LatLng(49.01, 104.13);
    await tap(tester, 'Энд буух');
    expect(find.text('Хот доторх тогтмол үнэ: 3,000₮'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    await tap(tester, 'Захиалах');
    expect(
      find.text('Захиалга илгээгдлээ: 3,000₮ (туршилт, сервер холбогдоогүй)'),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RiderApp)),
    );
    expect(container.read(bookingProvider).stage, BookingStage.requested);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(tester, 'Дахин эхлэх');
    expect(find.text('Хаанаас суух вэ?'), findsOneWidget);
    expect(map.drawnDropoff, isNull);
  });

  testWidgets('English locale translates steps, place names and demo notice', (
    tester,
  ) async {
    await start(tester, locale: const Locale('en'));
    expect(find.text('Where should we pick you up?'), findsOneWidget);
    await tap(tester, 'Pick up here');
    expect(find.text('Dumug food market'), findsOneWidget);
    await tap(tester, 'Dumug food market');
    expect(find.text('Normal taxi'), findsOneWidget);
    await tap(tester, 'Book');
    expect(find.textContaining('server not connected'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('all steps fit 320dp width at 1.3 text scale in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await start(tester);
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        brightness,
      );
      expect(tester.takeException(), isNull);
      await tap(tester, 'Энд суух');
      expect(tester.takeException(), isNull);
      await tap(tester, 'Энд буух');
      expect(tester.takeException(), isNull);
      await tap(tester, 'Захиалах');
      expect(tester.takeException(), isNull);
    });
  }
}
