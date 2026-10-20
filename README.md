# MGLS

MGLS is a taxi app for Mongolian towns, starting in **Erdenet**.

**The core idea: taxi drivers choose their own price.** Instead of the app
fixing one fare, each driver sets the price they want, riders see the offers
and pick the one they like (cheapest, closest or best rated). This works for
two kinds of taxi:

1. **Zone taxi** — a flat price for any trip inside the town zone.
2. **Shugamiin taxi** — a shared car on a fixed route, sold per seat.

Taxi companies that hold a permit join the app and bring their own cars and
drivers.

## How it works

### Zone taxi

The town is drawn on the map as a **zone** (with a separate **center zone**).
A trip that starts and ends inside the town zone has one flat price, no matter
the distance.

**Driver**
1. Goes online and sets their zone price, for example 3,000₮
   (it must stay inside the company's allowed range).
2. Gets ride requests near them and accepts the ones they want.
3. Picks up the rider, finishes the trip, and the rider pays the agreed price.

**Rider**
1. Drops a pickup pin and a dropoff pin, or taps a popular place
   (market, hospital, bus station…).
2. Sees the drivers nearby with **their prices**, arrival time and rating.
3. Picks one. The price is locked before the trip, so there is no argument
   at the end.

Trips into the center zone or out of town are not flat: the rider and the
driver agree a price inside the company's tariff for that distance.

### Shugamiin taxi (route taxi)

**Driver**
1. Creates a **line**: the route, the stops, the departure time, the number of
   seats, and **their own price per seat**.
2. Sees who booked which seat and where they get on.
3. Drives the line and picks people up at the stops.

**Rider**
1. Chooses a line (for example from a district to the center).
2. Sees the cars on that line, **each driver's seat price**, seats left and
   arrival time.
3. Books a seat and pays only for that seat. Several riders share one car.

### Rules the app follows (Mongolian law)

- Only taxi companies with a permit can run taxis; drivers join **under a
  company**. The company sets a minimum and maximum price, and drivers choose
  freely **inside** that range. This keeps driver pricing legal.
- Every paid trip gets a receipt (e-barimt) and the agreed price is recorded.
- Cars must be 10 years old or newer.
- Safety: SOS button, share-trip link, driver photo, car plate and rating
  before pickup.

## Status

| Part | State |
| --- | --- |
| Map of Erdenet in Mongolian, 2D/3D, popular places, search | Working (prototype) |
| Zone taxi flat price and center zone | Working (prototype; the zone shapes are placeholders until the real town and center borders are drawn) |
| Price offers inside the company range (offer slider) | Working (prototype, rider side) |
| Road route, distance and time | Working (uses a free test routing server) |
| Drivers setting their own zone price and seeing requests | Not built yet (driver app) |
| Shugamiin taxi: lines, stops, per-seat prices, seat booking | Not built yet (waiting on a legal check about permits for per-seat lines) |
| Login, real booking, payments | Not built yet |

The full plan is in [`docs/ROADMAP.md`](docs/ROADMAP.md), progress in
[`docs/PROGRESS.md`](docs/PROGRESS.md), and the rules for AI coding agents in
[`AGENTS.md`](AGENTS.md).

## Run it on your computer

Install [Flutter](https://docs.flutter.dev/get-started/install) (3.29 or newer)
and Git, then:

```bash
git clone <this repository link>
cd <repository folder>/rider_app
flutter pub get
flutter gen-l10n
flutter run -d chrome
```

For Android, plug in a phone or start an emulator, then run `flutter run`.
Without any setup the app runs in **demo mode** (no server or account needed).

## Development on this Windows PC

Dependencies are already declared in `rider_app/pubspec.yaml`. Use Git Bash;
Flutter is not on PATH:

```bash
F=/c/Users/bayrtbaatar/dev/flutter/bin/flutter
cd /c/Users/bayrtbaatar/Desktop/mgl-cab/rider_app
$F pub get
$F gen-l10n
$F analyze
$F test
```

Run the web app:

```bash
$F run -d web-server --web-port 8090 --web-hostname localhost
```

Open `http://localhost:8090`. Reload a background tab if the map needs repainting.
Run the Android emulator with host graphics (SwiftShader hides map text/icons):

```bash
/c/Users/bayrtbaatar/dev/android-sdk/emulator/emulator -avd mgls_pixel -gpu host
$F devices
$F run -d emulator-5554
```

Use the actual device ID from `$F devices` if different. Choose **No thanks**
on Google's Location Accuracy consent dialog; never accept consent dialogs.
Android builds need a short temporary folder:

```bash
export TEMP='C:\Users\bayrtbaatar\dev\tmp' TMP='C:\Users\bayrtbaatar\dev\tmp'
export JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir=C:\Users\bayrtbaatar\dev\tmp'
$F build apk --debug
```

JDK 21: `C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot` (already configured).
Android SDK: `C:\Users\bayrtbaatar\dev\android-sdk`.
PowerShell equivalents for verification:

```powershell
Set-Location C:/Users/bayrtbaatar/Desktop/mgl-cab/rider_app
& C:/Users/bayrtbaatar/dev/flutter/bin/flutter.bat analyze
& C:/Users/bayrtbaatar/dev/flutter/bin/flutter.bat test
```

## Source map

- `rider_app/lib/core/`: pricing, placeholder tariff/zones, places, OSRM routing,
  money formatting and coordinate conversions.
- `rider_app/lib/data/`: backend configuration, repository interfaces, in-memory
  demo repositories, Supabase adapters and response validation.
- `rider_app/lib/features/booking/`: pure Dart booking state machine, Riverpod 3
  Notifier, `MapAdapter` interface, MapLibre implementation and step widgets.
- `rider_app/lib/theme/`: placeholder brand palette, typography and spacing;
  light/dark themes follow the system setting. Owner must choose brand/logo.
- `rider_app/lib/l10n/`: Mongolian (default) and English ARB sources. Flutter
  generates `AppLocalizations`; generated Dart files are ignored.
- `rider_app/assets/map_style/`: existing OpenFreeMap vector style.
- `rider_app/test/`: pricing, money, routing, places, controller and booking
  widget tests. Widgets use a fake map and route loader, without platform views.
- `supabase/migrations/`, `supabase/seed.sql`: undeployed schema and demo data.
- `docs/ROADMAP.md`, `docs/PROGRESS.md`: acceptance criteria and run log.
- `reference/`: third-party study material; never ship it.

OSRM's public demo endpoint is for development only. Zone boundaries and tariffs
are placeholders. The displayed road distance and priced distance estimate still
differ; server pricing is scheduled later. Dart pricing must stay identical to
SQL `quote_trip`; never bypass tariff limits or disable RLS.

## Search and places (M2)

The search bar opens a full-screen pickup/destination search. Typing filters
the 16 bundled Erdenet landmarks after 350 ms. Popular results appear before
recent results, then online results. Every place has a name, area and kind icon.
Home and Work can be set or replaced from a result or a confirmed map pin.
The last ten unique selections, saved places and location reports persist in
`shared_preferences` on this device/browser. Catalogue names follow the app
language even when selected in the other locale. Clearing app/browser storage
removes this data. No account or network is needed for these local features.

“Location wrong?” opens a note form. The report stores the place, coordinates,
note and UTC timestamp locally. M3 adds signed-in sync with access controls;
guest reports stay on this device. No saved address/report is sent automatically
to a geocoder. The OSM coordinates are approximate building centres, not
verified entrances; use the pin and report flow to correct a pickup.

Online lookup is disabled by default and always disabled in release/profile
builds. For **one local developer instance only**, deliberately opt in:

```bash
$F run -d web-server --web-port 8091 --web-hostname localhost \
  --dart-define=MGLS_DEV_NOMINATIM=true
```

Read the [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/).
The public server forbids autocomplete. Typing never calls it: submit with
**Search online** or the keyboard search action. Requests are serialized with
at least one second between starts, including failures, and normalized queries
are cached in memory (100 query/locale pairs) for this app session. Native HTTP
uses `MGLS-Erdenet-Dev/0.1`; web requests use the browser's User-Agent/Referer.
Only Erdenet-bounded results with a name and area are shown. Attribution remains
visible. Failures leave the offline catalogue and map available.

The public service's traffic cap applies across the entire application, not
per phone. Do not enable this flag for multiple users or deploy it. The owner
must choose self-hosted Photon or a paid production geocoder with a shared
rate-limiting/caching proxy and a way to disable/switch providers. The injectable
`Geocoder` interface isolates that replacement. Local storage stays independent.

M2 tests include mocked HTTP timing, cache/failure behavior, storage reloads,
offline search/booking, and Mongolian/English layouts at 320 dp, 1.3× text in
both themes. Optional Windows visual captures use the installed Flutter fonts:

```bash
$F test test/place_search_widget_test.dart --dart-define=MGLS_CAPTURE=true
```

Images are written to the ignored `screenshots/m2_*.png` paths. No font assets
are copied into the app. See `docs/M2_CHECKS.md` for the acceptance evidence.

## Backend connection (M3)

**Status:** implementation is ready for an owner-provided test project. Live
Supabase and SQL/PostGIS checks remain unverified until the owner supplies the
project and runs the database checks. See `docs/M3_CHECKS.md` for the exact steps.

With both configuration values absent, the app uses in-memory RideRepository,
ZoneRepository and PlaceRepository implementations. Demo quotes use only the
placeholder zones/tariff in `core/config.dart`; local Home/Work/recents/reports
still persist through shared_preferences. A demo notice stays visible.

To connect a **development/test** Supabase project, apply migrations `0001` then
`0002` in order. It needs fare zones and at least one approved company with a
current taxi permit and tariff. `seed.sql` supplies fictional data only for an
isolated test project; never seed a production service with fake permits.
No project or accounts are created by the app. Login is M4; booking is M5.

Supply configuration at build/run time, using the full Flutter command path:

```bash
$F run -d web-server --web-port 8091 --web-hostname localhost \
  --dart-define=SUPABASE_URL=<project-url> \
  --dart-define=SUPABASE_ANON_KEY=<public-anon-or-publishable-key>
```

Replace the angle-bracket placeholders; they are not shell arguments to paste
literally. Prefer an ignored `rider_app/env/local.json` to avoid shell history:

```json
{"SUPABASE_URL":"","SUPABASE_ANON_KEY":""}
```

Fill both values locally, then use `$F run ... --dart-define-from-file=env/local.json`.
The root ignore rules cover `env/*.json` at every level. Never commit credentials
or supply a service_role/secret key: client keys are public capabilities protected
by RLS, not administrative secrets. The config guard rejects secret/service-role
keys, partial config, and non-HTTPS remote URLs. It cannot remove a secret someone
already passed to the compiler. Local Supabase HTTP is allowed only on localhost,
127.0.0.1 or the Android emulator's 10.0.2.2 host bridge.

Configured builds load fare zones, holes and approved company tariffs through
`fare_catalog`, and **always** request their quote from `fare_quote`. Both RPCs
work before login and expose only a public fare subset. Base tables remain
private. There is no client-price fallback if credentials, migrations or the
network are wrong. The UI shows loading/error/retry states, allows selecting a
company, and clears a previous quote/offer while repricing. Late responses after
restart/disposal are ignored. Map fare overlays use the loaded zones too.

Server fares remain the M1 straight-line estimate (WGS84 ×1.3, rounded once to
the metre), not an OSRM-priced road route. M3 coordinates boundary/rounding rules
and adds shared SQL/Dart fixtures; server-side road routing remains M5. Configured
builds only preview fares and never falsely claim a real ride was created.

Signed-in place sync uses `saved_places` and append-only `place_reports`, each
with owner-only RLS. Each signed-in user has separate local storage. Guest data
is not automatically uploaded on login, and recents remain device-local. Local
drafts win over fetched saved places until explicitly synced. Server outages keep
the local save and show a pending status with a retry action. Report retries use
a stable client ID to avoid duplicate reports. M4 will provide the login UI; M3
does not anonymously sign users up. See the database README for grants and tests.

For M3 visual QA on this Windows PC:

```bash
$F test test/backend_widget_test.dart --dart-define=MGLS_CAPTURE=true
```

This writes ignored `screenshots/m3_{light,dark}_{loading,error,quote,sync_pending,sync_ready}.png`.
Tests load installed Flutter fonts plus the Windows Arial fallback for ₮; no
fonts are copied or system settings changed. The map retains its existing light
style while all UI surfaces follow light/dark mode.

OpenStreetMap data is © OpenStreetMap contributors (ODbL); keep map attribution
visible. Secrets belong in ignored env files or `--dart-define`, and a Supabase
service-role key must never go into an app.
