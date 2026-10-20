import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/config.dart';
import 'package:rider_app/data/backend.dart';
import 'package:rider_app/data/backend_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const config = BackendConfig.environment();
  test(
    'owner project: real public zones, tariffs and quote are available',
    () async {
      final client = SupabaseClient(config.url, config.anonKey);
      addTearDown(client.dispose);
      final backend = Backend.live(client);
      final catalog = await backend.zones.load();
      expect(catalog.zones, isNotEmpty);
      expect(catalog.companies, isNotEmpty);
      final quote = await backend.rides.quote(
        pickup: startCenter,
        dropoff: startCenter,
        companyId: catalog.companies.first.id,
      );
      expect(quote.distanceM, 0);
      expect(quote.suggestedMnt, inInclusiveRange(quote.minMnt, quote.maxMnt));
    },
    skip: config.mode != BackendMode.supabase
        ? 'Owner Supabase URL/anon key and migrated test project are required.'
        : false,
  );
}
