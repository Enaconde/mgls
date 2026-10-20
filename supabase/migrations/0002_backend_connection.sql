-- M3: public fare previews, private saved places/reports, coordinated Dart parity.
-- Apply after 0001_init.sql. No accounts or demo company data are created here.
BEGIN;

DO $$
DECLARE spatial_schema text;
BEGIN
  SELECT n.nspname INTO spatial_schema FROM pg_extension e
    JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'postgis';
  IF spatial_schema IS NULL THEN RAISE EXCEPTION 'PostGIS is required'; END IF;
  PERFORM set_config('search_path', format('public, %I', spatial_schema), true);
END;
$$;

CREATE OR REPLACE FUNCTION public.valid_place_json(p jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
BEGIN
  IF jsonb_typeof(p) IS DISTINCT FROM 'object'
    OR jsonb_typeof(p->'id') IS DISTINCT FROM 'string'
    OR jsonb_typeof(p->'name') IS DISTINCT FROM 'string'
    OR jsonb_typeof(p->'area') IS DISTINCT FROM 'string'
    OR jsonb_typeof(p->'kind') IS DISTINCT FROM 'string'
    OR jsonb_typeof(p->'lat') IS DISTINCT FROM 'number'
    OR jsonb_typeof(p->'lon') IS DISTINCT FROM 'number' THEN RETURN false;
  END IF;
  RETURN length(p->>'id') BETWEEN 1 AND 200
    AND length(btrim(p->>'name')) BETWEEN 1 AND 300
    AND length(btrim(p->>'area')) BETWEEN 1 AND 1000
    AND p->>'kind' IN ('market','hospital','transport','school','government','shopping','other')
    AND (p->>'lat')::numeric BETWEEN -90 AND 90
    AND (p->>'lon')::numeric BETWEEN -180 AND 180;
END;
$$;

CREATE TABLE public.saved_places (
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('home','work')),
  place jsonb NOT NULL CHECK (public.valid_place_json(place)),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (owner_id, kind)
);
CREATE TABLE public.place_reports (
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  client_id text NOT NULL CHECK (length(client_id) BETWEEN 1 AND 250),
  place jsonb NOT NULL CHECK (public.valid_place_json(place)),
  note text NOT NULL CHECK (length(btrim(note)) BETWEEN 1 AND 500),
  reported_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (owner_id, client_id)
);

CREATE FUNCTION public.stamp_saved_place()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END;
$$;
CREATE TRIGGER saved_places_stamp BEFORE INSERT OR UPDATE ON public.saved_places
  FOR EACH ROW EXECUTE FUNCTION public.stamp_saved_place();

ALTER TABLE public.saved_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.place_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY saved_places_select ON public.saved_places FOR SELECT TO authenticated
  USING (owner_id = (SELECT auth.uid()));
CREATE POLICY saved_places_insert ON public.saved_places FOR INSERT TO authenticated
  WITH CHECK (owner_id = (SELECT auth.uid()));
CREATE POLICY saved_places_update ON public.saved_places FOR UPDATE TO authenticated
  USING (owner_id = (SELECT auth.uid())) WITH CHECK (owner_id = (SELECT auth.uid()));
CREATE POLICY reports_select ON public.place_reports FOR SELECT TO authenticated
  USING (owner_id = (SELECT auth.uid()));
CREATE POLICY reports_insert ON public.place_reports FOR INSERT TO authenticated
  WITH CHECK (owner_id = (SELECT auth.uid()));

REVOKE ALL ON public.saved_places, public.place_reports FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.saved_places, public.place_reports TO authenticated;
GRANT INSERT (owner_id,kind,place), UPDATE (owner_id,kind,place)
  ON public.saved_places TO authenticated;
GRANT INSERT (owner_id,client_id,place,note,reported_at)
  ON public.place_reports TO authenticated;
GRANT ALL ON public.saved_places, public.place_reports TO service_role;
REVOKE ALL ON FUNCTION public.valid_place_json(jsonb), public.stamp_saved_place()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.valid_place_json(jsonb) TO authenticated, service_role;

