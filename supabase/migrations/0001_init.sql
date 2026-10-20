-- Supabase / PostgreSQL 15. All monetary values are whole Mongolian tugrik (MNT).
-- Re-runnable for this schema: existing tables/types are retained, while functions,
-- triggers and policies are replaced. Later schema changes need new migrations.
BEGIN;

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

-- Respect an existing PostGIS installation, including one in public.
DO $$
DECLARE spatial_schema text;
BEGIN
  SELECT n.nspname INTO spatial_schema
  FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace
  WHERE e.extname = 'postgis';
  PERFORM set_config('search_path', format('public, %I', spatial_schema), true);
  -- SECURITY DEFINER spatial functions must only search trusted schemas.
  EXECUTE format('REVOKE CREATE ON SCHEMA %I FROM PUBLIC, anon, authenticated', spatial_schema);
END;
$$;

DO $$ BEGIN
  CREATE TYPE public.user_role AS ENUM ('rider', 'driver', 'company_admin', 'admin');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE public.ride_type AS ENUM ('normal', 'flat', 'route');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE public.ride_status AS ENUM
    ('requested', 'offered', 'accepted', 'arriving', 'in_progress', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE public.offer_kind AS ENUM ('rider_offer', 'driver_counter');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE public.offer_status AS ENUM ('pending', 'accepted', 'rejected', 'expired');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE public.account_status AS ENUM ('pending', 'approved', 'suspended');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE public.payment_method AS ENUM ('qpay', 'cash');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.user_role NOT NULL DEFAULT 'rider',
  full_name text NOT NULL CHECK (btrim(full_name) <> ''),
  phone text UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (btrim(name) <> ''),
  register_number text NOT NULL UNIQUE CHECK (btrim(register_number) <> ''),
  -- A company must supply its taxi permit before operating.
  taxi_permit_number text NOT NULL CHECK (btrim(taxi_permit_number) <> ''),
  permit_expires_on date NOT NULL,
  status public.account_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.company_admins (
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (company_id, profile_id)
);
CREATE INDEX IF NOT EXISTS company_admins_profile_idx ON public.company_admins(profile_id);

CREATE TABLE IF NOT EXISTS public.company_tariffs (
  company_id uuid PRIMARY KEY REFERENCES public.companies(id) ON DELETE CASCADE,
  base_fare_mnt integer NOT NULL CHECK (base_fare_mnt >= 0),
  min_per_km_mnt integer NOT NULL CHECK (min_per_km_mnt >= 0),
  max_per_km_mnt integer NOT NULL CHECK (max_per_km_mnt >= 0),
  CHECK (min_per_km_mnt <= max_per_km_mnt)
);

CREATE TABLE IF NOT EXISTS public.drivers (
  profile_id uuid PRIMARY KEY REFERENCES public.profiles(id),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  licence_number text NOT NULL UNIQUE CHECK (btrim(licence_number) <> ''),
  status public.account_status NOT NULL DEFAULT 'pending',
  rating numeric(3,2) CHECK (rating BETWEEN 0 AND 5),
  wallet_balance_mnt integer NOT NULL DEFAULT 0 CHECK (wallet_balance_mnt >= 0),
  UNIQUE (profile_id, company_id)
);
CREATE INDEX IF NOT EXISTS drivers_company_idx ON public.drivers(company_id);

CREATE TABLE IF NOT EXISTS public.vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  driver_id uuid,
  plate text NOT NULL UNIQUE CHECK (btrim(plate) <> ''),
  make text NOT NULL,
  model text NOT NULL,
  year integer NOT NULL,
  colour text,
  seats integer NOT NULL DEFAULT 4 CHECK (seats > 0),
  FOREIGN KEY (driver_id, company_id) REFERENCES public.drivers(profile_id, company_id),
  UNIQUE (id, company_id)
);
CREATE INDEX IF NOT EXISTS vehicles_company_idx ON public.vehicles(company_id);
CREATE INDEX IF NOT EXISTS vehicles_driver_idx ON public.vehicles(driver_id);

CREATE TABLE IF NOT EXISTS public.driver_locations (
  driver_id uuid PRIMARY KEY REFERENCES public.drivers(profile_id) ON DELETE CASCADE,
  location geography(Point,4326) NOT NULL,
  heading real CHECK (heading >= 0 AND heading < 360),
  is_online boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS driver_locations_location_gist
  ON public.driver_locations USING gist (location);

CREATE TABLE IF NOT EXISTS public.fare_zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  town text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('town', 'center')),
  area geography(Polygon,4326) NOT NULL,
  flat_price_mnt integer CHECK (flat_price_mnt >= 0),
  CHECK (kind <> 'center' OR flat_price_mnt IS NULL)
);
CREATE INDEX IF NOT EXISTS fare_zones_area_gist ON public.fare_zones USING gist (area);

