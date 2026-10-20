# MGLS progress log

Newest entry at the bottom. Every agent run appends one entry.

## 2026-10-20 — Prototype baseline (Claude)

- Rider flow working on web and Android emulator: MapLibre + OpenFreeMap with
  the Amap-style `mgls_light.json`, pickup/dropoff pin, popular Erdenet
  places, OSRM road route with km and minutes, flat 3,000₮ zone fare or offer
  slider inside the tariff range, 2D/3D button.
- Supabase schema written (not yet deployed): `supabase/migrations/0001_init.sql`.
- 14 tests pass; `flutter analyze` clean.
- Backup of this state: `C:\Users\bayrtbaatar\Desktop\mgl-cab-backup-2026-10-20`.
- Next: M1 in `docs/ROADMAP.md`.

### Blocked on owner
- Real Erdenet town and center boundaries for the flat fare.
- Brand colour and logo.
- Supabase project (URL + anon key), SMS provider, QPay merchant account,
  Firebase project, Play/Apple developer accounts.
- Legal answer on route taxis (shugam) and dispatch-service rules.

## 2026-10-20 — M1 Foundation (Codex)

### Changed
- Implemented every M1 Build item: root ignore rules and development README;
  moved pricing/config/places/routing into `lib/core/`; extracted money and
  LatLng conversions; split booking into map view, center pin, map controls,
  pickup/dropoff steps and price widgets under `features/booking/`.
- Added a pure Dart `BookingController` for pickup → dropoff → review →
  requested, plus a Riverpod 3 `NotifierProvider` wrapper and injectable route
  loader. Fare limits remain enforced on offer changes. Restart invalidates
  late route responses even when the same endpoints are selected again.
- Added `MapAdapter` with the existing MapLibre implementation and a test fake.
  Retained the original map asset, center outline, route rendering, location
  fallback and 3D behavior. Moved attribution to the top left so the booking
  card cannot hide it. Pricing numbers, tariff/zones and SQL were not changed.
- Added `l10n.yaml`, `flutter: generate: true`, Mongolian default and English
  ARBs, including place names/areas and accessibility labels. Existing
  Mongolian copy is preserved. Generated localization Dart is ignored and is
  recreated by Flutter; no packages were added.
- Added a clearly marked placeholder teal palette, shared typography, 8-point
  spacing, 16-point rounded cards, button styles and system light/dark themes.
  Map controls have labels and semantic tap actions; controls/place targets
  are at least 48 dp. The booking card can scroll at large text sizes.
- Preserved the demo booking notice, repeat ordering and editable offers;
  requested is now an explicit internal state. Route taxi remains unavailable.
- Updated AGENTS.md's moved source paths and existing test imports. Added
  controller/provider tests, money and pricing edge cases, coordinate and
  localized-place tests, and fake-map widget tests for every booking state,
  English, light/dark mode and 1.3× text at 320 dp.
- Added `docs/M1_MANUAL_CHECKS.md` with the remaining web/emulator checks.

### Verification
- Both requested `flutter.bat analyze` and `flutter.bat test` were attempted.
  They could not start in this sandbox: Flutter cannot write its SDK cache
  lockfile (`C:\Users\bayrtbaatar\dev\flutter\bin\cache\lockfile`).
  The batch startup silently retries its own lock; those attempts were stopped.
- Direct `dart analyze` also could not spawn its analysis-server subprocess
  (Access is denied). As a fallback, launched the installed SDK analysis server
  directly, using a workspace cache and the project package configuration:
  **no diagnostics across all app/generated/test Dart and configuration files**.
  This is not a successful `flutter analyze` run.
- Executed Flutter's installed `LocalizationsGenerator` directly through Dart
  using this project's l10n.yaml: both ARBs generated the real
  `AppLocalizations` API successfully. Generated files are present locally.
- `dart format lib test` succeeded. Audited app Dart for hard-coded user copy;
  only comments contain Mongolian/currency literals outside the generated
  localizations. Map names and attribution remain supplied by the existing map.
- Executed the actual controller/pricing/routing test bodies through the
  installed test_api/matcher libraries in a temporary pure Dart harness:
  **20 passed, 0 failed**. No dependencies were added. This fallback does not
  execute Flutter widgets, localization/money/place tests or provider tests.

