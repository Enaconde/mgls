import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/backend.dart';
import 'data/backend_config.dart';
import 'features/booking/map_adapter.dart';
import 'features/booking/rider_map_screen.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await initializeBackend(const BackendConfig.environment());
  runApp(
    ProviderScope(
      overrides: [backendProvider.overrideWithValue(backend)],
      child: const RiderApp(),
    ),
  );
}

class RiderApp extends StatelessWidget {
  const RiderApp({
    super.key,
    this.mapAdapter,
    this.locale = const Locale('mn'),
  });

  final MapAdapter? mapAdapter;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: RiderMapScreen(mapAdapter: mapAdapter),
    );
  }
}
