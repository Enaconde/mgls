import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/places.dart';
import 'package:rider_app/features/booking/booking_controller.dart';
import 'package:rider_app/features/booking/booking_provider.dart';
import 'package:rider_app/features/places/geocoder.dart';
import 'package:rider_app/features/places/place_providers.dart';
import 'package:rider_app/features/places/place_search_screen.dart';
import 'package:rider_app/features/places/place_store.dart';
import 'package:rider_app/l10n/app_localizations.dart';
import 'package:rider_app/l10n/app_localizations_en.dart';
import 'package:rider_app/main.dart';
import 'package:rider_app/theme/app_theme.dart';

import 'fake_map.dart';

class MemoryPlaceStore implements PlaceStore {
  PlaceLibrary library = PlaceLibrary();
  bool failLoad = false;
  bool failSave = false;
  Completer<PlaceLibrary>? pending;
  @override
  Future<PlaceLibrary> load() async {
    if (failLoad) throw StateError('unavailable');
    return pending == null ? library : await pending!.future;
  }

  @override
  Future<void> save(PlaceLibrary value) async {
    if (failSave) throw StateError('full');
    library = value;
  }
}

class FakeGeocoder implements Geocoder {
  int calls = 0;
  bool fail = false;
  List<Place> results = [];
  Completer<List<Place>>? pending;
  @override
  Future<List<Place>> search(String query, {required String language}) async {
    calls++;
    if (fail) throw const GeocodingException();
    return pending == null ? results : await pending!.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('MGLS_CAPTURE')) return;
    // Optional Windows-PC visual QA uses the SDK's installed font. No font
    // asset is copied into the app or required by the portable test suite.
    final loader = FontLoader('Roboto');
    for (final name in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
      loader.addFont(
        File(
          'C:/Users/bayrtbaatar/dev/flutter/bin/cache/artifacts/material_fonts/$name',
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File(
          'C:/Users/bayrtbaatar/dev/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await icons.load();
  });
  final english = AppLocalizationsEn();
  final captureKey = GlobalKey();

  Future<void> start(
    WidgetTester tester, {
    required MemoryPlaceStore store,
    Geocoder? geocoder,
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
    Widget? home,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeStoreProvider.overrideWithValue(store),
          geocoderProvider.overrideWithValue(geocoder),
        ],
        child: RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: brightness == Brightness.light
                ? ThemeMode.light
                : ThemeMode.dark,
            home: home ?? const PlaceSearchScreen(isPickup: true),
          ),
        ),
      ),
    );
    await tester.pump();
    if (store.pending == null) await tester.pumpAndSettle();
  }

  Finder list() => find
      .descendant(
        of: find.byType(PlaceSearchScreen),
        matching: find.byType(Scrollable),
      )
      .last;
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 250, scrollable: list());
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Finder resultRow(String id) =>
      find.byWidgetPredicate((w) => w is PlaceResultRow && w.place.id == id);
  Future<void> query(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('MGLS_CAPTURE')) return;
    final boundary =
        captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('../screenshots').create(recursive: true);
      await File('../screenshots/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'offline popular, saved and recent places load with name and area in order',
    (tester) async {
      final store = MemoryPlaceStore();
      final catalog = popularPlaces(english);
      store.library = PlaceLibrary()
          .saving(SavedPlaceKind.home, catalog.last)
          .visiting(catalog.first);
      await start(tester, store: store);
      expect(find.text(english.home), findsOneWidget);
      expect(
        find.text('${catalog.last.name}\n${catalog.last.area}'),
        findsOneWidget,
      );
      await query(tester, 'Dumug');
      await reveal(tester, find.text(english.recentPlaces));
      final rows = tester
          .widgetList<PlaceResultRow>(find.byType(PlaceResultRow))
          .toList();
      expect(rows, hasLength(2));
      expect(
        rows.every((r) => r.place.name.isNotEmpty && r.place.area.isNotEmpty),
        isTrue,
      );
      expect(rows.first.place.id, 'dumug_market');
      expect(find.text(english.onlinePlaces), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'typing is debounced locally, never invokes online search; explicit submit loads results',
    (tester) async {
      final geocoder = FakeGeocoder()
        ..results = [
          Place(
            id: 'remote',
            name: 'Remote school',
            area: 'Erdenet district',
            point: erdenetPopularPlaces.first.point,
            kind: PlaceKind.school,
          ),
        ];
      await start(tester, store: MemoryPlaceStore(), geocoder: geocoder);
      await tester.enterText(find.byType(TextField), 'Remote');
      await tester.pump(const Duration(milliseconds: 200));
      expect(geocoder.calls, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(geocoder.calls, 0);
      await reveal(tester, find.text(english.searchOnline));
      await tester.tap(find.text(english.searchOnline));
      await tester.pumpAndSettle();
      await reveal(tester, resultRow('remote'));
      expect(find.text('Erdenet district'), findsOneWidget);
      expect(geocoder.calls, 1);
    },
  );

  testWidgets(
    'loading, stale online responses, empty and network failure states',
    (tester) async {
      final geocoder = FakeGeocoder()..pending = Completer<List<Place>>();
      await start(tester, store: MemoryPlaceStore(), geocoder: geocoder);
      await query(tester, 'missing');
      await reveal(tester, find.text(english.searchOnline));
      await tester.tap(find.text(english.searchOnline));
      await tester.pump();
      expect(find.text(english.searchingPlaces), findsOneWidget);
      // A changed query invalidates a response even when it cannot cancel HTTP.
      await tester.enterText(find.byType(TextField), 'another');
      geocoder.pending!.complete(popularPlaces(english));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(english.searchingPlaces), findsNothing);
      expect(find.byType(PlaceResultRow), findsNothing);
      geocoder.pending = null;
      await tester.tap(find.text(english.searchOnline));
      await tester.pumpAndSettle();
      expect(find.text(english.noOnlinePlaces), findsOneWidget);
      geocoder.fail = true;
      await tester.tap(find.text(english.searchOnline));
      await tester.pumpAndSettle();
      expect(find.text(english.geocoderError), findsOneWidget);
      expect(find.text(english.noOnlinePlaces), findsNothing);
    },
  );

  testWidgets(
    'load errors preserve data, retry works and save failures remain on screen',
    (tester) async {
      final store = MemoryPlaceStore()..failLoad = true;
      await start(tester, store: store);
      expect(find.text(english.placeStorageError), findsOneWidget);
      store.failLoad = false;
      await tester.tap(find.text(english.retry));
      await tester.pumpAndSettle();
      expect(find.text(english.placeStorageError), findsNothing);
      store.failSave = true;
      await query(tester, 'Dumug');
      await reveal(tester, resultRow('dumug_market'));
      await tester.tap(find.text(english.dumugMarketName));
      await tester.pumpAndSettle();
      expect(find.text(english.placeStorageError), findsOneWidget);
      expect(find.byType(PlaceSearchScreen), findsOneWidget);
      expect(store.library.recent, isEmpty);
    },
  );

  testWidgets('initial storage loading state completes', (tester) async {
    final store = MemoryPlaceStore()..pending = Completer<PlaceLibrary>();
    await start(tester, store: store);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    store.pending!.complete(PlaceLibrary());
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  for (final brightness in Brightness.values) {
    for (final locale in [const Locale('mn'), const Locale('en')]) {
      testWidgets(
        'search, saved selection and report fit 320dp at 1.3x $brightness $locale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final store = MemoryPlaceStore();
          await start(
            tester,
            store: store,
            brightness: brightness,
            locale: locale,
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byType(PlaceSearchScreen)),
          )!;
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip(l10n.editHome));
          await tester.pumpAndSettle();
          expect(find.text(l10n.chooseHome), findsOneWidget);
          await query(tester, l10n.dumugMarketName);
          await reveal(tester, resultRow('dumug_market'));
          await tester.tap(resultRow('dumug_market'));
          await tester.pumpAndSettle();
          expect(store.library.saved[SavedPlaceKind.home]!.id, 'dumug_market');
          if (locale.languageCode == 'mn') {
            await capture(tester, 'm2_${brightness.name}_results');
          }
          final report = find.descendant(
            of: resultRow('dumug_market'),
            matching: find.byType(IconButton),
          );
          await tester.tap(report);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          // Simulate a small keyboard viewport as well as enlarged copy.
          tester.view.viewInsets = const FakeViewPadding(bottom: 220);
          await tester.enterText(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            ),
            'Entrance is on the other side',
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          if (locale.languageCode == 'mn') {
            await capture(tester, 'm2_${brightness.name}_report');
          }
          await tester.tap(find.text(l10n.saveReport));
          await tester.pumpAndSettle();
          expect(store.library.reports.single.place.id, 'dumug_market');
          expect(find.text(l10n.reportStored), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Home/Work survive reopening; selected pickup and dropoff reach booking and recents',
    (tester) async {
      final store = MemoryPlaceStore();
      final map = FakeMapAdapter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            placeStoreProvider.overrideWithValue(store),
            geocoderProvider.overrideWithValue(null),
            routeLoaderProvider.overrideWithValue((_, _) async => null),
          ],
          child: RiderApp(mapAdapter: map, locale: const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> open() async {
        await tester.tap(find.text(english.searchPlaces));
        await tester.pumpAndSettle();
      }

      await open();
      await tester.tap(find.byTooltip(english.editWork));
      await tester.pumpAndSettle();
      await query(tester, 'Dumug');
      await reveal(tester, resultRow('dumug_market'));
      await tester.tap(find.text(english.dumugMarketName));
      await tester.pumpAndSettle();
      expect(store.library.saved[SavedPlaceKind.work]!.id, 'dumug_market');
      Navigator.of(tester.element(find.byType(PlaceSearchScreen))).pop();
      await tester.pumpAndSettle();
      await open();
      await tester.tap(find.text(english.work));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RiderApp)),
      );
      expect(container.read(bookingProvider).stage, BookingStage.dropoff);
      expect(map.center, erdenetPopularPlaces.first.point);
      await open();
      await query(tester, 'Medipas');
      await reveal(tester, resultRow('medipas_hospital'));
      await tester.tap(find.text(english.medipasHospitalName));
      await tester.pumpAndSettle();
      expect(container.read(bookingProvider).stage, BookingStage.review);
      expect(store.library.recent.map((p) => p.id), [
        'medipas_hospital',
        'dumug_market',
      ]);
    },
  );

  testWidgets('Set on map can save Home at the confirmed pin', (tester) async {
    final store = MemoryPlaceStore();
    final map = FakeMapAdapter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeStoreProvider.overrideWithValue(store),
          geocoderProvider.overrideWithValue(null),
        ],
        child: RiderApp(mapAdapter: map, locale: const Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(english.searchPlaces));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(english.editHome));
    await tester.pumpAndSettle();
    await tester.tap(find.text(english.setOnMap));
    await tester.pumpAndSettle();
    expect(find.text(english.chooseHome), findsOneWidget);
    map.center = erdenetPopularPlaces.last.point;
    await tester.tap(find.text(english.pickupConfirm));
    await tester.pumpAndSettle();
    expect(store.library.saved[SavedPlaceKind.home]!.point, map.center);
    expect(store.library.saved[SavedPlaceKind.home]!.area, english.erdenetArea);
    expect(find.text(english.dropoffTitle), findsOneWidget);
  });
}
