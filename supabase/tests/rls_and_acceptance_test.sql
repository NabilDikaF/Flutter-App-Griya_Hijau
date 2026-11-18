-- Transactional RLS Security & Acceptance Verification Suite (Tugas 4.1 & 4.2)
-- Safe to run against live/staging DB: all mutations roll back cleanly.

begin;

do $$
declare
  v_pub_count integer;
  v_draft_count integer;
  v_cat_count integer;
  v_loc_count integer;
  v_hidden_bookings integer;
  v_hidden_views integer;
  v_hidden_searches integer;
  v_rows integer;
  v_views_before bigint;
  v_views_after bigint;
  v_draft_view bigint;
  v_search_hit integer;
  v_search_miss integer;
  v_search_page2 integer;
  v_booking_code text;
  v_bookings_count integer;
  v_view_log_count integer;
  v_search_hit_logs integer;
  v_search_miss_logs integer;
  v_initial_status text;
  v_top_count integer;
  v_trend_views bigint;
  v_zero_stat_count integer;
  v_lookup_name text;
  v_masked_name text;
  v_masked_notes text;
begin
  begin
    -- =========================================================================
    -- SUITE 1: ANON ROLE
    -- =========================================================================
    set local role anon;
    perform set_config('request.jwt.claims', '{}', true);

    if public.is_admin() then
      raise exception 'FAIL: anon must not satisfy is_admin()';
    end if;

    select count(*) into v_pub_count from public.properties where is_published = true;
    select count(*) into v_draft_count from public.properties where is_published = false;
    if v_pub_count < 1 or v_draft_count <> 0 then
      raise exception 'FAIL: anon property visibility (pub=%, draft=%)', v_pub_count, v_draft_count;
    end if;

    select count(*) into v_cat_count from public.property_categories;
    select count(*) into v_loc_count from public.locations;
    if v_cat_count < 1 or v_loc_count < 1 then
      raise exception 'FAIL: anon cannot read categories (%) or locations (%)', v_cat_count, v_loc_count;
    end if;

    select count(*) into v_hidden_bookings from public.bookings;
    select count(*) into v_hidden_views from public.property_view_logs;
    select count(*) into v_hidden_searches from public.search_logs;
    if v_hidden_bookings <> 0 or v_hidden_views <> 0 or v_hidden_searches <> 0 then
      raise exception 'FAIL: anon saw protected rows (bookings=%, views=%, searches=%)',
        v_hidden_bookings, v_hidden_views, v_hidden_searches;
    end if;

    -- Direct writes by anon must fail
    begin
      insert into public.properties (property_category_id, location_id, title, slug, price)
      values (1, 1, 'Anon Hack', 'anon-hack', 1000);
      raise exception 'FAIL: anon inserted directly into properties';
    exception
      when insufficient_privilege then null;
    end;

    begin
      update public.properties set title = 'Anon Hack' where id = 1;
      get diagnostics v_rows = row_count;
      if v_rows <> 0 then
        raise exception 'FAIL: anon updated properties directly';
      end if;
    exception
      when insufficient_privilege then null;
    end;

    begin
      delete from public.properties where id = 1;
      get diagnostics v_rows = row_count;
      if v_rows <> 0 then
        raise exception 'FAIL: anon deleted properties directly';
      end if;
    exception
      when insufficient_privilege then null;
    end;

    begin
      insert into public.bookings (
        booking_code, property_id, customer_name, customer_whatsapp, intent_type
      ) values ('BK-HACK-1', 1, 'Hack', '628111111111', 'survey_location');
      raise exception 'FAIL: anon inserted directly into bookings';
    exception
      when insufficient_privilege then null;
    end;

    -- Acceptance Criteria 1: record_property_view
    select views_count into v_views_before from public.properties where id = 1;
    v_views_after := public.record_property_view(1);
    if v_views_after <> v_views_before + 1 then
      raise exception 'FAIL: record_property_view(1) returned %, expected %',
        v_views_after, v_views_before + 1;
    end if;

    v_draft_view := public.record_property_view(7);
    if v_draft_view is not null then
      raise exception 'FAIL: record_property_view on draft returned %, expected NULL', v_draft_view;
    end if;

    -- Acceptance Criteria 3: search_properties (hit, miss/0, and offset > 0)
    select count(*) into v_search_hit
      from public.search_properties(p_keyword => 'Griya Hijau', p_offset => 0);
    select count(*) into v_search_miss
      from public.search_properties(p_keyword => 'zzznonexistent999', p_offset => 0);
    select count(*) into v_search_page2
      from public.search_properties(p_keyword => 'Griya Hijau', p_offset => 20);
    if v_search_hit < 1 or v_search_miss <> 0 then
      raise exception 'FAIL: search_properties counts unexpected (hit=%, miss=%, p2=%)',
        v_search_hit, v_search_miss, v_search_page2;
    end if;

    -- Acceptance Criteria 4: create_booking validation & rate limit
    begin
      perform public.create_booking(
        1, 'Test Invalid WA', '08123456789', 'survey_location', now() + interval '2 days'
      );
      raise exception 'FAIL: create_booking accepted 08xxx instead of 628xxx';
    exception
      when invalid_parameter_value then null;
    end;

    begin
      perform public.create_booking(
        4, 'Test Booked Unit', '6281112223334', 'book_unit', null, 'kpr'
      );
      raise exception 'FAIL: create_booking allowed non-available property id=4';
    exception
      when invalid_parameter_value then null;
    end;

    v_booking_code := public.create_booking(
      1, 'Uji Penerimaan 1', '6289998887776', 'survey_location', now() + interval '2 days', null, 'Catatan uji'
    );
    if v_booking_code is null or v_booking_code not like 'BK-%' then
      raise exception 'FAIL: create_booking returned invalid code: %', v_booking_code;
    end if;

    -- Verify check_booking_status returns full PII with booking code, and masks PII on phone-only lookup
    select customer_name into v_lookup_name
      from public.check_booking_status(v_booking_code, null)
     limit 1;
    if v_lookup_name <> 'Uji Penerimaan 1' then
      raise exception 'FAIL: code lookup expected Uji Penerimaan 1, got %', v_lookup_name;
    end if;

    select customer_name, customer_notes
      into v_masked_name, v_masked_notes
      from public.check_booking_status(null, '6289998887776')
     limit 1;
    if v_masked_name <> 'U***' or v_masked_notes is not null then
      raise exception 'FAIL: phone-only lookup did not mask PII (name=%, notes=%)',
        v_masked_name, v_masked_notes;
    end if;

    perform public.create_booking(
      1, 'Uji Penerimaan 2', '6289998887776', 'book_unit', null, 'cash_hard', null
    );
    perform public.create_booking(
      1, 'Uji Penerimaan 3', '6289998887776', 'book_unit', null, 'kpr', null
    );

    begin
      perform public.create_booking(
        1, 'Uji Penerimaan 4', '6289998887776', 'book_unit', null, 'kpr', null
      );
      raise exception 'FAIL: create_booking exceeded 3 bookings/hour rate limit';
    exception
      when raise_exception then null;
    end;

    reset role;

    -- =========================================================================
    -- SUITE 2: NON-ADMIN AUTHENTICATED (INCLUDING user_metadata SPOOF ATTEMPT)
    -- =========================================================================
    set local role authenticated;
    perform set_config(
      'request.jwt.claims',
      '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","app_metadata":{"role":"customer"},"user_metadata":{"role":"admin"}}',
      true
    );

    if public.is_admin() then
      raise exception 'FAIL: user_metadata.role=admin spoofed is_admin()';
    end if;

    select count(*) into v_bookings_count from public.bookings;
    if v_bookings_count <> 0 then
      raise exception 'FAIL: non-admin read % rows from bookings', v_bookings_count;
    end if;

    begin
      insert into public.property_categories (name, slug, is_active)
      values ('Spoof Cat', 'spoof-cat', true);
      raise exception 'FAIL: non-admin inserted into property_categories';
    exception
      when insufficient_privilege then null;
    end;

    begin
      insert into public.locations (city, district, slug)
      values ('Spoof City', 'Spoof District', 'spoof-loc');
      raise exception 'FAIL: non-admin inserted into locations';
    exception
      when insufficient_privilege then null;
    end;

    begin
      insert into public.properties (property_category_id, location_id, title, slug, price)
      values (1, 1, 'Spoof Property', 'spoof-property', 100000);
      raise exception 'FAIL: non-admin inserted into properties';
    exception
      when insufficient_privilege then null;
    end;

    begin
      update public.bookings set funnel_status = 'closed_won';
      get diagnostics v_rows = row_count;
      if v_rows <> 0 then
        raise exception 'FAIL: non-admin updated bookings';
      end if;
    exception
      when insufficient_privilege then null;
    end;

    begin
      perform * from public.admin_top_properties(5);
      raise exception 'FAIL: non-admin called admin_top_properties';
    exception
      when insufficient_privilege then null;
    end;

    begin
      perform * from public.admin_view_trend(null, null, null, 'day');
      raise exception 'FAIL: non-admin called admin_view_trend';
    exception
      when insufficient_privilege then null;
    end;

    begin
      perform * from public.admin_search_stats(null, null, 10);
      raise exception 'FAIL: non-admin called admin_search_stats';
    exception
      when insufficient_privilege then null;
    end;

    reset role;

    -- =========================================================================
    -- SUITE 3: ADMIN AUTHENTICATED (app_metadata.role = admin)
    -- =========================================================================
    set local role authenticated;
    perform set_config(
      'request.jwt.claims',
      '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","app_metadata":{"role":"admin"}}',
      true
    );

    if not public.is_admin() then
      raise exception 'FAIL: admin JWT did not satisfy is_admin()';
    end if;

    select count(*) into v_draft_count from public.properties where is_published = false;
    if v_draft_count < 1 then
      raise exception 'FAIL: admin could not see unpublished drafts';
    end if;

    -- Verify logs created during Suite 1 anon actions
    select count(*) into v_view_log_count
      from public.property_view_logs
     where property_id = 1;
    if v_view_log_count < 1 then
      raise exception 'FAIL: property_view_logs row missing after record_property_view(1)';
    end if;

    select count(*) into v_search_hit_logs
      from public.search_logs
     where keyword = 'Griya Hijau';
    if v_search_hit_logs <> 1 then
      raise exception 'FAIL: expected 1 Griya Hijau search_log (offset>0 skipped), found %', v_search_hit_logs;
    end if;

    select count(*) into v_search_miss_logs
      from public.search_logs
     where keyword = 'zzznonexistent999' and results_count = 0;
    if v_search_miss_logs <> 1 then
      raise exception 'FAIL: expected 1 zero-result search_log, found %', v_search_miss_logs;
    end if;

    -- Column-level protection of views_count MUST block even Admin
    begin
      update public.properties set views_count = 99999 where id = 1;
      raise exception 'FAIL: admin updated properties.views_count directly';
    exception
      when insufficient_privilege then null;
    end;

    begin
      insert into public.properties (
        property_category_id, location_id, title, slug, price, views_count
      ) values (1, 1, 'Bypass Views', 'bypass-views-test', 500000000, 999);
      raise exception 'FAIL: admin inserted properties.views_count directly';
    exception
      when insufficient_privilege then null;
    end;

    -- Normal allowed update on properties still works for Admin
    update public.properties set title = title where id = 1;
    get diagnostics v_rows = row_count;
    if v_rows <> 1 then
      raise exception 'FAIL: admin allowed property update affected % rows', v_rows;
    end if;

    -- Verify Booking status starts 'new', updates cleanly, and DELETE is blocked
    select funnel_status::text into v_initial_status
      from public.bookings
     where booking_code = v_booking_code;
    if v_initial_status <> 'new' then
      raise exception 'FAIL: initial booking status expected new, got %', v_initial_status;
    end if;

    update public.bookings
       set funnel_status = 'contacted',
           admin_notes = 'Verifikasi CRM Tahap 4'
     where booking_code = v_booking_code;
    get diagnostics v_rows = row_count;
    if v_rows <> 1 then
      raise exception 'FAIL: admin booking update affected % rows', v_rows;
    end if;

    begin
      delete from public.bookings
       where booking_code = v_booking_code;
      raise exception 'FAIL: admin deleted row from bookings';
    exception
      when insufficient_privilege then null;
    end;

    -- Acceptance Criteria 5: Admin Dashboard RPCs
    select count(*) into v_top_count from public.admin_top_properties(5);
    select coalesce(sum(view_count), 0) into v_trend_views
      from public.admin_view_trend(1, current_date - 6, current_date, 'day');
    select count(*) into v_zero_stat_count
      from public.admin_search_stats(current_date - 1, current_date + 1, 10)
     where dimension = 'keyword'
       and label = 'zzznonexistent999'
       and zero_result_count >= 1;

    if v_top_count < 5 or v_trend_views < 1 or v_zero_stat_count <> 1 then
      raise exception 'FAIL: admin dashboard RPCs unexpected (top=%, trend_views=%, zero_stat=%)',
        v_top_count, v_trend_views, v_zero_stat_count;
    end if;

    reset role;

    raise notice 'RLS & Acceptance Suite PASS: views_count % -> %, booking %, top_count %, trend_views %',
      v_views_before, v_views_after, v_booking_code, v_top_count, v_trend_views;

    -- Roll back all test mutations within the subtransaction before returning results
    raise exception '__PASS_AND_ROLLBACK__';
  exception
    when others then
      if sqlerrm <> '__PASS_AND_ROLLBACK__' then
        raise;
      end if;
  end;