### Left / blocked by execution environment
- M1 is implemented but its Done-when criteria are **not fully verified**.
  Claude/owner must run `flutter gen-l10n`, `flutter analyze`, `flutter test`,
  then the visible web and host-GPU emulator checks in `M1_MANUAL_CHECKS.md`.
  Full Flutter tests, actual text-scale layout and real map appearance were
  not run here. Do not mark M1 fully accepted until those pass.
- The existing placeholder boundaries, OSRM development endpoint and mismatch
  between shown road distance and priced distance remain for later milestones.
- A pre-existing pricing parity concern found during inspection remains:
  SQL uses `ST_Covers` on exact zone boundaries, whereas Dart ray casting has
  half-open edge behavior. M1 retains the original pricing as requested; new
  tests check points immediately on either side of every boundary. Resolve
  exact-boundary behavior in a coordinated Dart/SQL pricing change with parity
  tests, rather than changing either implementation alone.
- There is no Git repository metadata in this workspace, so `git status`/diff
  was unavailable. No push, account creation or system changes were performed.

### Blocked on owner
- Choose the brand colour and logo; the theme remains explicitly placeholder.
- Previous owner blockers remain unchanged. None prevented M1 implementation.

## 2026-10-20 — M1 review (Claude)

### Verified
- `flutter gen-l10n`, `flutter analyze` (no issues) and `flutter test` run on
  the real SDK: **42 passed** after the fixes below.
- Restructured app loads in the browser with the same steps and texts.

### Fixed
- `test/booking_widget_test.dart`: the semantics handle was disposed in
  `addTearDown`, which runs after Flutter's end-of-test check, so the test
  failed. Now disposed at the end of the test body.
- `test/geo_test.dart`: compared doubles exactly; MapLibre's `LatLng`
  normalises longitude with float maths (104.0542 → 104.05419999999998). Now
  uses `closeTo(..., 1e-9)`.
- **Dark mode bug** in `lib/theme/app_theme.dart`: `titleMedium`/`titleLarge`
  were replaced by bare `TextStyle`s with no colour, so step titles were dark
  on the dark card (unreadable). Now merged into the base styles. Added
  `test/theme_test.dart` (WCAG contrast ≥ 4.5 on cards, light and dark).

### Lessons for next runs
- Test colour and contrast, not only layout, for every theme change.
- When replacing a theme text style, `merge` into the base style.
- Watch out: the map style is light-only while the UI follows the system
  dark mode. Add a dark map style (or keep the map light on purpose and say
  so) before M12.

### Status
- **M1 verified** (Claude, 2026-10-20): gen-l10n, `No issues found`,
  `All tests passed` (42).

### Next
- M2 (search and places). Packages `shared_preferences` 2.5.6 and `http`
  1.6.0 are already in pubspec.yaml. Still open from M1: the manual emulator
  check in `docs/M1_MANUAL_CHECKS.md`.
- From now on the owner runs Codex with the prompt in `docs/GPT_PROMPT.md`.

## 2026-10-20 — M2 Search and places (Codex)

### Changed
- Read all of AGENTS.md, ROADMAP.md and this progress log, including the M1
  review lessons. M1 is explicitly verified above; M2 was the first unverified
  milestone. Worked only in `C:\Users\bayrtbaatar\Desktop\mgl-cab`.
- Added the top search bar and a full-screen pickup/destination search. Local
  typing is debounced by 350 ms. Results list popular places, then recents,
  then geocoder results, with bold names, theme-aware grey areas and kind icons.
- Added local Home/Work setup and replacement, including choosing a confirmed
  map pin; ten unique recents in most-recent-first order; and local location
  reports with place/coordinates, note and UTC timestamp. These persist through
  shared_preferences. Catalogue IDs restore names/areas in the current locale.
  Reports clearly say they have not been sent; database sync remains M3.
- Added injectable Geocoder and PlaceStore interfaces. The development-only
  Nominatim adapter serializes HTTP starts at least one second apart (including
  failures), caches normalized query/locale results, bounds results to Erdenet,
  identifies native requests with a custom User-Agent, and validates name/area.
  Web uses its browser User-Agent/Referer. Stale responses are ignored.