CREATE TABLE IF NOT EXISTS public.rides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id uuid NOT NULL REFERENCES public.profiles(id),
  type public.ride_type NOT NULL DEFAULT 'normal',
  status public.ride_status NOT NULL DEFAULT 'requested',
  pickup geography(Point,4326) NOT NULL,
  dropoff geography(Point,4326) NOT NULL,
  pickup_label text,
  dropoff_label text,
  distance_m integer NOT NULL CHECK (distance_m >= 0),
  suggested_price_mnt integer NOT NULL CHECK (suggested_price_mnt >= 0),
  min_price_mnt integer NOT NULL CHECK (min_price_mnt >= 0),
  max_price_mnt integer NOT NULL CHECK (max_price_mnt >= min_price_mnt),
  agreed_price_mnt integer,
  driver_id uuid REFERENCES public.drivers(profile_id),
  vehicle_id uuid,
  company_id uuid NOT NULL REFERENCES public.companies(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  accepted_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  FOREIGN KEY (vehicle_id, company_id) REFERENCES public.vehicles(id, company_id),
  CHECK (vehicle_id IS NULL OR driver_id IS NOT NULL),
  CHECK (suggested_price_mnt BETWEEN min_price_mnt AND max_price_mnt),
  CHECK (agreed_price_mnt IS NULL OR agreed_price_mnt BETWEEN min_price_mnt AND max_price_mnt),
  CHECK (status NOT IN ('accepted', 'arriving', 'in_progress', 'completed') OR
    (driver_id IS NOT NULL AND vehicle_id IS NOT NULL AND agreed_price_mnt IS NOT NULL
     AND accepted_at IS NOT NULL)),
  CHECK (status <> 'completed' OR completed_at IS NOT NULL),
  CHECK (status <> 'cancelled' OR cancelled_at IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS rides_rider_created_idx ON public.rides(rider_id, created_at DESC);
CREATE INDEX IF NOT EXISTS rides_driver_created_idx ON public.rides(driver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS rides_company_status_idx ON public.rides(company_id, status);
CREATE INDEX IF NOT EXISTS rides_vehicle_idx ON public.rides(vehicle_id);

CREATE TABLE IF NOT EXISTS public.ride_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  driver_id uuid REFERENCES public.drivers(profile_id),
  kind public.offer_kind NOT NULL,
  price_mnt integer NOT NULL CHECK (price_mnt >= 0),
  status public.offer_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((kind = 'rider_offer' AND driver_id IS NULL) OR
         (kind = 'driver_counter' AND driver_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS ride_offers_ride_idx ON public.ride_offers(ride_id);
CREATE INDEX IF NOT EXISTS ride_offers_driver_idx ON public.ride_offers(driver_id);
CREATE UNIQUE INDEX IF NOT EXISTS ride_offers_one_accepted_idx
  ON public.ride_offers(ride_id) WHERE status = 'accepted';

CREATE TABLE IF NOT EXISTS public.route_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  driver_id uuid NOT NULL,
  name text NOT NULL,
  path geography(LineString,4326) NOT NULL,
  -- Suggested format: [{"name":"Stop A","lat":49.02,"lng":104.04}, ...].
  stops jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(stops) = 'array'),
  seat_price_mnt integer NOT NULL CHECK (seat_price_mnt >= 0),
  seats_total integer NOT NULL CHECK (seats_total > 0),
  departs_at timestamptz,
  active boolean NOT NULL DEFAULT true,
  FOREIGN KEY (driver_id, company_id) REFERENCES public.drivers(profile_id, company_id)
);
CREATE INDEX IF NOT EXISTS route_lines_company_idx ON public.route_lines(company_id);
CREATE INDEX IF NOT EXISTS route_lines_driver_idx ON public.route_lines(driver_id);

CREATE TABLE IF NOT EXISTS public.route_bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  route_line_id uuid NOT NULL REFERENCES public.route_lines(id),
  rider_id uuid NOT NULL REFERENCES public.profiles(id),
  seats integer NOT NULL CHECK (seats > 0),
  pickup_stop text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS route_bookings_route_idx ON public.route_bookings(route_line_id);
CREATE INDEX IF NOT EXISTS route_bookings_rider_idx ON public.route_bookings(rider_id);

CREATE TABLE IF NOT EXISTS public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.rides(id),
  method public.payment_method NOT NULL,
  amount_mnt integer NOT NULL CHECK (amount_mnt >= 0),
  commission_mnt integer NOT NULL DEFAULT 0 CHECK (commission_mnt BETWEEN 0 AND amount_mnt),
  qpay_invoice_id text UNIQUE,
  ebarimt_id text UNIQUE,
  paid_at timestamptz
);
CREATE INDEX IF NOT EXISTS payments_ride_idx ON public.payments(ride_id);

-- Small definer helpers avoid recursive RLS on profiles and company_admins.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles
    WHERE id = (SELECT auth.uid()) AND role = 'admin');
$$;

CREATE OR REPLACE FUNCTION public.is_company_admin(p_company uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.company_admins ca JOIN public.profiles p ON p.id = ca.profile_id
    WHERE ca.company_id = p_company AND ca.profile_id = (SELECT auth.uid())
      AND p.role = 'company_admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_approved_driver(p_driver uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.drivers d
    JOIN public.companies c ON c.id = d.company_id
    JOIN public.profiles p ON p.id = d.profile_id
    WHERE d.profile_id = p_driver AND p.role = 'driver' AND d.status = 'approved'
      AND c.status = 'approved' AND c.permit_expires_on >= CURRENT_DATE
  );
$$;

-- Definer lookup breaks the route_lines <-> route_bookings policy cycle.
CREATE OR REPLACE FUNCTION public.is_route_operator(p_route uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.route_lines l WHERE l.id = p_route
      AND (l.driver_id = (SELECT auth.uid()) OR public.is_company_admin(l.company_id))
  );
$$;

CREATE OR REPLACE FUNCTION public.quote_trip(
  p_lat double precision, p_lng double precision,
  d_lat double precision, d_lng double precision, p_company uuid
)
RETURNS TABLE (
  ride_type public.ride_type, suggested_price_mnt integer,
  min_price_mnt integer, max_price_mnt integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path FROM CURRENT AS $$
DECLARE
  v_pickup geography(Point,4326);
  v_dropoff geography(Point,4326);
  v_tariff public.company_tariffs%ROWTYPE;
  v_flat integer;
  v_distance_m integer;
  v_min integer;
  v_max integer;
BEGIN
  IF p_lat IS NULL OR p_lng IS NULL OR d_lat IS NULL OR d_lng IS NULL
     OR NOT (p_lat BETWEEN -90 AND 90 AND d_lat BETWEEN -90 AND 90
             AND p_lng BETWEEN -180 AND 180 AND d_lng BETWEEN -180 AND 180) THEN
    RAISE EXCEPTION 'Coordinates must be finite latitude/longitude values' USING ERRCODE = '22023';
  END IF;
  SELECT t.* INTO v_tariff FROM public.company_tariffs t
  JOIN public.companies c ON c.id = t.company_id
  WHERE t.company_id = p_company AND c.status = 'approved'
    AND c.permit_expires_on >= CURRENT_DATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Company needs approval, a current permit and a tariff' USING ERRCODE = '23514';
  END IF;

  -- PostGIS always takes longitude before latitude; geography distances are metres.
  v_pickup := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
  v_dropoff := ST_SetSRID(ST_MakePoint(d_lng, d_lat), 4326)::geography;
  SELECT z.flat_price_mnt INTO v_flat FROM public.fare_zones z
  WHERE z.kind = 'town' AND z.flat_price_mnt IS NOT NULL
    AND ST_Covers(z.area, v_pickup) AND ST_Covers(z.area, v_dropoff)
    AND NOT EXISTS (
      SELECT 1 FROM public.fare_zones center_zone WHERE center_zone.kind = 'center'
        AND (ST_Covers(center_zone.area, v_pickup) OR ST_Covers(center_zone.area, v_dropoff))
    )
  -- Deterministic choice if placeholder/real town polygons overlap; boundaries count as inside.
  ORDER BY ST_Area(z.area), z.id LIMIT 1;
  IF FOUND THEN
    RETURN QUERY SELECT 'flat'::public.ride_type, v_flat, v_flat, v_flat;
    RETURN;
  END IF;

  -- Must match quoteTrip() in rider_app/lib/pricing.dart: road distance is
  -- straight-line x 1.3 rounded to the metre, prices rounded to the nearest 100 MNT.
  v_distance_m := round(ST_Distance(v_pickup, v_dropoff) * 1.3)::integer;
  v_min := (round((v_tariff.base_fare_mnt
    + v_distance_m::numeric / 1000 * v_tariff.min_per_km_mnt) / 100) * 100)::integer;
  v_max := (round((v_tariff.base_fare_mnt
    + v_distance_m::numeric / 1000 * v_tariff.max_per_km_mnt) / 100) * 100)::integer;
  RETURN QUERY SELECT 'normal'::public.ride_type,
    (round((v_min + v_max)::numeric / 2 / 100) * 100)::integer, v_min, v_max;
END;
$$;

CREATE OR REPLACE FUNCTION public.nearby_drivers(
  lat double precision, lng double precision, radius_m integer DEFAULT 3000
)
RETURNS TABLE (
  driver_id uuid, company_id uuid, location geography(Point,4326),
  heading real, distance_m double precision, updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path FROM CURRENT AS $$
DECLARE v_origin geography(Point,4326);
BEGIN
  IF lat IS NULL OR lng IS NULL OR NOT (lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180)
     OR radius_m IS NULL OR radius_m <= 0 THEN
    RAISE EXCEPTION 'Valid coordinates and a positive radius in metres are required' USING ERRCODE = '22023';
  END IF;
  v_origin := ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography;
  RETURN QUERY
  SELECT dl.driver_id, d.company_id, dl.location, dl.heading,
    ST_Distance(dl.location, v_origin), dl.updated_at
  FROM public.driver_locations dl JOIN public.drivers d ON d.profile_id = dl.driver_id
  WHERE dl.is_online AND public.is_approved_driver(dl.driver_id)
    AND ST_DWithin(dl.location, v_origin, radius_m)
  ORDER BY ST_Distance(dl.location, v_origin), dl.driver_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_company_permit()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.status = 'approved' AND NEW.permit_expires_on < CURRENT_DATE THEN
    RAISE EXCEPTION 'An approved company must hold a current taxi permit' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS companies_permit_check ON public.companies;
CREATE TRIGGER companies_permit_check BEFORE INSERT OR UPDATE ON public.companies
  FOR EACH ROW EXECUTE FUNCTION public.check_company_permit();

CREATE OR REPLACE FUNCTION public.check_vehicle_age()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  -- A time-dependent rule belongs in a trigger, not an immutable CHECK expression.
  IF NEW.year < extract(year FROM CURRENT_DATE)::integer - 10
     OR NEW.year > extract(year FROM CURRENT_DATE)::integer + 1 THEN
    RAISE EXCEPTION 'Vehicle year must be within the last 10 years (or next model year)'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS vehicles_age_check ON public.vehicles;
CREATE TRIGGER vehicles_age_check BEFORE INSERT OR UPDATE ON public.vehicles
  FOR EACH ROW EXECUTE FUNCTION public.check_vehicle_age();

CREATE OR REPLACE FUNCTION public.stamp_driver_location()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS driver_locations_stamp ON public.driver_locations;
CREATE TRIGGER driver_locations_stamp BEFORE INSERT OR UPDATE ON public.driver_locations
  FOR EACH ROW EXECUTE FUNCTION public.stamp_driver_location();

CREATE OR REPLACE FUNCTION public.prepare_ride()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path FROM CURRENT AS $$
DECLARE v_requote boolean;
BEGIN
  v_requote := TG_OP = 'INSERT';
  IF TG_OP = 'UPDATE' THEN
    v_requote := NEW.pickup::text IS DISTINCT FROM OLD.pickup::text
      OR NEW.dropoff::text IS DISTINCT FROM OLD.dropoff::text
      OR NEW.company_id IS DISTINCT FROM OLD.company_id OR NEW.type IS DISTINCT FROM OLD.type;
    IF v_requote AND (OLD.status <> 'requested' OR EXISTS (
      SELECT 1 FROM public.ride_offers WHERE ride_id = OLD.id
    )) THEN
      RAISE EXCEPTION 'Trip and tariff cannot change after offers or acceptance' USING ERRCODE = '23514';
    END IF;
    IF NOT v_requote AND (NEW.distance_m IS DISTINCT FROM OLD.distance_m
      OR NEW.suggested_price_mnt IS DISTINCT FROM OLD.suggested_price_mnt
      OR NEW.min_price_mnt IS DISTINCT FROM OLD.min_price_mnt
      OR NEW.max_price_mnt IS DISTINCT FROM OLD.max_price_mnt) THEN
      RAISE EXCEPTION 'Stored fare bounds are immutable; change the unoffered trip to requote'
        USING ERRCODE = '23514';
    END IF;
    IF NEW.status IS DISTINCT FROM OLD.status AND NOT (
      (OLD.status = 'requested' AND NEW.status IN ('offered', 'accepted', 'cancelled')) OR
      (OLD.status = 'offered' AND NEW.status IN ('accepted', 'cancelled')) OR
      (OLD.status = 'accepted' AND NEW.status IN ('arriving', 'in_progress', 'cancelled')) OR
      (OLD.status = 'arriving' AND NEW.status IN ('in_progress', 'cancelled')) OR
      (OLD.status = 'in_progress' AND NEW.status IN ('completed', 'cancelled'))
    ) THEN
      RAISE EXCEPTION 'Invalid ride status transition: % -> %', OLD.status, NEW.status
        USING ERRCODE = '23514';
    END IF;
  END IF;

  -- Regular/flat rides always get authoritative bounds. Route fares are supplied
  -- by the trusted backend; shuttle passengers normally use route_bookings.
  IF v_requote AND NEW.type <> 'route' THEN
    SELECT q.ride_type, q.suggested_price_mnt, q.min_price_mnt, q.max_price_mnt
      INTO NEW.type, NEW.suggested_price_mnt, NEW.min_price_mnt, NEW.max_price_mnt
    FROM public.quote_trip(ST_Y(NEW.pickup::geometry), ST_X(NEW.pickup::geometry),
      ST_Y(NEW.dropoff::geometry), ST_X(NEW.dropoff::geometry), NEW.company_id) q;
    NEW.distance_m := round(ST_Distance(NEW.pickup, NEW.dropoff) * 1.3)::integer;
  END IF;
  -- Validate the current assignment without tying historical rides to the
  -- vehicle's mutable driver_id: a car can be reassigned after a trip ends.
  IF (NEW.driver_id IS NOT NULL OR NEW.vehicle_id IS NOT NULL) AND
     (TG_OP = 'INSERT' OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
      OR NEW.vehicle_id IS DISTINCT FROM OLD.vehicle_id
      OR NEW.company_id IS DISTINCT FROM OLD.company_id
      OR (NEW.status = 'accepted' AND NEW.status IS DISTINCT FROM OLD.status)) THEN
    IF NOT EXISTS (SELECT 1 FROM public.drivers d WHERE d.profile_id = NEW.driver_id
      AND d.company_id = NEW.company_id AND public.is_approved_driver(d.profile_id)) THEN
      RAISE EXCEPTION 'Assignment requires an approved driver from the quoted company'
        USING ERRCODE = '23514';
    END IF;
    IF NEW.vehicle_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.vehicles v WHERE v.id = NEW.vehicle_id
        AND v.company_id = NEW.company_id AND v.driver_id = NEW.driver_id
        AND v.year >= extract(year FROM CURRENT_DATE)::integer - 10
    ) THEN
      RAISE EXCEPTION 'Vehicle must be assigned to this driver and meet the age limit'
        USING ERRCODE = '23514';
    END IF;
  END IF;
  IF NEW.status IN ('accepted', 'arriving', 'in_progress', 'completed') THEN
    NEW.accepted_at := coalesce(NEW.accepted_at, now());
  END IF;
  IF NEW.status = 'completed' THEN NEW.completed_at := coalesce(NEW.completed_at, now()); END IF;
  IF NEW.status = 'cancelled' THEN NEW.cancelled_at := coalesce(NEW.cancelled_at, now()); END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS rides_prepare ON public.rides;
CREATE TRIGGER rides_prepare BEFORE INSERT OR UPDATE ON public.rides
  FOR EACH ROW EXECUTE FUNCTION public.prepare_ride();

CREATE OR REPLACE FUNCTION public.check_ride_offer()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_ride public.rides%ROWTYPE;
BEGIN
  -- Serialize with ride edits/acceptance so an offer cannot race a fare change.
  SELECT * INTO v_ride FROM public.rides WHERE id = NEW.ride_id FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ride does not exist' USING ERRCODE = '23503';
  END IF;
  IF NEW.price_mnt NOT BETWEEN v_ride.min_price_mnt AND v_ride.max_price_mnt THEN
    RAISE EXCEPTION 'Offer price % must be between % and % MNT',
      NEW.price_mnt, v_ride.min_price_mnt, v_ride.max_price_mnt USING ERRCODE = '23514';
  END IF;
  IF TG_OP = 'INSERT' OR NEW.price_mnt IS DISTINCT FROM OLD.price_mnt
     OR NEW.ride_id IS DISTINCT FROM OLD.ride_id OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
     OR NEW.kind IS DISTINCT FROM OLD.kind THEN
    IF v_ride.status NOT IN ('requested', 'offered') THEN
      RAISE EXCEPTION 'Ride is no longer open to offers' USING ERRCODE = '23514';
    END IF;
    IF NEW.kind = 'driver_counter' AND NOT EXISTS (
      SELECT 1 FROM public.drivers d WHERE d.profile_id = NEW.driver_id
        AND d.company_id = v_ride.company_id AND public.is_approved_driver(d.profile_id)
    ) THEN
      RAISE EXCEPTION 'Counteroffer requires an approved driver from the quoted company'
        USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS ride_offers_price_check ON public.ride_offers;
CREATE TRIGGER ride_offers_price_check BEFORE INSERT OR UPDATE ON public.ride_offers
  FOR EACH ROW EXECUTE FUNCTION public.check_ride_offer();

-- Set only trusted schemas for functions that resolve PostGIS types/operators.
DO $$
DECLARE spatial_schema text; function_name text;
BEGIN
  SELECT n.nspname INTO spatial_schema FROM pg_extension e
    JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'postgis';
  FOREACH function_name IN ARRAY ARRAY[
    'public.quote_trip(double precision,double precision,double precision,double precision,uuid)',
    'public.nearby_drivers(double precision,double precision,integer)',
    'public.prepare_ride()'
  ] LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = pg_catalog, %I, pg_temp',
      function_name, spatial_schema);
  END LOOP;
END;
$$;

-- RLS: clients cannot self-approve, edit wallet/payment data, or assign drivers.
-- Sensitive writes use a trusted service_role backend. Never ship its key to clients.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_tariffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fare_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_read ON public.profiles;
CREATE POLICY profiles_read ON public.profiles FOR SELECT TO authenticated USING (
  id = (SELECT auth.uid()) OR (SELECT public.is_admin()) OR EXISTS (
    SELECT 1 FROM public.drivers d WHERE d.profile_id = profiles.id
      AND public.is_company_admin(d.company_id)
  ) OR EXISTS (
    SELECT 1 FROM public.rides r WHERE
      (r.rider_id = (SELECT auth.uid()) AND r.driver_id = profiles.id) OR
      (r.driver_id = (SELECT auth.uid()) AND r.rider_id = profiles.id) OR
      (public.is_company_admin(r.company_id) AND profiles.id IN (r.rider_id, r.driver_id))
  )
);
DROP POLICY IF EXISTS profiles_insert ON public.profiles;
CREATE POLICY profiles_insert ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (id = (SELECT auth.uid()) AND role = 'rider');
DROP POLICY IF EXISTS profiles_update ON public.profiles;
CREATE POLICY profiles_update ON public.profiles FOR UPDATE TO authenticated
  USING (id = (SELECT auth.uid())) WITH CHECK (id = (SELECT auth.uid()));

DROP POLICY IF EXISTS companies_read ON public.companies;
CREATE POLICY companies_read ON public.companies FOR SELECT TO authenticated USING (
  (status = 'approved' AND permit_expires_on >= CURRENT_DATE)
  OR public.is_company_admin(id) OR (SELECT public.is_admin())
);
DROP POLICY IF EXISTS company_admins_read ON public.company_admins;
CREATE POLICY company_admins_read ON public.company_admins FOR SELECT TO authenticated USING (
  profile_id = (SELECT auth.uid()) OR public.is_company_admin(company_id) OR (SELECT public.is_admin())
);
DROP POLICY IF EXISTS company_tariffs_read ON public.company_tariffs;
CREATE POLICY company_tariffs_read ON public.company_tariffs FOR SELECT TO authenticated USING (
  (SELECT public.is_admin()) OR public.is_company_admin(company_id)
  OR EXISTS (SELECT 1 FROM public.companies c WHERE c.id = company_tariffs.company_id)
);
DROP POLICY IF EXISTS drivers_read ON public.drivers;
CREATE POLICY drivers_read ON public.drivers FOR SELECT TO authenticated USING (
  profile_id = (SELECT auth.uid()) OR public.is_company_admin(company_id) OR (SELECT public.is_admin())
);
DROP POLICY IF EXISTS vehicles_read ON public.vehicles;
CREATE POLICY vehicles_read ON public.vehicles FOR SELECT TO authenticated USING (
  driver_id = (SELECT auth.uid()) OR public.is_company_admin(company_id) OR (SELECT public.is_admin())
  OR EXISTS (SELECT 1 FROM public.rides r
    WHERE r.vehicle_id = vehicles.id AND r.rider_id = (SELECT auth.uid()))
);
DROP POLICY IF EXISTS driver_locations_read ON public.driver_locations;
CREATE POLICY driver_locations_read ON public.driver_locations FOR SELECT TO authenticated USING (
  driver_id = (SELECT auth.uid()) OR (SELECT public.is_admin()) OR EXISTS (
    SELECT 1 FROM public.drivers d WHERE d.profile_id = driver_locations.driver_id
      AND public.is_company_admin(d.company_id)
  )
);
DROP POLICY IF EXISTS driver_locations_insert ON public.driver_locations;
CREATE POLICY driver_locations_insert ON public.driver_locations FOR INSERT TO authenticated
  WITH CHECK (driver_id = (SELECT auth.uid()) AND public.is_approved_driver(driver_id));
DROP POLICY IF EXISTS driver_locations_update ON public.driver_locations;
CREATE POLICY driver_locations_update ON public.driver_locations FOR UPDATE TO authenticated
  USING (driver_id = (SELECT auth.uid()))
  WITH CHECK (driver_id = (SELECT auth.uid()) AND
    (NOT is_online OR public.is_approved_driver(driver_id)));
DROP POLICY IF EXISTS driver_locations_delete ON public.driver_locations;
CREATE POLICY driver_locations_delete ON public.driver_locations FOR DELETE TO authenticated
  USING (driver_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS fare_zones_read ON public.fare_zones;
CREATE POLICY fare_zones_read ON public.fare_zones FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS rides_read ON public.rides;
CREATE POLICY rides_read ON public.rides FOR SELECT TO authenticated USING (
  rider_id = (SELECT auth.uid()) OR driver_id = (SELECT auth.uid())
  OR public.is_company_admin(company_id) OR (SELECT public.is_admin()) OR (
    status IN ('requested', 'offered') AND public.is_approved_driver((SELECT auth.uid()))
    AND EXISTS (SELECT 1 FROM public.drivers d
      WHERE d.profile_id = (SELECT auth.uid()) AND d.company_id = rides.company_id)
  )
);
DROP POLICY IF EXISTS rides_insert ON public.rides;
CREATE POLICY rides_insert ON public.rides FOR INSERT TO authenticated WITH CHECK (
  rider_id = (SELECT auth.uid()) AND type IN ('normal', 'flat') AND status = 'requested'
  AND driver_id IS NULL AND vehicle_id IS NULL AND agreed_price_mnt IS NULL
  AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = (SELECT auth.uid()) AND p.role = 'rider')
);
DROP POLICY IF EXISTS rides_cancel ON public.rides;
CREATE POLICY rides_cancel ON public.rides FOR UPDATE TO authenticated
  USING (rider_id = (SELECT auth.uid()) AND status IN ('requested', 'offered'))
  WITH CHECK (rider_id = (SELECT auth.uid()) AND status = 'cancelled');

DROP POLICY IF EXISTS ride_offers_read ON public.ride_offers;
CREATE POLICY ride_offers_read ON public.ride_offers FOR SELECT TO authenticated USING (
  driver_id = (SELECT auth.uid()) OR (SELECT public.is_admin()) OR EXISTS (
    SELECT 1 FROM public.rides r WHERE r.id = ride_offers.ride_id AND (
      r.rider_id = (SELECT auth.uid()) OR public.is_company_admin(r.company_id) OR (
        ride_offers.kind = 'rider_offer' AND ride_offers.status = 'pending'
        AND r.status IN ('requested', 'offered') AND public.is_approved_driver((SELECT auth.uid()))
        AND EXISTS (SELECT 1 FROM public.drivers d
          WHERE d.profile_id = (SELECT auth.uid()) AND d.company_id = r.company_id)
      )
    )
  )
);
DROP POLICY IF EXISTS ride_offers_insert ON public.ride_offers;
CREATE POLICY ride_offers_insert ON public.ride_offers FOR INSERT TO authenticated WITH CHECK (
  status = 'pending' AND EXISTS (
    SELECT 1 FROM public.rides r WHERE r.id = ride_offers.ride_id
      AND r.status IN ('requested', 'offered') AND (
        (kind = 'rider_offer' AND ride_offers.driver_id IS NULL AND r.rider_id = (SELECT auth.uid())) OR
        (kind = 'driver_counter' AND ride_offers.driver_id = (SELECT auth.uid())
          AND public.is_approved_driver((SELECT auth.uid())) AND EXISTS (
            SELECT 1 FROM public.drivers d WHERE d.profile_id = (SELECT auth.uid())
              AND d.company_id = r.company_id
          ))
      )
  )
);

DROP POLICY IF EXISTS route_lines_read ON public.route_lines;
CREATE POLICY route_lines_read ON public.route_lines FOR SELECT TO authenticated USING (
  driver_id = (SELECT auth.uid()) OR public.is_company_admin(company_id) OR (SELECT public.is_admin())
  OR (active AND public.is_approved_driver(driver_id))
  OR EXISTS (SELECT 1 FROM public.route_bookings b
    WHERE b.route_line_id = route_lines.id AND b.rider_id = (SELECT auth.uid()))
);
DROP POLICY IF EXISTS route_bookings_read ON public.route_bookings;
CREATE POLICY route_bookings_read ON public.route_bookings FOR SELECT TO authenticated USING (
  rider_id = (SELECT auth.uid()) OR (SELECT public.is_admin())
  OR public.is_route_operator(route_line_id)
);
DROP POLICY IF EXISTS route_bookings_insert ON public.route_bookings;
CREATE POLICY route_bookings_insert ON public.route_bookings FOR INSERT TO authenticated WITH CHECK (
  rider_id = (SELECT auth.uid()) AND status = 'pending'
  AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = (SELECT auth.uid()) AND p.role = 'rider')
  AND EXISTS (SELECT 1 FROM public.route_lines l WHERE l.id = route_bookings.route_line_id
    AND l.active AND public.is_approved_driver(l.driver_id) AND seats <= l.seats_total)
);
DROP POLICY IF EXISTS route_bookings_cancel ON public.route_bookings;
CREATE POLICY route_bookings_cancel ON public.route_bookings FOR UPDATE TO authenticated
  USING (rider_id = (SELECT auth.uid()) AND status = 'pending')
  WITH CHECK (rider_id = (SELECT auth.uid()) AND status = 'cancelled');
