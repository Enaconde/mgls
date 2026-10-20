# MGLS roadmap: from prototype to a polished product

Work top to bottom. Each milestone lists **Build**, **Done when** and
**Needs owner** (things only the owner can do: accounts, money, legal
answers, real phones). Never skip "Done when".

Status today (2026-10-20): the rider flow works on web and the Android
emulator: Amap-style MapLibre map, pickup and dropoff, popular places,
road route, flat fare or offer slider. No backend, login, driver app or
payments yet.

---

## M1 — Foundation (no accounts needed)

**Build**
- Root `.gitignore`: `build/`, `.dart_tool/`, `*.env`, `env/*.json`,
  `android/key.properties`, `*.jks`, `*.keystore`, `.codex-*`, `screenshots/`.
- Root `README.md`: what MGLS is, how to run web/emulator/tests (copy the
  commands from AGENTS.md), folder map.
- Restructure `rider_app/lib/`:
  - `core/`: `pricing.dart`, `config.dart`, `places.dart`, `routing.dart`,
    `money.dart` (move `formatMnt` here), `geo.dart` (LatLng conversions).
  - `features/booking/`: split `rider_map_screen.dart` into small widgets:
    map view, center pin, map controls (3D, locate), pickup step,
    dropoff step with popular places, price card.
  - `theme/`: colors, typography, spacing, light **and** dark theme.
- State: add `flutter_riverpod`. Move booking logic into a pure Dart
  `BookingController` (state machine: pickup → dropoff → review → requested)
  with no Flutter or map imports, fully unit-tested.
- Hide the map behind an interface (`MapAdapter`) so widget tests can use a
  fake map; MapLibre platform views do not run in tests.
- Localization with `flutter gen-l10n`: `app_mn.arb` (default) and
  `app_en.arb`. No hard-coded user text left in widgets.
- Design system: replace the amber seed with a placeholder brand palette
  (clearly marked "placeholder, owner to choose"). One button style, one card
  style, 8-pt spacing, rounded 16 cards, consistent icon sizes.
- Accessibility: semantics labels on icon buttons, tap targets ≥ 48 dp,
  layout survives 1.3× text scale.

**Done when**
- `flutter analyze` clean, `flutter test` green, tests cover
  `BookingController` transitions, pricing edge cases (zone edges, rounding),
  money formatting and one widget test per booking step with the fake map.
- The app looks and behaves the same or better on web and on the emulator.
- No user-facing string outside the ARB files.

**Needs owner:** brand colour and logo (placeholder until then).

---

## M2 — Search and places

**Build**
- Amap-style search bar at the top: tap to open a full-screen search.
- Results: popular places first, then recent places, then geocoder results.
  Each row: bold name, grey area line, icon by kind.
- Geocoder behind an interface. Dev implementation: Nominatim
  (`nominatim.openstreetmap.org`) with a proper User-Agent, max 1 request per
  second, debounced typing, results cached. Mark it **dev only**: its policy
  forbids heavy autocomplete use.
- Saved Home and Work (local storage, `shared_preferences`), recent places
  (last 10), "Set on map" row.
- "Location wrong?" report button that stores a report locally now and in the
  database after M3.
- Bigger popular places list for Erdenet (markets, hospitals, schools,
  government, stations, big shops), each with an OSM source comment.

**Done when** search works offline for popular/saved/recent places, the
geocoder never fires more than once a second (test it), and every result
row has name + area.

**Needs owner:** later, a production geocoder (self-hosted Photon or a paid
API) — note it in PROGRESS.md.

---

## M3 — Backend connection

**Build**
- `supabase_flutter`; config from `--dart-define=SUPABASE_URL=...` and
  `SUPABASE_ANON_KEY=...` (never commit them; document in README).
- Repository layer (`RideRepository`, `ZoneRepository`, `PlaceRepository`)
  with in-memory fakes used by tests and by a "demo mode" when no keys are set.