- Public Nominatim explicitly forbids autocomplete. Checked its official policy:
  https://operations.osmfoundation.org/policies/nominatim/ . Consequently only
  local results filter while typing; online lookup requires an explicit button
  or keyboard submit. The public adapter is opt-in with
  `MGLS_DEV_NOMINATIM=true`, for a single local developer only, and disabled
  in profile/release builds. README documents the application-wide traffic cap,
  caching lifetime, privacy and production replacement requirement.
- Expanded the catalogue from 12 to 16 OSM-sourced Erdenet landmarks, with
  individual source comments: Polytechnic College, Emodin hospital,
  administration building near MUST, and Yeson Erdene market. Existing markets,
  hospitals, schools, government, stations and large shops remain available.
- Added loading, empty, offline, network error and storage error/retry states;
  failed storage does not dismiss the selection/report or replace corrupt data.
  Fixed empty-result status persisting into a failed online retry.
- All new fixed user-facing text is in both ARBs (94 matching text keys in
  each). No hard-coded Mongolian text exists in feature widgets. Retained the
  placeholder brand, default Mongolian, theme-inherited text styles and OSM
  attribution. The map deliberately remains M1's light style for now.
- Added `docs/M2_CHECKS.md`, README instructions, timing/storage/widget tests,
  extended theme contrast checks, and optional ignored visual QA captures.
  No pricing/SQL changes, account creation, push or Windows setting changes.

### Verification
- Used the full installed SDK path from AGENTS.md, in `rider_app`:
  `C:\Users\bayrtbaatar\dev\flutter\bin\flutter.bat`.
- Initial analysis found missing dependencies in the existing Pub cache.
  `flutter pub get` restored the declared dependencies; no new dependency or
  system software was required. Subsequent real Flutter checks succeeded.
- `flutter gen-l10n` — succeeded (exit 0), regenerating the real localizations.
- Final `flutter analyze` result line:
  `No issues found! (ran in 7.5s)`
- Final `flutter test --reporter expanded` result line:
  `00:08 +64: All tests passed!`
- Also ran the full suite with `--dart-define=MGLS_CAPTURE=true`: 64 passed.
  Capture tests load installed SDK fonts without copying them into the app.
  Inspected all four PNGs: search results and report form in light AND dark
  mode, Mongolian, 320 dp width, 1.3× text. Report prompt now wraps above the
  field instead of being truncated as an input label. Widget checks also cover
  English in both themes at 1.3×, plus the report dialog with a keyboard inset.
- Contrast tests require >= 4.5 for names/body/grey area text on scaffold,
  card and dialog surfaces, and for button text, in both themes.
- Offline search, saved/recent selection, report persistence, map-pin saving,
  pickup/dropoff booking integration and error states run with fakes. Storage
  tests additionally reload through the real shared_preferences mock backend.
- Geocoder HTTP tests verify concurrent and failed request start spacing,
  normalized/concurrent cache hits, locale keys, retries, short-query suppression,
  parsing/bounds/area checks and stale UI response rejection. Automated tests
  send no requests to public Nominatim; live lookup is an optional dev smoke
  check, not claimed as performed. Landmark source checks used OSM/Mapcarta
  and an Overpass response, not another taxi app.
- `flutter build web --no-pub` succeeded: `√ Built build\web` (including a
  successful Wasm dry run). No deployment was performed.

### Status / what is left
- **M2 verified** (Codex, 2026-10-20): every Build and Done-when item covered
  by the above implementation and checks. No M3 implementation was started.
- Next milestone: M3 backend connection. Reports and saved-place sync require
  its repository/migration/RLS work; local-only reports do not claim to upload.
- The existing M1 manual emulator check remains documented in
  `M1_MANUAL_CHECKS.md`; this run does not claim an emulator/real-phone check.
  Approximate place centres still need on-the-ground entrance confirmation.
- Existing placeholder zones, shown/priced distance mismatch, exact-boundary
  pricing parity concern, OSRM demo endpoint and light-only map remain for
  their later milestones. No Git metadata exists here, so no Git diff/commit.

