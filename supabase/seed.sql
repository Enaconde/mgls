-- DEMO ONLY: approximate Erdenet polygons, registration and permit identifiers.
-- Replace these placeholders with surveyed boundaries and verified company data.
-- No auth users or real driver/rider accounts are created by this seed.
BEGIN;

DO $$
DECLARE spatial_schema text;
BEGIN
  SELECT n.nspname INTO spatial_schema FROM pg_extension e
    JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'postgis';
  IF spatial_schema IS NULL THEN RAISE EXCEPTION 'Apply migrations/0001_init.sql first'; END IF;
  PERFORM set_config('search_path', format('public, %I', spatial_schema), true);
END;
$$;

INSERT INTO public.companies
  (id, name, register_number, taxi_permit_number, permit_expires_on, status)
VALUES
  ('11111111-1111-4111-8111-111111111111', 'Erdenet Demo Taxi', 'DEMO-REGISTER-001',
   'DEMO-TAXI-PERMIT-001', DATE '2035-12-31', 'approved')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, register_number = EXCLUDED.register_number,
  taxi_permit_number = EXCLUDED.taxi_permit_number,
  permit_expires_on = EXCLUDED.permit_expires_on, status = EXCLUDED.status;

INSERT INTO public.company_tariffs (company_id, base_fare_mnt, min_per_km_mnt, max_per_km_mnt)
VALUES ('11111111-1111-4111-8111-111111111111', 1000, 1000, 2000)
ON CONFLICT (company_id) DO UPDATE SET
  base_fare_mnt = EXCLUDED.base_fare_mnt,
  min_per_km_mnt = EXCLUDED.min_per_km_mnt, max_per_km_mnt = EXCLUDED.max_per_km_mnt;

-- WKT uses longitude latitude. These rectangles are NOT official fare boundaries.
-- Keep them identical to fareZones in rider_app/lib/config.dart until the app
-- loads zones from this table.
-- Approximate town envelope, including the center; both endpoints must be inside.
INSERT INTO public.fare_zones (id, town, kind, area, flat_price_mnt)
VALUES
  ('22222222-2222-4222-8222-222222222222', 'Erdenet', 'town',
   ST_GeogFromText('SRID=4326;POLYGON((104.0230 49.0030,104.1430 49.0030,104.1430 49.0630,104.0230 49.0630,104.0230 49.0030))'),
   3000),
  -- Approximate center exclusion: either endpoint inside it uses the normal tariff.
  ('33333333-3333-4333-8333-333333333333', 'Erdenet', 'center',
   ST_GeogFromText('SRID=4326;POLYGON((104.0420 49.0220,104.0660 49.0220,104.0660 49.0380,104.0420 49.0380,104.0420 49.0220))'),
   NULL)
ON CONFLICT (id) DO UPDATE SET
  town = EXCLUDED.town, kind = EXCLUDED.kind,
  area = EXCLUDED.area, flat_price_mnt = EXCLUDED.flat_price_mnt;

COMMIT;