-- Same quote contract as M1. Preserve its trigger callers and existing grants.
-- Containment uses planar lon/lat polygon edges in BOTH Dart and SQL, including
-- boundaries and hole boundaries. WGS84 geography is retained for distances.
CREATE OR REPLACE FUNCTION public.quote_trip(
  p_lat double precision, p_lng double precision,
  d_lat double precision, d_lng double precision, p_company uuid
)
RETURNS TABLE (ride_type public.ride_type, suggested_price_mnt integer,
  min_price_mnt integer, max_price_mnt integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path FROM CURRENT AS $$
DECLARE
  v_pickup geography(Point,4326);
  v_dropoff geography(Point,4326);
  v_tariff public.company_tariffs%ROWTYPE;
  v_flat integer; v_distance_m integer; v_min integer; v_max integer;
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
  v_pickup := ST_SetSRID(ST_MakePoint(p_lng,p_lat),4326)::geography;
  v_dropoff := ST_SetSRID(ST_MakePoint(d_lng,d_lat),4326)::geography;
  SELECT z.flat_price_mnt INTO v_flat FROM public.fare_zones z
    WHERE z.kind = 'town' AND z.flat_price_mnt IS NOT NULL
      AND ST_Covers(z.area::geometry, v_pickup::geometry)
      AND ST_Covers(z.area::geometry, v_dropoff::geometry)
      AND NOT EXISTS (SELECT 1 FROM public.fare_zones c WHERE c.kind = 'center'
        AND (ST_Covers(c.area::geometry, v_pickup::geometry)
          OR ST_Covers(c.area::geometry, v_dropoff::geometry)))
    ORDER BY ST_Area(z.area::geometry), z.id LIMIT 1;
  IF FOUND THEN
    RETURN QUERY SELECT 'flat'::public.ride_type, v_flat, v_flat, v_flat;
    RETURN;
  END IF;
  v_distance_m := round(ST_Distance(v_pickup,v_dropoff) * 1.3)::integer;
  v_min := (round((v_tariff.base_fare_mnt
    + v_distance_m::numeric / 1000 * v_tariff.min_per_km_mnt) / 100) * 100)::integer;
  v_max := (round((v_tariff.base_fare_mnt
    + v_distance_m::numeric / 1000 * v_tariff.max_per_km_mnt) / 100) * 100)::integer;
  RETURN QUERY SELECT 'normal'::public.ride_type,
    (round((v_min::numeric + v_max) / 2 / 100) * 100)::integer, v_min, v_max;
END;
$$;

-- Only this deliberately limited subset is public; base tables stay private.
CREATE FUNCTION public.fare_catalog()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path FROM CURRENT AS $$
  SELECT jsonb_build_object(
    'zones', coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id',z.id,'town',z.town,'kind',z.kind,'flat_price_mnt',z.flat_price_mnt,
      'area',ST_AsGeoJSON(z.area::geometry,15)::jsonb) ORDER BY z.id)
      FROM public.fare_zones z), '[]'::jsonb),
    'companies', coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id',c.id,'name',c.name,'base_fare_mnt',t.base_fare_mnt,
      'min_per_km_mnt',t.min_per_km_mnt,'max_per_km_mnt',t.max_per_km_mnt) ORDER BY c.id)
      FROM public.companies c JOIN public.company_tariffs t ON t.company_id = c.id
      WHERE c.status = 'approved' AND c.permit_expires_on >= CURRENT_DATE), '[]'::jsonb)
  );
$$;

CREATE FUNCTION public.fare_quote(
  p_lat double precision, p_lng double precision,
  d_lat double precision, d_lng double precision, p_company uuid
)
RETURNS TABLE (ride_type public.ride_type, distance_m integer,
  suggested_price_mnt integer, min_price_mnt integer, max_price_mnt integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path FROM CURRENT AS $$
DECLARE q record; v_distance integer;
BEGIN
  SELECT * INTO STRICT q FROM public.quote_trip(p_lat,p_lng,d_lat,d_lng,p_company);
  v_distance := round(ST_Distance(
    ST_SetSRID(ST_MakePoint(p_lng,p_lat),4326)::geography,
    ST_SetSRID(ST_MakePoint(d_lng,d_lat),4326)::geography) * 1.3)::integer;
  RETURN QUERY SELECT q.ride_type, v_distance, q.suggested_price_mnt,
    q.min_price_mnt, q.max_price_mnt;
END;
$$;

DO $$
DECLARE spatial_schema text; signature text;
BEGIN
  SELECT n.nspname INTO spatial_schema FROM pg_extension e
    JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'postgis';
  FOREACH signature IN ARRAY ARRAY[
    'public.quote_trip(double precision,double precision,double precision,double precision,uuid)',
    'public.fare_catalog()',
    'public.fare_quote(double precision,double precision,double precision,double precision,uuid)'
  ] LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = pg_catalog, %I, pg_temp', signature, spatial_schema);
  END LOOP;
END;
$$;

GRANT USAGE ON SCHEMA public TO anon;
REVOKE ALL ON FUNCTION public.fare_catalog(),
  public.fare_quote(double precision,double precision,double precision,double precision,uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fare_catalog(),
  public.fare_quote(double precision,double precision,double precision,double precision,uuid)
  TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
