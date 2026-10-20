# MGLS — instructions for coding agents

Read this whole file, then `docs/ROADMAP.md`, then the newest entries of
`docs/PROGRESS.md` before you change anything.

## The product

MGLS is a taxi "connector" app for Mongolia, starting in **Erdenet**.
Permit-holding taxi companies sign up and bring their cars and drivers;
riders book through one app. Three ride types:

1. **Normal taxi** — rider and driver agree a price, but only inside the
   company's min–max tariff range (inDrive-style offers and counters).
2. **Flat-fare town taxi** — 3,000₮ for any trip that starts and ends inside
   the town zone, unless either end is inside the center zone.
3. **Shugamiin (route) taxi** — fixed line, riders book seats. Legal status
   unclear: build behind a feature flag, off by default.

Background research (market, law, DiDi/inDrive/Uber/Amap notes):
https://claude.ai/code/artifact/45100d65-0836-4085-8c14-e92590bf850c

## Repository map

| Path | What it is |
| --- | --- |
| `rider_app/` | Flutter rider app (Android, iOS, web). Package name `rider_app`, display name MGLS. |
| `rider_app/lib/core/pricing.dart` | Fare quote: flat zones, tariff range, rounding. Must match SQL `quote_trip`. |
| `rider_app/lib/core/config.dart` | Placeholder fare zones and tariff (Erdenet). |
| `rider_app/lib/core/places.dart` | Popular Erdenet places (coordinates from OpenStreetMap). |
| `rider_app/lib/core/routing.dart` | Road routes from OSRM. |
| `rider_app/lib/features/booking/` | Booking state machine, Riverpod provider, map adapter and step widgets. |
| `rider_app/assets/map_style/mgls_light.json` | MapLibre style (Amap-like), OpenFreeMap tiles. |
| `supabase/migrations/0001_init.sql` | Database: tables, RLS, `quote_trip`, `nearby_drivers`, triggers. |
| `supabase/seed.sql` | Demo company, tariff and zones (zones must equal `config.dart`). |
| `reference/` | Third-party reference files. Never ship them. |
| `docs/ROADMAP.md` | Milestones and acceptance criteria. Work in this order. |
| `docs/PROGRESS.md` | Log you append to after every run. |

## How to work

- Do **one milestone (or one clearly named part of one) per run**. Read its
  acceptance criteria in `docs/ROADMAP.md` first.
- Keep it green: `flutter analyze` must report no issues and `flutter test`
  must pass before you finish. Add tests for every pure function and for
  every new screen's key states.
- Small, readable code that matches what is there. Comments explain *why*.
- All user-facing text is **Mongolian (Cyrillic)**, kept in localization files
  (see M1), with English as the second locale. Money is whole tugrik, shown
  as `12,500₮`.
- When something needs the owner (an account, money, a legal answer, a
  real phone), **stop that part**, write it under "Blocked on owner" in
  `docs/PROGRESS.md`, and continue with work that is not blocked.
- Finish every run by appending to `docs/PROGRESS.md`: date, milestone, what
  changed, how you verified it, what is left, what is blocked.
- Do not run `git push`, do not create accounts, do not change Windows or
  system settings, do not install system software. Ask in PROGRESS.md.

## Commands on this PC (Windows, Git Bash)

Flutter is **not on PATH**. Use the full path:

```bash
F=/c/Users/bayrtbaatar/dev/flutter/bin/flutter
cd /c/Users/bayrtbaatar/Desktop/mgl-cab/rider_app
$F analyze
$F test
```

Android builds need a short temp folder, or Gradle fails with
"Unable to establish loopback connection":

```bash
export TEMP='C:\Users\bayrtbaatar\dev\tmp' TMP='C:\Users\bayrtbaatar\dev\tmp'
export JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir=C:\Users\bayrtbaatar\dev\tmp'
$F build apk --debug
```