- Load fare zones and tariffs from the database; `config.dart` becomes the
  demo-mode fallback only.
- Migration `0002_*.sql` for anything new (place reports, saved places sync),
  each table with RLS.
- SQL tests (pgTAP or a SQL script with asserts) for `quote_trip`: the same
  cases as the Dart pricing tests must give the same numbers.

**Done when** the app runs in demo mode with no keys, and with keys it reads
zones and quotes from Supabase; pricing parity test passes.

**Needs owner:** create a free Supabase project and pass URL + anon key;
approve installing the Supabase CLI (and Docker, if local Supabase is wanted).

---

## M4 — Login and profiles

**Build**
- Phone-number login with SMS one-time code (Supabase Auth phone provider).
- Dev-only test numbers/codes so development needs no real SMS.
- First-run flow: language, consent to terms + privacy (Mongolian), name.
- Profile screen: name, phone, saved places, delete-account request.

**Done when** a new user can sign up, log out, log back in; RLS stops one
user reading another's profile (tested).

**Needs owner:** choose and pay an SMS provider that delivers to Mongolian
numbers (international like Twilio, or a local Mongolian SMS gateway via a
Supabase SMS hook); privacy policy and terms text reviewed by a lawyer.

---

## M5 — Ride lifecycle (rider side)

**Build**
- Server-side route + price: a Supabase Edge Function gets the road route
  (OSRM), stores road distance, and prices from it. The client only shows
  quotes. This fixes "shown 4.7 km, priced as 5.5 km".
- Create ride → realtime status (requested, offered, accepted, arriving,
  in progress, completed, cancelled).
- Offers screen: driver counter-offers listed with price, arrival time,
  rating, car; rider accepts one. Offer expiry timer. "Raise your offer" hint
  when nobody takes it.
- Live driver position on the map during pickup and trip, with ETA.
- Trip screen: driver photo, name, car, **plate**, rating, call (masked later),
  share trip, SOS.
- Completion: price summary, payment method (cash for now), rating + comment.
- Cancel rules and reasons; no-show handling.
- Ride history screen.

**Done when** two test accounts (rider + a driver simulated by a script or
the M6 app) complete a whole ride end to end; every state change is visible
in realtime; prices never leave the tariff range (database rejects it, tested).

**Needs owner:** none beyond M3–M4.

---

## M6 — Driver app

**Build**
- Monorepo: `packages/mgls_core` (models, pricing, money, map style, theme,
  l10n shared), `rider_app`, new `driver_app`.
- Driver onboarding: belongs to an approved company; documents uploaded
  (licence, ID, car photos) to Supabase Storage for company review.
- Go online/offline; background location with an Android foreground service
  and a visible notification; battery-friendly update rate.
- Incoming requests list and sound; accept or counter inside the range;
  navigation hand-off to Google Maps / Maps.me / OsmAnd.
- Trip states: arrived, started (PIN check), completed; earnings; wallet
  balance and commission history.
- Push notifications for requests (Firebase Cloud Messaging).

**Done when** a driver on the emulator receives a ride from the rider app on
web, counters, wins, and completes it; going offline stops location updates.

**Needs owner:** Firebase project for push; Google Play policy declaration for
background location (needs a short video and justification at release).

---

## M7 — Company portal and admin (Flutter web)

**Build**
- Company: sign-up with permit number, expiry, register number, documents;
  add drivers and cars; set tariff (min/max per km, base); see trips,
  earnings, payouts; reports to download.
- Admin (MGLS team): approve/suspend companies and drivers, check permit
  expiry, draw and edit fare zones on a map (polygon editor), live map of
  online drivers and active trips, complaints, refunds.
- Audit log of admin actions.

**Done when** a company can onboard and be approved without SQL, and an admin
can redraw a zone and see prices change in the rider app.

**Needs owner:** the real Erdenet town and center boundaries; first 1–2
partner taxi companies.

---

## M8 — Payments

