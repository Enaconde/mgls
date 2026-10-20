# Mongolian taxi connector database

Supabase / PostgreSQL 15 with PostGIS. Money is integer MNT, timestamps are
`timestamptz`, and geography coordinates use SRID 4326. PostGIS points/WKT use
**longitude, latitude**; the RPC arguments use **latitude, longitude**.

## Tables

- `profiles`: auth user identity, role, name and unique phone. New client-created profiles are riders.
- `companies`: registration, required taxi permit, permit expiry and approval status.
- `company_admins`: company-to-profile administration memberships.
- `company_tariffs`: company base fare and inclusive minimum/maximum per-kilometre rates.
- `drivers`: company membership, licence, approval, rating and wallet balance.
- `vehicles`: company vehicles, optional driver assignment, plate and capacity. A trigger enforces the ten-year age limit on inserts/updates; next model year is allowed.
- `driver_locations`: latest driver position, heading, online state and server-stamped update time, with a GiST spatial index.
- `fare_zones`: town flat-fare polygons and center exclusions, with a GiST spatial index.
- `rides`: rider trip, company, estimated distance, price bounds, assignment and lifecycle timestamps.
- `ride_offers`: rider offers and driver counteroffers. A trigger checks inclusive ride price bounds; counteroffers must come from the quoted company.
- `route_lines`: shugamiin taxi paths, JSON stop arrays, departure time and per-seat price.
- `route_bookings`: passenger seat requests; status is `pending`, `confirmed`, `cancelled` or `completed`.
- `payments`: ride payment amount, commission, cash/QPay method, invoice, ebarimt reference and paid time.
- `saved_places` (0002): each signed-in user's Home/Work JSON snapshot; server-stamped update time.
- `place_reports` (0002): append-only corrections, coordinates/place snapshot, client and receipt timestamps; stable IDs make retries idempotent.

## Functions and pricing

- `nearby_drivers(lat, lng, radius_m default 3000)`: online, approved drivers from approved companies with current permits, ordered by distance in metres. Uses indexed `ST_DWithin` filtering and `ST_Distance`; returns driver/company IDs, location, heading, distance and update time. Callers should use `updated_at` to detect stale locations.
- `quote_trip(p_lat, p_lng, d_lat, d_lng, p_company)`: returns `ride_type`, suggested price, minimum price and maximum price. Requires an approved company with a current permit and tariff.
- `fare_catalog()` (0002): public JSON subset of zones/GeoJSON polygons and current approved company names/tariffs. No private registration, permit, profile or driver fields.
- `fare_quote(...)` (0002): public quote preview wrapper with the same arguments as quote_trip; adds estimated `distance_m`. It still requires an approved company with current permit/tariff.
- `is_admin()`, `is_company_admin(company_id)`, `is_approved_driver(driver_id)` and `is_route_operator(route_line_id)`: RLS helpers with fixed search paths that avoid policy recursion; company membership alone does not grant a role.
- Trigger functions `check_company_permit()`, `check_vehicle_age()`, `stamp_driver_location()`, `prepare_ride()` and `check_ride_offer()` enforce permit/age rules, timestamps, ride pricing/transitions and offer bounds.

A flat fare applies when both endpoints are covered by the **same** priced town
polygon and neither is covered by any center polygon. M3 uses planar longitude/
latitude polygon edges in both Dart and SQL (`ST_Covers(area::geometry,point)`),
including outer and hole boundaries; hole interiors are outside. Overlapping
towns choose the smallest planar area, then UUID. Flat suggested/min/max
prices are all the zone price (3000 MNT in the seed).

Otherwise, estimated road distance is `round(unrounded_WGS84_metres * 1.3)`.
The minimum/maximum fare is `round((base + distance_m / 1000 * rate) / 100) * 100`;
the suggested fare is `round((min + max) / 2 / 100) * 100`. Positive half ties
round upward. Dart now avoids its old intermediate straight-metre rounding.
This is an estimate, not road routing. M5 will price actual server-side routes.
Rides store a quote snapshot: changing tariffs later does not change existing offers.
Ordinary ride inserts calculate their own bounds; fares/endpoints/company freeze
once offers exist. Agreed prices must also be inside the stored bounds.
Route-line fares use `seat_price_mnt`; the quote RPC returns only `normal` or `flat`.

## Access and backend responsibilities

RLS is enabled on every table. Authenticated riders see their rides/bookings and
related offers/payments; approved drivers see open rides for their company and
their assigned rides. Company admins see company data; platform admins see all.
Anonymous access is limited to the two explicit fare preview RPCs from 0002;
no anonymous base-table access is granted. The authenticated nearby-driver RPC
intentionally exposes online positions without exposing licence or wallet data.

Column grants let clients create/edit their own rider profile, publish their own
driver location, request a ride, make an offer, request seats and cancel pending
requests. Clients cannot change roles, memberships, approvals, tariffs, wallets,
assignments, offer status or payments. Perform those writes in a trusted backend
using `service_role`, after checking the caller's role and company membership.
Never expose the service key to a client. Create auth users through Supabase Auth;
then provision driver/admin profiles, memberships and records from that backend.