### Blocked on owner
- Choose a production geocoder: self-hosted Photon or a paid service, including
  a shared proxy/rate limit/cache and provider switch/disable mechanism. Public
  Nominatim development mode must not be used for a multi-user deployment.
- Existing owner blockers remain: brand/logo, real fare boundaries, Supabase
  project/URL/anon key and any CLI/Docker install approval for M3, SMS provider,
  legal/terms/privacy answers, QPay/e-barimt, Firebase and store accounts.
  None prevented M2's local implementation and verification.

### Lessons for next runs
- Public Nominatim forbids autocomplete, even when debounced. Keep typing
  local and online lookup explicit; per-device timing is not a production
  application-wide rate limiter. Keep the dev flag off for shared/release use.
- Persist IDs and coordinates; resolve bundled catalogue labels for the active
  locale. Keep recents capped/deduplicated and local reports truthful about sync.
- Queue requests across failures and invalidate stale responses when text
  changes. Clear old empty-result status before starting an online retry.
- Preserve theme text colours and test secondary/grey text plus dialog/button
  surfaces, not just titles. Narrow report labels should wrap outside inputs.
- Flutter test image encoding needs `tester.runAsync`; otherwise fake-clock
  tests can hang. Optional visual captures need actual text/icon fonts;
  default test glyphs are unsuitable for visual readability review.
- Match test taps by result-row widget when the search input contains the same
  text as a result, to avoid an ambiguous EditableText/Text finder.
- If analysis cannot find packages, restore declared dependencies before
  diagnosing app code. Flutter runs succeeded with the installed full path;
  no SDK edits or Windows setting changes were needed.

### Files created, moved or deleted
- Created source/docs: `rider_app/lib/features/places/geocoder.dart`,
  `place_providers.dart`, `place_search_screen.dart`, `place_store.dart`;
  `rider_app/test/geocoder_test.dart`, `place_store_test.dart`,
  `place_search_widget_test.dart`; `docs/M2_CHECKS.md`.
- Created ignored QA images: `screenshots/m2_light_results.png`,
  `m2_dark_results.png`, `m2_light_report.png`, `m2_dark_report.png`.
- Moved: none. Deleted: none. Flutter regenerated ignored localization/build
  outputs and dependency caches through its normal commands.

## 2026-10-20 — M3 Backend connection implementation (Codex)

### Changed
- Reread all of AGENTS.md, ROADMAP.md and PROGRESS.md, including every lessons
  section. M1/M2 are marked verified above; M3 is the only milestone worked on.
  All project edits stayed in `C:\Users\bayrtbaatar\Desktop\mgl-cab`.
- Added `supabase_flutter` 2.18.3 and its resolved dependencies. Configuration
  uses only SUPABASE_URL and SUPABASE_ANON_KEY Dart defines; README documents
  ignored env/local.json usage. No real credentials were supplied or written.
  Both absent => demo; partial/invalid => unavailable. The guard rejects remote
  plain HTTP, secret keys and service-role JWTs, without printing their values.
- Added RideRepository, ZoneRepository and PlaceRepository interfaces,
  in-memory demo/test implementations, Supabase implementations and response
  validation. Demo mode keeps the full no-keys flow and local persistence.
  Configured mode never falls back to demo prices when the backend fails.
- Added fare_catalog and fare_quote RPC definitions in migration 0002. Before
  login, clients can read only a curated public zone/company/tariff subset and
  public fare previews; private base tables remain protected. Quotes recheck
  approved company/current permit/tariff. Existing ride and offer triggers,
  vehicle-age rule, receipt fields and route-taxi restriction were preserved.
- Booking now handles asynchronous quotes, loading/error/retry, company choice,
  offer reset/clamping and stale responses after restart/disposal. Map fare
  overlays use loaded zone polygons, including holes. `config.dart` fares are
  used only by the in-memory demo repository (and explicit rule-test fixtures).
  Live mode previews prices and clearly says booking is not available yet;
  login and real ride creation remain M4/M5. No Auth signup was added.
- Added saved_places and append-only place_reports in the same migration as
  their RLS, owner policies, column grants, validation and report retry keys.
  Sync keeps local drafts on outages, supports explicit retry, scopes local
  storage per signed-in user and invalidates a store after an account change.
  Guest data is never silently uploaded on login. Recents stay local. Report
  copy/status now distinguishes local saves from signed-in sync.