**Build**
- Cash rides: commission taken from the driver's prepaid wallet at pickup.
- Wallet top-up via QPay (invoice + QR + bank deep links; webhook verified on
  the server).
- Rider payment by QPay for the ride.
- e-barimt receipt for each paid ride (store the receipt id).
- Refunds, reconciliation report, negative-balance rules (driver goes offline).
- All money logic on the server; clients never decide amounts.

**Done when** sandbox QPay payments and webhooks work end to end; ledger
always balances (tested).

**Needs owner:** QPay merchant account; e-barimt registration; decide
commission (research suggests 10–15% normal, fixed fee on 3,000₮ rides).

---

## M9 — Safety and trust

**Build**
- SOS button: calls Mongolian emergency numbers (verify the current numbers
  before shipping) and sends the trip to the MGLS team and trusted contacts.
- Share-trip web link with live position, ends when the trip ends.
- Masked phone calls / in-app chat.
- Driver selfie check against the profile photo before going online.
- Report / block driver or rider; women-riders-with-women-drivers option.
- Trip anomaly alerts (long stop, big route change).

**Done when** each feature has a test or a written manual test script that
passes on the emulator.

**Needs owner:** telephony provider for masked calls; 24/7 safety contact.

---

## M10 — Route taxi (feature flag, off by default)

**Build** lines with stops and times, seat booking, seats-left count,
per-seat price inside a range, driver line management.

**Done when** works with the flag on and is invisible with it off.

**Needs owner:** legal answer on whether per-seat lines need a permit.

---

## M11 — Production infrastructure

**Build**
- Own OSRM server with the Mongolia extract (Geofabrik), updated monthly.
- Map tiles: stay on OpenFreeMap or self-host a Mongolia PMTiles file;
  cache tiles in the app.
- Crash reporting (Sentry or Firebase Crashlytics), privacy-friendly analytics.
- Monitoring, database backups, rate limits on Edge Functions, abuse limits
  (offer spam, fake accounts).
- Security review of every RLS policy and Edge Function; secrets rotation.
- Load test: 500 online drivers, 50 rides per minute.

**Done when** the app runs with no demo or dev-only servers, and a written
runbook covers outages.

**Needs owner:** a small server or cloud account and its monthly cost.

---

## M12 — Polish and release

**Polished means:**
- Every screen has loading, empty, error and no-internet states.
- Smooth: 60 fps map, cold start under 2 s on a mid-range Android phone,
  APK under 40 MB.
- Mongolian copy reviewed by a native speaker; consistent tone; ₮ everywhere.
- Dark mode, text scaling, screen-reader labels.
- App icon, splash screen, store screenshots, short promo text.
- Privacy policy and terms in Mongolian, linked in the app and the store.

**Release steps:** signing key stored safely (not in git), versioning,
internal test track with 1–2 Erdenet companies, fix feedback, then public
Play Store release. iOS after Android.

**Needs owner:** Google Play developer account (one-time ~$25), Apple
developer account (~$99/year) and a Mac or cloud build service for iOS,
company/legal entity details for the store listing.

---

## Things to watch out for (whole project)

- **Law first:** permits, tariff range, e-barimt, personal data. When unsure,
  stop and ask the owner.
- **Safety in shared and night rides:** DiDi Hitch was suspended after two
  murders; never ship rides without SOS, share-trip and driver checks.
- **Competition:** UBCab (16 provinces), QGO (bargaining, shared rides),
  state-backed Hotula. Win on low commission, flat fares and small towns.
- **Cash:** most rides are cash; the wallet/commission model must work offline.
- **Weak addresses:** many places have no address; pins, landmarks, saved
  places and "Set on map" matter more than street search.
- **Cold and poor networks:** Mongolian winters and weak signal; handle
  offline gracefully, keep data use small.
- **Free dev services** (OSRM demo, Nominatim, Supabase free tier) have usage
  limits; replace before launch.
- **Do not copy competitors' code or assets.** Study as a user only.
