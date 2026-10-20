-- Run ONLY against a disposable Supabase/PostGIS test database after migrations.
-- psql -X -v ON_ERROR_STOP=1 -f supabase/tests/pricing_parity.sql
-- This transaction rolls back all fixtures, including the temporary zone set.
BEGIN;
SET LOCAL plpgsql.check_asserts = on;
DO $$
DECLARE spatial_schema text;
BEGIN
  SELECT n.nspname INTO spatial_schema FROM pg_extension e
    JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'postgis';
  PERFORM set_config('search_path', format('public, %I',spatial_schema),true);
END;
$$;
CREATE TEMP TABLE parity_fixture (data jsonb);
-- This exact payload is also read by rider_app/test/pricing_parity_test.dart.
INSERT INTO parity_fixture VALUES ($fixture$
{"zoneSets":{"seed":[{"id":"22222222-2222-4222-8222-222222222222","town":"Erdenet","kind":"town","flat_price_mnt":3000,"area":{"type":"Polygon","coordinates":[[[104.023,49.063],[104.143,49.063],[104.143,49.003],[104.023,49.003],[104.023,49.063]]]}},{"id":"33333333-3333-4333-8333-333333333333","town":"Erdenet","kind":"center","flat_price_mnt":null,"area":{"type":"Polygon","coordinates":[[[104.042,49.038],[104.066,49.038],[104.066,49.022],[104.042,49.022],[104.042,49.038]]]}}],"none":[],"twoTowns":[{"id":"22222222-2222-4222-8222-222222222222","town":"Erdenet","kind":"town","flat_price_mnt":3000,"area":{"type":"Polygon","coordinates":[[[104.023,49.063],[104.143,49.063],[104.143,49.003],[104.023,49.003],[104.023,49.063]]]}},{"id":"55555555-5555-4555-8555-555555555555","town":"Other","kind":"town","flat_price_mnt":4000,"area":{"type":"Polygon","coordinates":[[[104.0,49.1],[104.0,49.2],[104.2,49.2],[104.2,49.1],[104.0,49.1]]]}}],"overlap":[{"id":"22222222-2222-4222-8222-222222222222","town":"Erdenet","kind":"town","flat_price_mnt":3000,"area":{"type":"Polygon","coordinates":[[[104.023,49.063],[104.143,49.063],[104.143,49.003],[104.023,49.003],[104.023,49.063]]]}},{"id":"44444444-4444-4444-8444-444444444444","town":"Small","kind":"town","flat_price_mnt":3500,"area":{"type":"Polygon","coordinates":[[[104.03,49.005],[104.03,49.015],[104.06,49.015],[104.06,49.005],[104.03,49.005]]]}}],"tie":[{"id":"66666666-6666-4666-8666-666666666666","town":"Tie","kind":"town","flat_price_mnt":5000,"area":{"type":"Polygon","coordinates":[[[104.03,49.005],[104.03,49.015],[104.06,49.015],[104.06,49.005],[104.03,49.005]]]}},{"id":"44444444-4444-4444-8444-444444444444","town":"Small","kind":"town","flat_price_mnt":3500,"area":{"type":"Polygon","coordinates":[[[104.03,49.005],[104.03,49.015],[104.06,49.015],[104.06,49.005],[104.03,49.005]]]}}],"hole":[{"id":"44444444-4444-4444-8444-444444444444","town":"Small","kind":"town","flat_price_mnt":3500,"area":{"type":"Polygon","coordinates":[[[104.03,49.005],[104.03,49.015],[104.06,49.015],[104.06,49.005],[104.03,49.005]],[[104.039,49.009],[104.039,49.011],[104.041,49.011],[104.041,49.009],[104.039,49.009]]]}}]},"cases":[{"name":"town flat","set":"seed","p":[49.01,104.04],"d":[49.01,104.13],"tariff":[1000,1000,2000],"expected":["flat",8559,3000,3000,3000]},{"name":"center dropoff","set":"seed","p":[49.01,104.04],"d":[49.0309,104.0542],"tariff":[1000,1000,2000],"expected":["normal",3310,4300,7600,6000]},{"name":"center pickup","set":"seed","p":[49.0309,104.0542],"d":[49.01,104.04],"tariff":[1000,1000,2000],"expected":["normal",3310,4300,7600,6000]},{"name":"outside dropoff","set":"seed","p":[49.01,104.04],"d":[49.15,104.0833],"tariff":[1000,1000,2000],"expected":["normal",20654,21700,42300,32000]},{"name":"outside pickup","set":"seed","p":[49.15,104.0833],"d":[49.01,104.04],"tariff":[1000,1000,2000],"expected":["normal",20654,21700,42300,32000]},{"name":"zero distance flat","set":"seed","p":[49.01,104.04],"d":[49.01,104.04],"tariff":[1000,1000,2000],"expected":["flat",0,3000,3000,3000]},{"name":"zero distance center","set":"seed","p":[49.0309,104.0542],"d":[49.0309,104.0542],"tariff":[1000,1000,2000],"expected":["normal",0,1000,1000,1000]},{"name":"town edge 0","set":"seed","p":[49.01,104.04],"d":[49.063,104.08],"tariff":[1000,1000,2000],"expected":["flat",8554,3000,3000,3000]},{"name":"center edge 0","set":"seed","p":[49.01,104.04],"d":[49.038,104.05],"tariff":[1000,1000,2000],"expected":["normal",4158,5200,9300,7300]},{"name":"town edge 0 side -1","set":"seed","p":[49.01,104.04],"d":[49.062999000000005,104.08],"tariff":[1000,1000,2000],"expected":["flat",8554,3000,3000,3000]},{"name":"center edge 0 side -1","set":"seed","p":[49.01,104.04],"d":[49.037999,104.05],"tariff":[1000,1000,2000],"expected":["normal",4158,5200,9300,7300]},{"name":"town edge 0 side 1","set":"seed","p":[49.01,104.04],"d":[49.063001,104.08],"tariff":[1000,1000,2000],"expected":["normal",8554,9600,18100,13900]},{"name":"center edge 0 side 1","set":"seed","p":[49.01,104.04],"d":[49.038000999999994,104.05],"tariff":[1000,1000,2000],"expected":["flat",4158,3000,3000,3000]},{"name":"town edge 1","set":"seed","p":[49.01,104.04],"d":[49.003,104.08],"tariff":[1000,1000,2000],"expected":["flat",3937,3000,3000,3000]},{"name":"center edge 1","set":"seed","p":[49.01,104.04],"d":[49.022,104.05],"tariff":[1000,1000,2000],"expected":["normal",1978,3000,5000,4000]},{"name":"town edge 1 side -1","set":"seed","p":[49.01,104.04],"d":[49.002999,104.08],"tariff":[1000,1000,2000],"expected":["normal",3937,4900,8900,6900]},{"name":"center edge 1 side -1","set":"seed","p":[49.01,104.04],"d":[49.021999,104.05],"tariff":[1000,1000,2000],"expected":["flat",1978,3000,3000,3000]},{"name":"town edge 1 side 1","set":"seed","p":[49.01,104.04],"d":[49.003001,104.08],"tariff":[1000,1000,2000],"expected":["flat",3937,3000,3000,3000]},{"name":"center edge 1 side 1","set":"seed","p":[49.01,104.04],"d":[49.022000999999996,104.05],"tariff":[1000,1000,2000],"expected":["normal",1979,3000,5000,4000]},{"name":"town edge 2","set":"seed","p":[49.01,104.04],"d":[49.01,104.023],"tariff":[1000,1000,2000],"expected":["flat",1617,3000,3000,3000]},{"name":"center edge 2","set":"seed","p":[49.01,104.04],"d":[49.03,104.042],"tariff":[1000,1000,2000],"expected":["normal",2898,3900,6800,5400]},{"name":"town edge 2 side -1","set":"seed","p":[49.01,104.04],"d":[49.01,104.022999],"tariff":[1000,1000,2000],"expected":["normal",1617,2600,4200,3400]},{"name":"center edge 2 side -1","set":"seed","p":[49.01,104.04],"d":[49.03,104.041999],"tariff":[1000,1000,2000],"expected":["flat",2898,3000,3000,3000]},{"name":"town edge 2 side 1","set":"seed","p":[49.01,104.04],"d":[49.01,104.023001],"tariff":[1000,1000,2000],"expected":["flat",1617,3000,3000,3000]},{"name":"center edge 2 side 1","set":"seed","p":[49.01,104.04],"d":[49.03,104.042001],"tariff":[1000,1000,2000],"expected":["normal",2898,3900,6800,5400]},{"name":"town edge 3","set":"seed","p":[49.01,104.04],"d":[49.01,104.143],"tariff":[1000,1000,2000],"expected":["flat",9796,3000,3000,3000]},{"name":"center edge 3","set":"seed","p":[49.01,104.04],"d":[49.03,104.066],"tariff":[1000,1000,2000],"expected":["normal",3804,4800,8600,6700]},{"name":"town edge 3 side -1","set":"seed","p":[49.01,104.04],"d":[49.01,104.142999],"tariff":[1000,1000,2000],"expected":["flat",9796,3000,3000,3000]},{"name":"center edge 3 side -1","set":"seed","p":[49.01,104.04],"d":[49.03,104.065999],"tariff":[1000,1000,2000],"expected":["normal",3804,4800,8600,6700]},{"name":"town edge 3 side 1","set":"seed","p":[49.01,104.04],"d":[49.01,104.143001],"tariff":[1000,1000,2000],"expected":["normal",9796,10800,20600,15700]},{"name":"center edge 3 side 1","set":"seed","p":[49.01,104.04],"d":[49.03,104.066001],"tariff":[1000,1000,2000],"expected":["flat",3804,3000,3000,3000]},{"name":"town corner 49.063/104.023","set":"seed","p":[49.01,104.04],"d":[49.063,104.023],"tariff":[1000,1000,2000],"expected":["flat",7831,3000,3000,3000]},{"name":"town corner 49.063/104.143","set":"seed","p":[49.01,104.04],"d":[49.063,104.143],"tariff":[1000,1000,2000],"expected":["flat",12432,3000,3000,3000]},{"name":"town corner 49.003/104.143","set":"seed","p":[49.01,104.04],"d":[49.003,104.143],"tariff":[1000,1000,2000],"expected":["flat",9849,3000,3000,3000]},{"name":"town corner 49.003/104.023","set":"seed","p":[49.01,104.04],"d":[49.003,104.023],"tariff":[1000,1000,2000],"expected":["flat",1907,3000,3000,3000]},{"name":"round base 1049","set":"none","p":[49.0309,104.0542],"d":[49.0309,104.0542],"tariff":[1049,1000,2000],"expected":["normal",0,1000,1000,1000]},{"name":"round base 1050","set":"none","p":[49.0309,104.0542],"d":[49.0309,104.0542],"tariff":[1050,1000,2000],"expected":["normal",0,1100,1100,1100]},{"name":"round base 1051","set":"none","p":[49.0309,104.0542],"d":[49.0309,104.0542],"tariff":[1051,1000,2000],"expected":["normal",0,1100,1100,1100]},{"name":"different towns","set":"twoTowns","p":[49.01,104.04],"d":[49.15,104.0833],"tariff":[1000,1000,2000],"expected":["normal",20654,21700,42300,32000]},{"name":"smallest overlapping zone","set":"overlap","p":[49.01,104.04],"d":[49.012,104.05],"tariff":[1000,1000,2000],"expected":["flat",994,3500,3500,3500]},{"name":"equal area uses id","set":"tie","p":[49.01,104.04],"d":[49.012,104.05],"tariff":[1000,1000,2000],"expected":["flat",994,3500,3500,3500]},{"name":"hole interior","set":"hole","p":[49.01,104.04],"d":[49.012,104.05],"tariff":[1000,1000,2000],"expected":["normal",994,2000,3000,2500]},{"name":"hole boundary covered","set":"hole","p":[49.009,104.04],"d":[49.012,104.05],"tariff":[1000,1000,2000],"expected":["flat",1045,3500,3500,3500]},{"name":"suggested half up","set":"none","p":[49.0309,104.0542],"d":[49.0319,104.0542],"tariff":[1000,0,500],"expected":["normal",145,1000,1100,1100]},{"name":"submetre below round","set":"none","p":[49.0309,104.0542],"d":[49.030903,104.0542],"tariff":[1000,1000,2000],"expected":["normal",0,1000,1000,1000]},{"name":"submetre above round","set":"none","p":[49.0309,104.0542],"d":[49.030904,104.0542],"tariff":[1000,1000,2000],"expected":["normal",1,1000,1000,1000]}]}
$fixture$::jsonb);

