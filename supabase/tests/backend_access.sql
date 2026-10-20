-- Disposable Supabase/PostGIS database ONLY, after 0001 and 0002.
-- Synthetic auth rows exist only inside this rolled-back transaction; no Auth
-- signup, real phone/email, network request or permanent account is created.
-- psql -X -v ON_ERROR_STOP=1 -f supabase/tests/backend_access.sql
BEGIN;
SET LOCAL plpgsql.check_asserts = on;
INSERT INTO auth.users(id) VALUES
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
INSERT INTO public.companies(id,name,register_number,taxi_permit_number,permit_expires_on,status)
  VALUES('99999999-9999-4999-8999-999999999999','Public fare fixture',
    'TEST-ACCESS-REGISTER','TEST-ACCESS-PERMIT',CURRENT_DATE+365,'approved');
INSERT INTO public.company_tariffs VALUES('99999999-9999-4999-8999-999999999999',1000,1000,2000);

SET LOCAL ROLE anon;
DO $$
DECLARE catalog jsonb; company jsonb; q record;
BEGIN
  ASSERT NOT has_table_privilege(current_user,'public.saved_places','SELECT');
  ASSERT NOT has_table_privilege(current_user,'public.place_reports','SELECT');
  ASSERT NOT has_table_privilege(current_user,'public.company_tariffs','SELECT');
  ASSERT NOT has_table_privilege(current_user,'public.fare_zones','SELECT');
  ASSERT NOT has_table_privilege(current_user,'public.profiles','SELECT');
  catalog := public.fare_catalog();
  ASSERT jsonb_typeof(catalog->'zones')='array';
  ASSERT jsonb_typeof(catalog->'companies')='array';
  FOR company IN SELECT * FROM jsonb_array_elements(catalog->'companies') LOOP
    ASSERT NOT company ? 'register_number';
    ASSERT NOT company ? 'taxi_permit_number';
    ASSERT NOT company ? 'phone';
  END LOOP;
  SELECT * INTO STRICT q FROM public.fare_quote(49.01,104.04,49.03,104.05,
    '99999999-9999-4999-8999-999999999999');
  ASSERT q.suggested_price_mnt BETWEEN q.min_price_mnt AND q.max_price_mnt;
END;
$$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SET LOCAL ROLE authenticated;
INSERT INTO public.saved_places(owner_id,kind,place) VALUES(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','home',
  '{"id":"fixture","name":"Test place","area":"Erdenet","lat":49.03,"lon":104.05,"kind":"other"}');
INSERT INTO public.place_reports(owner_id,client_id,place,note,reported_at) VALUES(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','report-one',
  '{"id":"fixture","name":"Test place","area":"Erdenet","lat":49.03,"lon":104.05,"kind":"other"}',
  'Test correction',now());
-- Retrying a locally queued report must not create duplicates.
INSERT INTO public.place_reports(owner_id,client_id,place,note,reported_at)
  SELECT owner_id,client_id,place,note,reported_at FROM public.place_reports
  ON CONFLICT(owner_id,client_id) DO NOTHING;
DO $$
BEGIN
  ASSERT (SELECT count(*)=1 FROM public.saved_places);
  ASSERT (SELECT count(*)=1 FROM public.place_reports);
  ASSERT NOT has_column_privilege(current_user,'public.saved_places','updated_at','UPDATE');
  ASSERT NOT has_table_privilege(current_user,'public.place_reports','UPDATE');
  ASSERT NOT has_table_privilege(current_user,'public.place_reports','DELETE');
  BEGIN
    UPDATE public.saved_places SET owner_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    RAISE EXCEPTION 'Owner transfer was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.saved_places(owner_id,kind,place)
      SELECT 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','work',place FROM public.saved_places;
    RAISE EXCEPTION 'Cross-owner insert was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.place_reports(owner_id,client_id,place,note,reported_at)
      SELECT owner_id,'empty-note',place,' ',now() FROM public.place_reports;
    RAISE EXCEPTION 'Blank report was allowed';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN
    UPDATE public.saved_places SET place=jsonb_set(place,'{lat}','999'::jsonb);
    RAISE EXCEPTION 'Invalid coordinate was allowed';
  EXCEPTION WHEN check_violation THEN NULL; END;
END;
$$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE affected integer;
BEGIN
  ASSERT (SELECT count(*)=0 FROM public.saved_places), 'Other user saw Home';
  ASSERT (SELECT count(*)=0 FROM public.place_reports), 'Other user saw reports';
  UPDATE public.saved_places SET kind='work' WHERE owner_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  GET DIAGNOSTICS affected = ROW_COUNT;
  ASSERT affected=0, 'Other user changed Home';
END;
$$;
RESET ROLE;
DO $$
BEGIN
  ASSERT (SELECT relrowsecurity FROM pg_class WHERE oid='public.saved_places'::regclass);
  ASSERT (SELECT relrowsecurity FROM pg_class WHERE oid='public.place_reports'::regclass);
  ASSERT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.rides'::regclass AND tgname='rides_prepare' AND tgenabled='O');
  ASSERT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.ride_offers'::regclass AND tgname='ride_offers_price_check' AND tgenabled='O');
  ASSERT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.vehicles'::regclass AND tgname='vehicles_age_check' AND tgenabled='O');
  RAISE NOTICE 'backend_access: public fare and private place checks passed';
END;
$$;
ROLLBACK;