DROP POLICY IF EXISTS payments_read ON public.payments;
CREATE POLICY payments_read ON public.payments FOR SELECT TO authenticated USING (
  (SELECT public.is_admin()) OR EXISTS (SELECT 1 FROM public.rides r WHERE r.id = payments.ride_id
    AND (r.rider_id = (SELECT auth.uid()) OR r.driver_id = (SELECT auth.uid())
      OR public.is_company_admin(r.company_id)))
);

-- Explicit grants override Supabase's permissive default table grants. RLS and
-- column grants work together: clients cannot choose roles, fares or approvals.
REVOKE ALL ON TABLE public.profiles, public.companies, public.company_admins,
  public.company_tariffs, public.drivers, public.vehicles, public.driver_locations,
  public.fare_zones, public.rides, public.ride_offers, public.route_lines,
  public.route_bookings, public.payments FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA public TO authenticated, service_role;
GRANT SELECT ON TABLE public.profiles, public.companies, public.company_admins,
  public.company_tariffs, public.drivers, public.vehicles, public.driver_locations,
  public.fare_zones, public.rides, public.ride_offers, public.route_lines,
  public.route_bookings, public.payments TO authenticated;
GRANT ALL ON TABLE public.profiles, public.companies, public.company_admins,
  public.company_tariffs, public.drivers, public.vehicles, public.driver_locations,
  public.fare_zones, public.rides, public.ride_offers, public.route_lines,
  public.route_bookings, public.payments TO service_role;
