# M3 backend connection — implementation and remaining acceptance

M3 is **not fully verified** until the owner-provided live connection and SQL
checks pass. Passing Flutter tests with HTTP fakes does not establish real RLS
or PostGIS parity. No M4 implementation or account creation is part of this run.

## Implemented checks

- Configuration: no keys => demo, both values => Supabase, partial/invalid =>
  unavailable. Secret/service-role keys and insecure remote URLs are rejected.
- Demo and live repositories share the same app flow. SDK HTTP tests verify
  catalogue RPC, quote RPC, server-owned amounts, saved owner filters, idempotent
  report writes, malformed responses and network errors. All requests are faked.
- Live prices never fall back to config.dart. Fare/quote errors block a booking
  action; successful server previews still do not claim a real ride was created.
- Quote state covers loading, failure, retry, new company, offer clamping,
  restart with identical endpoints and provider disposal. Routes fail separately.
- Zones/holes and tariffs load from a safe public RPC. The map adapter uses the
  loaded zones, rather than displaying prototype fare polygons in live mode.
- Place drafts persist locally, survive sync outages, retry without duplicate
  reports, and use per-account keys. A changed owner invalidates a store.
  Guest data is never automatically uploaded on login; recents remain local.
- Both themes at 320×700 dp, 1.3× text: server quote loading/error/ready,
  company switching, sync pending and synced. Screenshots are under ignored
  `screenshots/m3_*.png`; test fonts include installed Arial for the ₮ fallback.
- Theme contrast checks cover body/title/secondary text, dialog/button surfaces,
  and fare labels. Static fare labels use readable chips rather than disabled
  controls that reduce text opacity. Mongolian/English copy stays in both ARBs.
- Existing M1/M2 tests plus the new 46-case shared pricing fixture remain green.
  Final commands/result lines are appended to PROGRESS.md.

## Owner-dependent completion

1. Provide an isolated Supabase test project URL and its public anon/publishable
   key through ignored local configuration. Never provide a service-role key.
   No test project or account is created automatically.
2. Apply `supabase/migrations/0001_init.sql`, then
   `supabase/migrations/0002_backend_connection.sql`, once in order. An isolated
   test project may use `seed.sql`. Fake permit/company data must stay out of a
   production service. Production company identity and real fare zones come
   from the owner and remain existing blockers.
3. Run both complete SQL scripts under `supabase/tests/` in that disposable
   database (SQL Editor or an approved existing psql/Supabase CLI installation).
   Expected notices: `pricing_parity: 46 shared cases passed` and
   `backend_access: public fare and private place checks passed`.
   These are expected lines, not execution results from this run.
4. From rider_app, with the full Flutter path, run:

   ```bash
   F=/c/Users/bayrtbaatar/dev/flutter/bin/flutter
   $F test test/supabase_connection_test.dart --dart-define-from-file=env/local.json
   $F run -d web-server --web-port 8091 --web-hostname localhost \
     --dart-define-from-file=env/local.json
   ```

   The live test skips explicitly when no valid configuration exists; a skipped
   test is not evidence that the project connection works. With keys it must
   read nonempty zones and current approved tariffs and obtain a real quote.
5. In the configured app, confirm that company selection changes the server
   quote, a network failure shows retry without demo prices, and map fare
   overlays match the fetched zone set. Confirm system dark/light themes and
   1.3× text on the intended platform. No actual booking is expected in M3.
6. Append the actual SQL/live results to PROGRESS.md before marking M3 verified.

For a local Supabase instance, the owner must explicitly approve installing
the Supabase CLI and Docker first. This run installs neither and changes no
Windows settings. The hosted test-project route does not require local Docker.

## Deliberate limits

- Login/profile UI is M4; real ride creation/realtime status is M5.
- Quote distance is unrounded WGS84 straight-line ×1.3, then rounded once;
  the displayed OSRM route can differ until server-side road routing in M5.
- Both pricing implementations now include planar polygon edges/hole edges,
  choose the smallest overlapping area then UUID, and use 100₮ half-up rounding.
  Dart's previous metre pre-rounding and half-open edge behavior are removed.
  Dart fixture success alone does not prove these changes against PostGIS.
- Saved-place sync uses local drafts as the conflict winner; deletion and
  multi-device conflict resolution are future profile/product work. Reports
  remain queued locally even after a successful idempotent upload for retry.
- The existing map remains light styled; fare UI follows the system theme.