- JDK 21: `C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot` (Flutter is configured to use it).
- Android SDK: `C:\Users\bayrtbaatar\dev\android-sdk`; emulator AVD `mgls_pixel`.
- Start the emulator with `-gpu host`. With software graphics (SwiftShader)
  MapLibre draws no text or icons, which looks like a bug but is not.
- The emulator shows Google's "Location Accuracy" consent dialog on each app
  start. Choose "No thanks"; never accept consent dialogs.
- Web dev server: `$F run -d web-server --web-port 8090 --web-hostname localhost`.
  In a hidden or background browser tab the MapLibre map can stay blank
  until it is repainted; reload before calling it broken.
- Python is not installed. Node.js 24 is.

## Rules that must never break

**Law (Mongolia, Motor Transport Law amendment of 7 Dec 2023, in force 15 Oct 2024):**
- Only permit-holding legal entities may run taxis. Individual drivers join
  **under a company**; never let a driver operate without an approved company.
- Company onboarding records permit number + expiry, register number, tax
  status. Expired permit = company and its drivers go offline automatically.
- Cars no older than 10 years (enforced by trigger; keep it).
- Taxi permits require a device that checks the set tariff (art. 15.10): the
  app's agreed price must always stay within the company's tariff range and be
  recorded on the ride. Never allow free pricing outside the range.
- e-barimt receipts (art. 15.9.8): every completed paid ride needs a receipt
  record. Integration may come later, but keep the field and flow.
- Route taxis (shugam) stay behind a feature flag until the owner confirms the
  permit question.

**Pricing:**
- `rider_app/lib/core/pricing.dart` and SQL `quote_trip` must give identical
  numbers: road distance = straight line × 1.3 rounded to the metre, prices
  rounded to the nearest 100₮, flat fare when both ends are in the same town
  zone and neither is in a center zone. Change both together, with tests.
- The server is the source of truth for prices. Clients display quotes; the
  database recomputes and enforces them (trigger `prepare_ride`, offer check).

**Security and privacy:**
- Never commit secrets. Keys come from `--dart-define` or env files listed in
  `.gitignore`. The Supabase **service_role key never goes into an app**.
- Row Level Security stays on for every table. Any new table gets RLS and
  policies in the same migration, plus a test or a written check.
- Collect only needed personal data. Mongolia's Law on Personal Data
  Protection applies: consent screen, privacy policy, data deletion request.
- Mask phone numbers between rider and driver.

**Safety features are required, not optional:** SOS, share-trip link, driver
photo + plate + rating before pickup, ride PIN or plate check, trip anomaly
alerts later.

**Copyright:** study other apps only as a user. Never copy code, icons,
images, styles or text from DiDi, Uber, Amap, QGO, UBCab or inDrive. Map data
is OpenStreetMap (ODbL): keep the attribution visible.

## Known technical traps

- `maplibre_gl` has its own `LatLng`; the app's logic uses `latlong2`'s.
  Import MapLibre as `ml` and convert with `_ml()`.
- Map tiles: OpenFreeMap (free, no key). Do not reintroduce CARTO (needs a key
  now) or raster tiles.
- Routing: `router.project-osrm.org` is a **demo server for development only**.
  Production needs our own OSRM (Mongolia extract) or a paid API — see M11.
- The style uses `["coalesce", ["get","name:mn"], ["get","name"], ...]`;
  `name:mn` is usually absent but `name` is Mongolian in Mongolia, which is fine.
- Fitting the camera to bounds resets tilt to 0; keep the 3D button state in sync.
- Map stop icons are PNGs drawn at 44px: scale by device pixel ratio on
  phones (`_iconScale`).
- Fare zones in `config.dart` and `seed.sql` are **placeholders**; real
  boundaries must come from the owner. Load zones from the database in M4.
- Shown distance (OSRM road distance) and priced distance (×1.3 estimate)
  differ. Fix in M4 by pricing on the server from a server-side route.