GRANT INSERT (id, full_name, phone), UPDATE (full_name, phone) ON public.profiles TO authenticated;
-- Including driver_id in UPDATE supports UPSERT; RLS fixes it to auth.uid().
GRANT INSERT (driver_id, location, heading, is_online), UPDATE (driver_id, location, heading, is_online), DELETE
  ON public.driver_locations TO authenticated;
GRANT INSERT (rider_id, type, pickup, dropoff, pickup_label, dropoff_label, company_id), UPDATE (status)
  ON public.rides TO authenticated;
GRANT INSERT (ride_id, driver_id, kind, price_mnt) ON public.ride_offers TO authenticated;
GRANT INSERT (route_line_id, rider_id, seats, pickup_stop), UPDATE (status)
  ON public.route_bookings TO authenticated;

REVOKE ALL ON FUNCTION public.is_admin(), public.is_company_admin(uuid), public.is_approved_driver(uuid),
  public.is_route_operator(uuid),
  public.quote_trip(double precision,double precision,double precision,double precision,uuid),
  public.nearby_drivers(double precision,double precision,integer),
  public.check_company_permit(), public.check_vehicle_age(), public.stamp_driver_location(),
  public.prepare_ride(), public.check_ride_offer() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin(), public.is_company_admin(uuid), public.is_approved_driver(uuid),
  public.is_route_operator(uuid),
  public.quote_trip(double precision,double precision,double precision,double precision,uuid),
  public.nearby_drivers(double precision,double precision,integer) TO authenticated, service_role;

COMMIT;