DO $$
DECLARE
  fixture jsonb; test_case jsonb; z jsonb; q record; original_quote record;
  case_count integer := 0;
  company uuid := '99999999-9999-4999-8999-999999999999';
BEGIN
  SELECT data INTO fixture FROM parity_fixture;
  INSERT INTO public.companies(id,name,register_number,taxi_permit_number,permit_expires_on,status)
    VALUES(company,'Pricing fixture','TEST-PARITY-REGISTER','TEST-PARITY-PERMIT',CURRENT_DATE+365,'approved');
  INSERT INTO public.company_tariffs VALUES(company,1000,1000,2000);
  FOR test_case IN SELECT * FROM jsonb_array_elements(fixture->'cases') LOOP
    DELETE FROM public.fare_zones;
    FOR z IN SELECT * FROM jsonb_array_elements(fixture->'zoneSets'->(test_case->>'set')) LOOP
      INSERT INTO public.fare_zones(id,town,kind,area,flat_price_mnt) VALUES(
        (z->>'id')::uuid,z->>'town',z->>'kind',
        ST_SetSRID(ST_GeomFromGeoJSON((z->'area')::text),4326)::geography,
        (z->>'flat_price_mnt')::integer);
    END LOOP;
    UPDATE public.company_tariffs SET base_fare_mnt=(test_case->'tariff'->>0)::integer,
      min_per_km_mnt=(test_case->'tariff'->>1)::integer,
      max_per_km_mnt=(test_case->'tariff'->>2)::integer WHERE company_id=company;
    SELECT * INTO STRICT q FROM public.fare_quote(
      (test_case->'p'->>0)::double precision,(test_case->'p'->>1)::double precision,
      (test_case->'d'->>0)::double precision,(test_case->'d'->>1)::double precision,company);
    IF jsonb_build_array(q.ride_type,q.distance_m,q.min_price_mnt,q.max_price_mnt,q.suggested_price_mnt)
      IS DISTINCT FROM test_case->'expected' THEN
      RAISE EXCEPTION 'Pricing parity failed for %: actual %, expected %',test_case->>'name',
        row_to_json(q),test_case->'expected';
    END IF;
    -- Check quote_trip itself, not only the new public wrapper.
    SELECT * INTO STRICT original_quote FROM public.quote_trip(
      (test_case->'p'->>0)::double precision,(test_case->'p'->>1)::double precision,
      (test_case->'d'->>0)::double precision,(test_case->'d'->>1)::double precision,company);
    ASSERT original_quote.ride_type = q.ride_type;
    ASSERT original_quote.min_price_mnt = q.min_price_mnt;
    ASSERT original_quote.max_price_mnt = q.max_price_mnt;
    ASSERT original_quote.suggested_price_mnt = q.suggested_price_mnt;
    case_count := case_count+1;
  END LOOP;
  ASSERT case_count=46, 'Shared fixture count changed: review both suites';
  BEGIN
    PERFORM public.fare_quote(49.01,104.04,49.01,104.13,'00000000-0000-4000-8000-000000000000');
    RAISE EXCEPTION 'Missing company was accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN
    PERFORM public.fare_quote('NaN'::double precision,104.04,49.01,104.13,company);
    RAISE EXCEPTION 'Invalid coordinates were accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  UPDATE public.companies SET status='suspended' WHERE id=company;
  BEGIN
    PERFORM public.fare_quote(49.01,104.04,49.01,104.13,company);
    RAISE EXCEPTION 'Suspended company was accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
  RAISE NOTICE 'pricing_parity: % shared cases passed',case_count;
END;
$$;
ROLLBACK;
