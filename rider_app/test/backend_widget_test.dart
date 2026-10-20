import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/config.dart';
import 'package:rider_app/core/pricing.dart';
import 'package:rider_app/data/backend.dart';
import 'package:rider_app/data/backend_config.dart';
import 'package:rider_app/data/memory_repositories.dart';
import 'package:rider_app/data/repositories.dart';
import 'package:rider_app/features/booking/booking_controller.dart';
import 'package:rider_app/features/booking/booking_provider.dart';
import 'package:rider_app/features/places/place_providers.dart';
import 'package:rider_app/features/places/place_search_screen.dart';
import 'package:rider_app/l10n/app_localizations.dart';
import 'package:rider_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_state_test.dart'
    show ControlledRides, MutablePlaces, serverQuote;
import 'fake_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (!const bool.fromEnvironment('MGLS_CAPTURE')) return;
    const fontRoot =
        'C:/Users/bayrtbaatar/dev/flutter/bin/cache/artifacts/material_fonts';
    final font = FontLoader('Roboto');
    for (final file in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
      font.addFont(
        File('$fontRoot/$file').readAsBytes().then(ByteData.sublistView),
      );
    }
    await font.load();
    final fallback = FontLoader('Arial');
    for (final file in ['arial.ttf', 'arialbd.ttf']) {
      fallback.addFont(
        File('C:/Windows/Fonts/$file').readAsBytes().then(ByteData.sublistView),
      );
    }
    await fallback.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File('$fontRoot/materialicons-regular.otf')
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    await icons.load();
  });

  final boundary = GlobalKey();
  Future<void> capture(WidgetTester tester, String file) async {
    if (!const bool.fromEnvironment('MGLS_CAPTURE')) return;
    final render =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('../screenshots').create(recursive: true);
      await File('../screenshots/$file.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<FakeMapAdapter> start(WidgetTester tester, Backend backend) async {
    final map = FakeMapAdapter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendProvider.overrideWithValue(backend),
          geocoderProvider.overrideWithValue(null),
          routeLoaderProvider.overrideWithValue((_, _) async => null),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: RiderApp(mapAdapter: map),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return map;
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.tap(find.text(text).first);
    await tester.pump();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'server loading, failure, retry and company switch at 1.3x $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final rides = ControlledRides();
        final zones = MemoryZoneRepository(
          FareCatalog(
            zones: [fareZones.last],
            companies: [
              const CompanyTariff(
                id: 'first',
                name: 'MGLS A',
                tariff: defaultTariff,
              ),
              const CompanyTariff(
                id: 'second',
                name: 'MGLS B',
                tariff: defaultTariff,
              ),
            ],
          ),
        );
        final map = await start(
          tester,
          Backend(
            mode: BackendMode.supabase,
            zones: zones,
            rides: rides,
            places: MemoryPlaceRepository(),
          ),
        );
        final strings = l10n(tester);
        expect(map.zones, zones.catalog.zones);
        await tap(tester, strings.pickupConfirm);
        await tester.pumpAndSettle();
        await tap(tester, strings.dropoffConfirm);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(strings.loadingFare), findsOneWidget);
        expect(find.text(strings.order), findsNothing);
        expect(tester.takeException(), isNull);
        await capture(tester, 'm3_${brightness.name}_loading');
        rides.pending.single.completeError(const BackendUnavailable());
        await tester.pumpAndSettle();
        expect(find.text(strings.fareUnavailable), findsOneWidget);
        expect(find.byType(Slider), findsNothing);
        await capture(tester, 'm3_${brightness.name}_error');
        await tap(tester, strings.retry);
        await tester.pump(const Duration(milliseconds: 100));
        rides.pending.last.complete(serverQuote);
        await tester.pumpAndSettle();
        expect(find.text(strings.yourOffer('15,000₮')), findsOneWidget);
        await tester.ensureVisible(find.text(strings.yourOffer('15,000₮')));
        await tester.pumpAndSettle();
        await capture(tester, 'm3_${brightness.name}_quote');
        await tap(tester, 'MGLS B');
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(strings.yourOffer('15,000₮')), findsNothing);
        rides.pending.last.complete(
          const Quote(
            type: RideType.normal,
            distanceM: 4000,
            minMnt: 5000,
            maxMnt: 7000,
            suggestedMnt: 6000,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(strings.yourOffer('6,000₮')), findsOneWidget);
        await tap(tester, strings.order);
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(RiderApp)),
        );
        expect(container.read(bookingProvider).stage, BookingStage.review);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('signed-in sync pending and retry fit 1.3x $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final places = MutablePlaces()..fail = true;
      await start(
        tester,
        Backend(
          mode: BackendMode.supabase,
          zones: MemoryZoneRepository(),
          rides: MemoryRideRepository(MemoryZoneRepository()),
          places: places,
        ),
      );
      final strings = l10n(tester);
      await tap(tester, strings.searchPlaces);
      await tester.pumpAndSettle();
      expect(find.byType(PlaceSearchScreen), findsOneWidget);
      expect(find.text(strings.placesSyncPending), findsOneWidget);
      await capture(tester, 'm3_${brightness.name}_sync_pending');
      places.fail = false;
      await tap(tester, strings.syncPlaces);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(strings.placesSyncReady),
        -200,
        scrollable: find
            .descendant(
              of: find.byType(PlaceSearchScreen),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.text(strings.placesSyncReady), findsOneWidget);
      await capture(tester, 'm3_${brightness.name}_sync_ready');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'unavailable backend is explicit and never displays demo pricing',
    (tester) async {
      await start(tester, Backend.unavailable());
      final strings = l10n(tester);
      expect(find.text(strings.backendUnavailable), findsOneWidget);
      await tap(tester, strings.pickupConfirm);
      await tester.pumpAndSettle();
      await tap(tester, strings.dropoffConfirm);
      await tester.pumpAndSettle();
      expect(find.text(strings.fareUnavailable), findsOneWidget);
      expect(find.text(strings.order), findsNothing);
      expect(find.textContaining('3,000₮'), findsNothing);
    },
  );
}