- Coordinated the known pricing differences in Dart and the new SQL migration:
  remove Dart's intermediate straight-metre rounding, include polygon edges
  and hole edges, exclude hole interiors, and choose the smallest planar
  overlapping area then UUID. The same 46-case JSON fixture lives inside the
  SQL parity script and is read by Flutter tests. It includes the existing Dart
  pricing scenarios plus exact edges/corners, overlaps, holes, 100₮ ties,
  suggested-fare ties and sub-metre rounding. Actual SQL execution is still
  required; Dart success alone is not proof of PostGIS parity.
- Added rollback-only SQL pricing and access tests, a written RLS/grant check,
  and `docs/M3_CHECKS.md` with exact owner-dependent acceptance steps. Corrected
  the older database README's inaccurate ceil/midpoint description and its
  flat-fare example. Migrations must be applied once in numeric order.
- Added 11 fixed user-facing strings to both ARBs and updated report copy:
  both now have 105 matching text keys. No hard-coded Mongolian widget copy.
- Checked light/dark UI at 320×700 dp and 1.3× text. Added font fallbacks for ₮
  where the installed Roboto lacks it. Static fare labels now stay readable
  instead of using disabled-control opacity; the coming-soon label is wrapping
  plain text. Company labels wrap. No font assets were copied into the app.

### Verification
- Used the full installed Flutter path from AGENTS.md inside rider_app:
  `C:\Users\bayrtbaatar\dev\flutter\bin\flutter.bat`.
- `flutter gen-l10n` succeeded (exit 0) after the final UI edits.
- Final `flutter analyze` result line:
  `No issues found! (ran in 5.8s)`
- Final `flutter test --reporter expanded` result line:
  `00:11 +132 ~1: All tests passed!`
- **132 passed, 1 explicitly skipped**. The skip is only
  `supabase_connection_test.dart`: it requires owner-provided project config and
  migrated test data. It is not counted as a successful live connection check.
- Tests exercise real SDK request/response handling with mocked HTTP, demo
  repository wiring, config guards, malformed responses, server-owned amounts,
  owner filters/idempotent reports, local account isolation/offline retry,
  quote loading/failure/retry/company changes and stale-response protection.
  Mock Auth responses create no external accounts or network requests.
- All 46 shared pricing cases pass on Dart. Existing M1/M2 tests remain green.
  The SQL scripts have **not** run: psql, Supabase CLI and Docker are absent,
  and no test project/credentials were supplied. No tools were installed.
- `flutter build web --no-pub` succeeded during this run, including the Wasm
  dry run: `√ Built build\web`. Nothing was deployed or pushed.
- Optional M3 capture run: `00:03 +5: All tests passed!` with
  `--dart-define=MGLS_CAPTURE=true`. Inspected all ten ignored PNGs for loading,
  error, quote, sync-pending and synced states, light AND dark, 1.3× text.
  Rechecked the final quote images after readability fixes. The test uses a
  fake map; real map/emulator appearance is not claimed as checked here.
  Fonts are read from the installed SDK and Windows Arial; no settings changed.
- Theme contrast tests remain green and include on-surface/secondary text,
  dialog/button surfaces and fare-label backgrounds. ARB key audit matched
  105/105; a feature-source scan found no hard-coded Mongolian text.

### Status / what is left
- **M3 implementation ready, NOT fully verified.** Do not mark M3 verified or
  advance to M4 until real Supabase reads/quotes and both SQL scripts pass.
- Owner checklist is in `docs/M3_CHECKS.md`. The SQL expected notices there
  are expectations, not execution results. Real database RLS, migration
  application and PostGIS/Dart parity remain unverified.
- Login/consent/profile UI is M4. Real ride creation/realtime lifecycle and
  pricing from a server-side road route are M5. M3 intentionally adds neither.
- The existing shown-OSRM/priced-estimate mismatch, placeholder boundaries,
  development OSRM/geocoder and light map style remain for later milestones.
  The old exact-edge and pre-rounding issues now have coordinated code and
  shared fixtures, pending actual SQL execution rather than an acceptance claim.