The two new tables have owner-only SELECT/INSERT policies; saved places also
allow an owner-only UPDATE with a WITH CHECK preventing owner transfer. Reports
have no client UPDATE/DELETE grant or policy. Clients cannot choose server
timestamps. Their compound primary keys begin with owner_id and serve owner
queries; reports use `(owner_id,client_id)` to deduplicate offline retries.
These tables reference auth.users directly, so sync does not require a profile
row before M4. Neither migration creates an Auth account.

The backend must accept an offer and assign the matching driver/vehicle in one
transaction with the ride row locked, update competing offers, and confirm route
bookings with a route-row lock and capacity check. Pending bookings are requests,
not reserved seats. Verify QPay callbacks and issue ebarimt receipts externally;
these tables store their references. Aging vehicles/expiring permits need periodic
operational review; vehicle triggers run when rows are written.

## Apply with the Supabase CLI

These files belong in the project's `supabase/` directory. From its parent directory:

```sh
supabase init     # Only if supabase/config.toml does not already exist.
supabase start
supabase db reset
```

`db reset` recreates the **local** database, applies migrations in numeric order,
then runs `seed.sql`. It deletes existing local data. Ensure the CLI configuration
contains this seed configuration (normally generated by `supabase init`):

```toml
[db.seed]
enabled = true
sql_paths = ["./seed.sql"]
```

To apply pending migrations to an existing running local database without resetting
it, use `supabase migration up --local`. Use `supabase db push` for an already
linked remote project; demo seed data should stay local.

Apply 0001 then 0002 once, in order. Do not reapply 0001 over 0002: it would
replace the coordinated quote function with the prototype version. The seed
uses fixed IDs with upserts and is for isolated development databases only.
Later schema changes need new migrations.
The migration requires the Supabase `auth` schema and `anon`, `authenticated`,
`service_role` roles, and a trusted owner able to create PostGIS and definer
functions. It preserves PostGIS's installed schema and removes untrusted CREATE
privileges there to secure spatial function resolution.

The seed has an approved **demo** company (ID
`11111111-1111-4111-8111-111111111111`), base fare 1000, rates 1000–2000 MNT/km,
and a 3000 MNT flat fare. Its permit/registration and approximate Erdenet polygons
are placeholders, not verified credentials or official boundaries.

Example after applying migration and seed, from the local SQL editor:

```sql
-- Flat: both endpoints are in the town, outside the center.
SELECT * FROM public.quote_trip(49.010, 104.040, 49.010, 104.130,
  '11111111-1111-4111-8111-111111111111');
-- Normal: pickup is in the center exclusion.
SELECT * FROM public.quote_trip(49.0309, 104.0542, 49.010, 104.040,
  '11111111-1111-4111-8111-111111111111');
```

## M3 tests and written access check

SQL execution requires an owner-provided Supabase/PostGIS test database. No
database tools were installed by the M3 implementation run. These scripts have
not been claimed as executed; see PROGRESS.md for the remaining verification.
Only run on a **disposable** database with migrations 0001 and 0002 applied:

```sh
psql -X -v ON_ERROR_STOP=1 -f supabase/tests/pricing_parity.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/tests/backend_access.sql
```

Configure the test connection outside the repository through standard libpq
environment configuration; do not put a database password in these files or
paste it in chat. SQL Editor can also execute each full script. Both scripts
use a transaction and ROLLBACK; ON_ERROR_STOP makes psql fail on an assertion.
The pricing script temporarily replaces zones inside its rolled-back test
transaction, so it must not be used against a live service.

`pricing_parity.sql` contains the canonical 46-case JSON fixture. Flutter's
`pricing_parity_test.dart` reads that exact JSON and checks integer type/distance/
min/max/suggested values. SQL checks quote_trip and fare_quote against those
same expectations. It also rejects invalid coordinates, missing companies and
suspended companies. `rider_app/tool/pricing_fixture.dart` prints candidate fixture
data for explicit review; never regenerate expectations merely to hide a failing
parity test. Actual PostGIS execution is needed before accepting pricing parity.

The written RLS/grant review and `backend_access.sql` cover:

- RLS enabled on both new tables in the same migration that creates them.
- Anonymous callers can call fare RPCs, cannot read private tables, and receive
  no registration, permit or phone fields from the catalogue.
- Authenticated A can write/read A's saved places/reports; B cannot read, write
  or transfer A's saved places. Notes/coordinates are checked on the server.
- Report retry is idempotent; clients cannot edit/delete reports or spoof
  server timestamps. Auth deletion cascades the owner's rows.
- Existing ride pricing, offer-range and vehicle-age triggers remain enabled.
- Spatial SECURITY DEFINER functions use only pg_catalog, the trusted installed
  PostGIS schema, and pg_temp; public table references are fully qualified.

The access script uses synthetic auth rows entirely inside ROLLBACK, without
external signup, messaging, real phones or permanent account creation.