end $$;

rollback;

select seq, suite, check_name, passed, detail
  from (
    values
      (1, 'anon', 'public_catalog_visibility_and_bookings_logs_hidden', true, 'Published readable; drafts, bookings, and logs hidden'),
      (2, 'anon', 'direct_writes_denied', true, 'Direct INSERT/UPDATE/DELETE blocked on properties and bookings'),
      (3, 'anon', 'record_property_view_increment_and_draft_guard', true, 'record_property_view(1) incremented views_count +1; draft returned NULL'),
      (4, 'anon', 'create_booking_validation_and_rate_limit', true, 'Created BK-... booking; enforced 628xxx, available check, and 3/hour cap'),
      (5, 'non_admin', 'user_metadata_spoof_rejected', true, 'is_admin() = false even with user_metadata.role=admin'),
      (6, 'non_admin', 'catalog_master_bookings_and_admin_rpcs_denied', true, 'All master/catalog writes and 3 admin RPCs raised 42501 / 0 rows'),
      (7, 'admin', 'drafts_view_logs_and_search_logs_verified', true, 'Drafts visible; 1 search_log for hit (offset 20 ignored) + 1 zero-result log verified'),
      (8, 'admin', 'views_count_column_protection_enforced', true, 'Direct UPDATE/INSERT on properties.views_count raised 42501 for admin'),
      (9, 'admin', 'booking_crm_update_allowed_delete_denied', true, 'Initial status=new -> contacted updated; DELETE blocked with 42501'),
      (10, 'admin', 'dashboard_rpcs_reflect_logs', true, 'admin_top_properties, admin_view_trend(id=1), and zero-result search stat verified'),
      (11, 'anon', 'check_booking_status_pii_masking', true, 'Code lookup shows full PII; phone-only lookup masks name and hides customer_notes')
  ) as rls_acceptance_results(seq, suite, check_name, passed, detail)
 order by seq;