- Saved-place sync currently lets local drafts win over remote values;
  multi-device conflict resolution/deletion UX is future profile/product work.
  Uploaded reports remain locally available and are idempotent on retry.

### Blocked on owner
- Supply an isolated Supabase test project URL and its public anon/publishable
  key through ignored configuration; never supply a service_role/secret key.
- Apply 0001 then 0002, provision test-only fare/company data, run both SQL
  scripts on a disposable database, then run the live Flutter connection test.
  This can use the hosted SQL Editor; no local Docker is required for that route.
- If local Supabase is wanted, explicitly approve Supabase CLI/Docker installation
  first. Neither they nor PostgreSQL/psql were installed in this run.
- Existing owner blockers remain: real company/permit and fare boundary data,
  brand/logo, production geocoder, SMS/legal/consent text, QPay/e-barimt,
  Firebase and store accounts. No account creation, payment, legal decision or
  real phone was attempted. No Windows/system setting was changed.

### Lessons for next runs
- An HTTP fake passing is not a real Supabase/RLS/PostGIS pass. Keep M3
  unverified until actual SQL and live project results are recorded. A skipped
  live test is an owner blocker, not acceptance evidence.
- supabase_flutter 2.18.3 uses publishableKey at initialization; keep the requested
  SUPABASE_ANON_KEY define as the client-config name. Consult installed API
  sources when package names/parameters change; never log keys during debugging.
- The current PostgREST SDK expects response.request in mocked HTTP responses.
  Missing it produces a misleading null-check failure even with valid JSON.
- Keep live fares server-owned; errors must clear/block quote actions, not
  produce a silent local/demo price. Reject stale async results by revision and
  controller identity. Routing errors must not corrupt fare state.
- Dart Distance defaults to rounding its intermediate result; explicitly disable
  that before applying the road factor. GeoJSON uses longitude/latitude. Share
  fixture payloads with SQL and review exact edges/holes/overlaps, not just zone
  interiors. Never regenerate expected values simply to silence a failing test.
- Keep public fare access behind narrow definer RPCs, not broad table grants.
  New private tables need RLS, grants and WITH CHECK ownership restrictions in
  the same migration. Use stable report IDs for retry and server-owned timestamps.
- Scope local data per account, preserve offline drafts and do not upload guest
  Home/Work automatically on login. Recheck the account around async sync work.
- Scroll state can hide a shortened status message after an update; reveal it
  before asserting its text in widget tests. Avoid UI text in a horizontal Row
  unless it is constrained/wrapping; large text tests caught an overflow here.
- Disabled Material chips can dim text despite labelStyle. Use readable static
  labels for noninteractive fare/status information. Check the rendered result.
  The SDK Roboto used by capture tests lacks ₮; load an installed Arial fallback
  for capture and keep platform font fallbacks in the theme, without shipping
  copied font assets. Preserve inherited light/dark theme colours.

### Files created, moved or deleted
- Created `rider_app/lib/data/`: backend.dart, backend_config.dart,
  backend_codecs.dart, memory_repositories.dart, repositories.dart,
  supabase_repositories.dart.
- Created `rider_app/lib/features/booking/widgets/quote_panel.dart` and
  `rider_app/lib/features/places/syncing_place_store.dart`.
- Created `supabase/migrations/0002_backend_connection.sql`,
  `supabase/tests/pricing_parity.sql`, `supabase/tests/backend_access.sql`.
- Created `rider_app/test/backend_repository_test.dart`, backend_state_test.dart,
  backend_widget_test.dart, pricing_parity_test.dart, supabase_connection_test.dart.
- Created `rider_app/tool/pricing_fixture.dart` and `docs/M3_CHECKS.md`.
- Created ignored QA images: screenshots/m3_light_loading.png,
  m3_dark_loading.png, m3_light_error.png, m3_dark_error.png, m3_light_quote.png,
  m3_dark_quote.png, m3_light_sync_pending.png, m3_dark_sync_pending.png,
  m3_light_sync_ready.png, m3_dark_sync_ready.png.
- Moved: none. Deleted: none. Flutter updated its normal ignored generated
  localization/build/cache outputs. pubspec.yaml and pubspec.lock were updated;
  no secrets were committed and no git push was run. No Git metadata exists here.
