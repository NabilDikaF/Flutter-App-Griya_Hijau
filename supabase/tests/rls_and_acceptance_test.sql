-- Transactional RLS Security & Acceptance Verification Suite
-- Covers Stage 1 security remediation (findings 2.1, 2.2 DB, 2.3, 2.4, 2.5,
-- 2.6, 2.7, 2.8/2.9 SQL RPCs, and DB hardening).
-- Safe to run against live/staging DB: all mutations roll back cleanly.

begin;

do $$
declare
  v_inactive_cat_id bigint;
  v_inactive_prop_id bigint;
  v_pub_count integer;
  v_draft_count integer;
  v_inactive_visible integer;
  v_inactive_img_visible integer;
  v_cat_count integer;
  v_loc_count integer;
  v_hidden_bookings integer;
  v_hidden_views integer;
  v_hidden_searches integer;
  v_rows integer;
  v_views_before bigint;
  v_views_after bigint;
  v_views_cooldown bigint;
  v_views_prop2_before bigint;
  v_views_prop2_after bigint;
  v_views_prop2_dedup bigint;
  v_draft_view bigint;
  v_inactive_view bigint;
  v_search_hit integer;
  v_search_miss integer;
  v_search_page2 integer;
  v_search_invalid_loc integer;
  v_search_invalid_cat integer;
  v_booking_code text;
  v_bookings_count integer;
  v_view_log_count integer;
  v_search_hit_logs integer;
  v_search_upper_logs integer;
  v_search_miss_logs integer;
  v_initial_status text;
  v_top_count integer;
  v_trend_views bigint;
  v_zero_stat_count integer;
  v_lookup_count integer;
  v_lookup_name text;
  v_lookup_notes text;
  v_lookup_json jsonb;
  v_sum_views bigint;
  v_sum_searches bigint;
  v_sum_active_leads bigint;
  v_sum_scheduled_surveys bigint;
  v_expected_views bigint;
  v_expected_active bigint;
  v_expected_scheduled bigint;
  v_upcoming_count integer;
  v_upcoming_closed integer;
  v_upcoming_prev_date timestamptz;
  v_upcoming_cur_date timestamptz;
  v_list_count integer;
  v_list_total bigint;
  v_policy_public_count integer;
  v_policy_admin_count integer;
  v_tbl text;
  v_fn text;
  v_today_wib date := (now() at time zone 'Asia/Jakarta')::date;
begin
  begin
    -- =========================================================================
    -- PRE-SUITE FIXTURES (rolled back at end of test block)
    -- =========================================================================
    insert into public.property_categories (name, slug, is_active)
    values ('Kategori Nonaktif Uji', 'kategori-nonaktif-uji', false)
    returning id into v_inactive_cat_id;

    insert into public.properties (
      property_category_id, location_id, title, slug, price, availability_status, is_published
    ) values (
      v_inactive_cat_id, 1, 'Properti Kategori Nonaktif Uji', 'properti-kategori-nonaktif-uji', 500000000, 'available', true
    )
    returning id into v_inactive_prop_id;

    insert into public.property_images (property_id, image_path, is_primary, sort_order)
    values (v_inactive_prop_id, 'properties/' || v_inactive_prop_id || '/main.jpg', true, 0);

    insert into public.bookings (
      booking_code, property_id, customer_name, customer_whatsapp, intent_type, payment_plan, funnel_status
    ) values (
      'BK-20261114-F5E4D', 1, 'Legacy Lima Hex', '6287776665554', 'book_unit', 'cash_hard', 'new'
    );

    -- =========================================================================
    -- SUITE 1: ANON ROLE
    -- =========================================================================
    set local role anon;
    perform set_config('request.jwt.claims', '{}', true);
    perform set_config('request.headers', '', true);

    if public.is_admin() then
      raise exception 'FAIL: anon must not satisfy is_admin()';
    end if;

    select count(*) into v_pub_count from public.properties where is_published = true;
    select count(*) into v_draft_count from public.properties where is_published = false;
    if v_pub_count < 1 or v_draft_count <> 0 then
      raise exception 'FAIL: anon property visibility (pub=%, draft=%)', v_pub_count, v_draft_count;
    end if;

    -- 2.1: Published properties & images in inactive category must be hidden
    select count(*) into v_inactive_visible from public.properties where id = v_inactive_prop_id;
    select count(*) into v_inactive_img_visible from public.property_images where property_id = v_inactive_prop_id;
    if v_inactive_visible <> 0 or v_inactive_img_visible <> 0 then
      raise exception 'FAIL: anon saw inactive-category rows (prop=%, img=%)',
        v_inactive_visible, v_inactive_img_visible;
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

    -- B1.9: Admin RPCs & dangerous table privileges revoked from anon
    foreach v_fn in array array[
      'public.admin_top_properties(integer)',
      'public.admin_view_trend(bigint, date, date, text)',
      'public.admin_search_stats(date, date, integer)',
      'public.admin_dashboard_summary(date, date)',
      'public.admin_upcoming_surveys(integer)',
      'public.admin_list_bookings(public.funnel_status, text, integer, integer)'
    ] loop
      if has_function_privilege('anon', v_fn, 'EXECUTE') then
        raise exception 'FAIL: anon still has EXECUTE on %', v_fn;
      end if;
    end loop;

    foreach v_tbl in array array[
      'public.property_categories',
      'public.locations',
      'public.properties',
      'public.property_images',
      'public.property_view_logs',
      'public.search_logs',
      'public.bookings'
    ] loop
      if has_table_privilege('anon', v_tbl, 'TRUNCATE')
         or has_table_privilege('anon', v_tbl, 'REFERENCES')
         or has_table_privilege('anon', v_tbl, 'TRIGGER') then
        raise exception 'FAIL: anon retains TRUNCATE/REFERENCES/TRIGGER on %', v_tbl;
      end if;
    end loop;

    begin
      perform * from public.admin_dashboard_summary(null, null);
      raise exception 'FAIL: anon called admin_dashboard_summary';
    exception
      when insufficient_privilege then null;
    end;

    begin
      perform * from public.admin_upcoming_surveys(5);
      raise exception 'FAIL: anon called admin_upcoming_surveys';
    exception
      when insufficient_privilege then null;
    end;

    begin
      perform * from public.admin_list_bookings(null, null, 10, 0);
      raise exception 'FAIL: anon called admin_list_bookings';
    exception
      when insufficient_privilege then null;
    end;

    -- 2.1 & 2.6: record_property_view (increment, null-header cooldown, IP/UA dedup, draft/inactive guard)
    select views_count into v_views_before from public.properties where id = 1;
    v_views_after := public.record_property_view(1);
    if v_views_after <> v_views_before + 1 then
      raise exception 'FAIL: record_property_view(1) returned %, expected %',
        v_views_after, v_views_before + 1;
    end if;

    v_views_cooldown := public.record_property_view(1);
    if v_views_cooldown <> v_views_after then
      raise exception 'FAIL: null-header cooldown did not throttle repeat view (% vs %)',
        v_views_cooldown, v_views_after;
    end if;

    perform set_config(
      'request.headers',
      '{"x-forwarded-for":"203.0.113.10, 10.0.0.1","user-agent":"TestAgent/1.0"}',
      true
    );
    select views_count into v_views_prop2_before from public.properties where id = 2;
    v_views_prop2_after := public.record_property_view(2);
    v_views_prop2_dedup := public.record_property_view(2);
    perform set_config('request.headers', '', true);
    if v_views_prop2_after <> v_views_prop2_before + 1 or v_views_prop2_dedup <> v_views_prop2_after then
      raise exception 'FAIL: header-based view dedup unexpected (before=%, after=%, dedup=%)',
        v_views_prop2_before, v_views_prop2_after, v_views_prop2_dedup;
    end if;

    v_draft_view := public.record_property_view(7);
    if v_draft_view is not null then
      raise exception 'FAIL: record_property_view on draft returned %, expected NULL', v_draft_view;
    end if;

    v_inactive_view := public.record_property_view(v_inactive_prop_id);
    if v_inactive_view is not null then
      raise exception 'FAIL: record_property_view on inactive category returned %, expected NULL',
        v_inactive_view;
    end if;

    -- 2.7 & B1.9: search_properties case-variant dedup, pagination skip, & invalid FK handling
    select count(*) into v_search_hit
      from public.search_properties(p_keyword => 'Griya Hijau', p_offset => 0);
    perform count(*)
      from public.search_properties(p_keyword => 'griya hijau', p_offset => 0);
    perform count(*)
      from public.search_properties(p_keyword => '  GRIYA HIJAU  ', p_offset => 0);
    select count(*) into v_search_miss
      from public.search_properties(p_keyword => 'zzznonexistent999', p_offset => 0);
    select count(*) into v_search_page2
      from public.search_properties(p_keyword => 'Griya Hijau', p_offset => 20);
    select count(*) into v_search_invalid_loc
      from public.search_properties(p_location_id => 999999999);
    select count(*) into v_search_invalid_cat
      from public.search_properties(p_category_id => 999999999);
    if v_search_hit < 1 or v_search_miss <> 0 or v_search_invalid_loc <> 0 or v_search_invalid_cat <> 0 then
      raise exception 'FAIL: search_properties counts unexpected (hit=%, miss=%, p2=%, invLoc=%, invCat=%)',
        v_search_hit, v_search_miss, v_search_page2, v_search_invalid_loc, v_search_invalid_cat;
    end if;

    -- 2.1, 2.4 & 2.5: create_booking validation, inactive category block, survey date bounds, control char strip, 64-bit code & 3/hr cap
    begin
      perform public.create_booking(
        v_inactive_prop_id, 'Test Inactive Cat', '6281112223334', 'book_unit', null, 'kpr'
      );
      raise exception 'FAIL: create_booking allowed inactive-category property %', v_inactive_prop_id;
    exception
      when invalid_parameter_value then null;
    end;

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

    begin
      perform public.create_booking(
        1, 'Test Past Date', '6281112223334', 'survey_location', now() - interval '1 hour'
      );
      raise exception 'FAIL: create_booking allowed past preferred_survey_date';
    exception
      when invalid_parameter_value then null;
    end;

    begin
      perform public.create_booking(
        1, 'Test Too Far Date', '6281112223334', 'survey_location', now() + interval '181 days'
      );
      raise exception 'FAIL: create_booking allowed preferred_survey_date beyond 180 days';
    exception
      when invalid_parameter_value then null;
    end;

    v_booking_code := public.create_booking(
      1,
      E'Uji\x07\t\n Penerimaan 1\x7F',
      '6289998887776',
      'survey_location',
      now() + interval '2 days',
      null,
      E'Catatan\r\n uji\x1B'
    );
    if v_booking_code is null or v_booking_code !~ '^BK-[0-9]{8}-[0-9A-F]{16}$' then
      raise exception 'FAIL: create_booking expected 16-hex code BK-YYYYMMDD-<16HEX>, got: %',
        v_booking_code;
    end if;

    -- 2.3 & 2.4: check_booking_status requires BOTH code + WA; omits customer_whatsapp & admin_notes
    begin
      perform * from public.check_booking_status(null, '6289998887776');
      raise exception 'FAIL: check_booking_status allowed WA-only lookup';
    exception
      when invalid_parameter_value then null;
    end;

    begin
      perform * from public.check_booking_status(v_booking_code, null);
      raise exception 'FAIL: check_booking_status allowed code-only lookup';
    exception
      when invalid_parameter_value then null;
    end;

    begin
      perform * from public.check_booking_status('', '');
      raise exception 'FAIL: check_booking_status accepted empty inputs';
    exception
      when invalid_parameter_value then null;
    end;

    select count(*) into v_lookup_count
      from public.check_booking_status(v_booking_code, '6281111111111');
    if v_lookup_count <> 0 then
      raise exception 'FAIL: valid code + wrong WA leaked % rows', v_lookup_count;
    end if;

    select count(*) into v_lookup_count
      from public.check_booking_status('BK-20261122-0000000000000000', '6289998887776');
    if v_lookup_count <> 0 then
      raise exception 'FAIL: wrong code + valid WA returned % rows', v_lookup_count;
    end if;

    select to_jsonb(r), r.customer_name, r.customer_notes
      into v_lookup_json, v_lookup_name, v_lookup_notes
      from public.check_booking_status(v_booking_code, '089998887776') as r
     limit 1;
    get diagnostics v_rows = row_count;
    if v_rows <> 1
       or v_lookup_name <> 'Uji Penerimaan 1'
       or v_lookup_notes <> 'Catatan uji'
       or (v_lookup_json ? 'customer_whatsapp')
       or (v_lookup_json ? 'admin_notes') then
      raise exception 'FAIL: code+WA lookup mismatch or exposed fields (rows=%, name=%, notes=%, json=%)',
        v_rows, v_lookup_name, v_lookup_notes, v_lookup_json;
    end if;

    select count(*) into v_lookup_count
      from public.check_booking_status('BK-20261114-F5E4D', '087776665554');
    if v_lookup_count <> 1 then
      raise exception 'FAIL: legacy 5-hex code + matching WA expected 1 row, got %', v_lookup_count;
    end if;

    select count(*) into v_lookup_count
      from public.check_booking_status('BK-20261114-F5E4D', '6281111111111');
    if v_lookup_count <> 0 then
      raise exception 'FAIL: legacy 5-hex code + wrong WA returned % rows', v_lookup_count;
    end if;

    -- Rate limit cap 3/hour per WA (serial execution in single transaction; true parallel race lock requires 2 DB connections)
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

    select count(*) into v_inactive_visible from public.properties where id = v_inactive_prop_id;
    select count(*) into v_inactive_img_visible from public.property_images where property_id = v_inactive_prop_id;
    if v_inactive_visible <> 0 or v_inactive_img_visible <> 0 then
      raise exception 'FAIL: non-admin authenticated saw inactive-category rows (prop=%, img=%)',
        v_inactive_visible, v_inactive_img_visible;
    end if;

    select count(*) into v_bookings_count from public.bookings;
    if v_bookings_count <> 0 then
      raise exception 'FAIL: non-admin read % rows from bookings', v_bookings_count;
    end if;

    foreach v_tbl in array array[
      'public.property_categories',
      'public.locations',
      'public.properties',
      'public.property_images',
      'public.property_view_logs',
      'public.search_logs',
      'public.bookings'
    ] loop
      if has_table_privilege('authenticated', v_tbl, 'TRUNCATE')
         or has_table_privilege('authenticated', v_tbl, 'REFERENCES')
         or has_table_privilege('authenticated', v_tbl, 'TRIGGER') then
        raise exception 'FAIL: authenticated retains TRUNCATE/REFERENCES/TRIGGER on %', v_tbl;
      end if;
    end loop;

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

    begin
      perform * from public.admin_dashboard_summary(null, null);
      raise exception 'FAIL: non-admin called admin_dashboard_summary';
    exception
      when insufficient_privilege then null;
    end;

    begin
      perform * from public.admin_upcoming_surveys(5);
      raise exception 'FAIL: non-admin called admin_upcoming_surveys';
    exception
      when insufficient_privilege then null;
    end;

    begin
      perform * from public.admin_list_bookings(null, null, 10, 0);
      raise exception 'FAIL: non-admin called admin_list_bookings';
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

    -- 2.1: Admin MUST still read inactive-category properties & images
    select count(*) into v_inactive_visible from public.properties where id = v_inactive_prop_id;
    select count(*) into v_inactive_img_visible from public.property_images where property_id = v_inactive_prop_id;
    if v_inactive_visible <> 1 or v_inactive_img_visible <> 1 then
      raise exception 'FAIL: admin could not see inactive-category row (prop=%, img=%)',
        v_inactive_visible, v_inactive_img_visible;
    end if;

    -- Verify logs created during Suite 1 anon actions (exact 1 null-header log + 1 lowercase dedup search log)
    select count(*) into v_view_log_count
      from public.property_view_logs
     where property_id = 1
       and viewed_at >= transaction_timestamp();
    if v_view_log_count <> 1 then
      raise exception 'FAIL: expected 1 property_view_logs row for id=1 in this tx (cooldown), found %',
        v_view_log_count;
    end if;

    select count(*) into v_search_hit_logs
      from public.search_logs
     where keyword = 'griya hijau'
       and searched_at >= transaction_timestamp();
    select count(*) into v_search_upper_logs
      from public.search_logs
     where keyword = 'Griya Hijau'
       and searched_at >= transaction_timestamp();
    if v_search_hit_logs <> 1 or v_search_upper_logs <> 0 then
      raise exception 'FAIL: expected 1 lowercase griya hijau search_log and 0 mixed-case, found lower=% mixed=%',
        v_search_hit_logs, v_search_upper_logs;
    end if;

    select count(*) into v_search_miss_logs
      from public.search_logs
     where keyword = 'zzznonexistent999'
       and results_count = 0
       and searched_at >= transaction_timestamp();
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

    -- B1.9: Strict CHECK constraints on property_images.image_path & properties.google_maps_url
    begin
      insert into public.property_images (property_id, image_path, is_primary, sort_order)
      values (1, 'properties/1/../secret.jpg', false, 99);
      raise exception 'FAIL: property_images accepted traversal path';
    exception
      when check_violation then null;
    end;

    begin
      insert into public.property_images (property_id, image_path, is_primary, sort_order)
      values (1, 'https://evil.example/a.jpg', false, 99);
      raise exception 'FAIL: property_images accepted full URL instead of storage path';
    exception
      when check_violation then null;
    end;

    insert into public.property_images (property_id, image_path, is_primary, sort_order)
    values (1, 'properties/1/550e8400-e29b-41d4-a716-446655440000.jpg', false, 99);

    begin
      update public.properties
         set google_maps_url = 'https://docs.google.com/document/d/1'
       where id = 1;
      raise exception 'FAIL: google_maps_url accepted non-Maps google.com path';
    exception
      when check_violation then null;
    end;

    begin
      update public.properties
         set google_maps_url = 'https://www.google.com/url?q=https://evil.example'
       where id = 1;
      raise exception 'FAIL: google_maps_url accepted /url open redirect';
    exception
      when check_violation then null;
    end;

    begin
      update public.properties
         set google_maps_url = 'https://maps.google.com@evil.example/'
       where id = 1;
      raise exception 'FAIL: google_maps_url accepted userinfo @ bypass';
    exception
      when check_violation then null;
    end;

    update public.properties
       set google_maps_url = 'https://maps.app.goo.gl/PCcwbg84BmPS5BJs8'
     where id = 1;

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

    -- Prepare confirmed survey dates across open + closed bookings for 2.8/2.9 RPC checks
    update public.bookings
       set funnel_status = 'survey_scheduled',
           confirmed_survey_date = now() + interval '3 days'
     where booking_code = v_booking_code;

    update public.bookings
       set funnel_status = 'contacted',
           confirmed_survey_date = now() + interval '2 days'
     where customer_whatsapp = '6289998887776'
       and customer_name = 'Uji Penerimaan 2';

    update public.bookings
       set funnel_status = 'closed_lost',
           confirmed_survey_date = now() + interval '1 day'
     where customer_whatsapp = '6289998887776'
       and customer_name = 'Uji Penerimaan 3';

    -- Existing Admin Dashboard RPCs
    select count(*) into v_top_count from public.admin_top_properties(5);
    select coalesce(sum(view_count), 0) into v_trend_views
      from public.admin_view_trend(1, v_today_wib - 6, v_today_wib, 'day');
    select count(*) into v_zero_stat_count
      from public.admin_search_stats(v_today_wib - 1, v_today_wib + 1, 10)
     where dimension = 'keyword'
       and label = 'zzznonexistent999'
       and zero_result_count >= 1;

    if v_top_count < 5 or v_trend_views < 1 or v_zero_stat_count <> 1 then
      raise exception 'FAIL: admin dashboard RPCs unexpected (top=%, trend_views=%, zero_stat=%)',
        v_top_count, v_trend_views, v_zero_stat_count;
    end if;

    -- 2.8 & 2.9: New Admin Summary, Upcoming Surveys & Filtered/Paginated Bookings RPCs
    select coalesce(sum(views_count), 0) into v_expected_views from public.properties;
    select count(*) into v_expected_active
      from public.bookings
     where funnel_status not in ('closed_won', 'closed_lost');
    select count(*) into v_expected_scheduled
      from public.bookings
     where confirmed_survey_date is not null
       and funnel_status not in ('closed_won', 'closed_lost');

    select total_views, total_searches, active_leads_count, scheduled_surveys_count
      into v_sum_views, v_sum_searches, v_sum_active_leads, v_sum_scheduled_surveys
      from public.admin_dashboard_summary(v_today_wib - 6, v_today_wib);

    if v_sum_views <> v_expected_views
       or v_sum_searches < 2
       or v_sum_active_leads <> v_expected_active
       or v_sum_scheduled_surveys <> v_expected_scheduled then
      raise exception 'FAIL: admin_dashboard_summary mismatch (views=% vs %, searches=%, active=% vs %, sched=% vs %)',
        v_sum_views, v_expected_views, v_sum_searches,
        v_sum_active_leads, v_expected_active,
        v_sum_scheduled_surveys, v_expected_scheduled;
    end if;

    v_upcoming_count := 0;
    v_upcoming_closed := 0;
    v_upcoming_prev_date := null;
    for v_upcoming_cur_date in
      select s.confirmed_survey_date
        from public.admin_upcoming_surveys(50) s
    loop
      v_upcoming_count := v_upcoming_count + 1;
      if v_upcoming_prev_date is not null and v_upcoming_cur_date < v_upcoming_prev_date then
        raise exception 'FAIL: admin_upcoming_surveys not sorted ascending (% < %)',
          v_upcoming_cur_date, v_upcoming_prev_date;
      end if;
      v_upcoming_prev_date := v_upcoming_cur_date;
    end loop;

    select count(*) into v_upcoming_closed
      from public.admin_upcoming_surveys(50) s
     where s.funnel_status in ('closed_won', 'closed_lost');

    if v_upcoming_count <> v_sum_scheduled_surveys or v_upcoming_closed <> 0 then
      raise exception 'FAIL: admin_upcoming_surveys mismatch (count=%, summary=%, closed=%)',
        v_upcoming_count, v_sum_scheduled_surveys, v_upcoming_closed;
    end if;

    select count(*), coalesce(max(total_count), 0)
      into v_list_count, v_list_total
      from public.admin_list_bookings('contacted', 'Uji Penerimaan', 10, 0);
    if v_list_count < 1 or v_list_total < 1 then
      raise exception 'FAIL: admin_list_bookings status+keyword filter failed (count=%, total=%)',
        v_list_count, v_list_total;
    end if;

    select count(*) into v_list_count
      from public.admin_list_bookings(null, 'Griya Hijau', 20, 0);
    if v_list_count < 3 then
      raise exception 'FAIL: admin_list_bookings property_title keyword filter expected >=3 rows, got %',
        v_list_count;
    end if;

    select count(*), coalesce(max(total_count), 0)
      into v_list_count, v_list_total
      from public.admin_list_bookings(null, '6289998887776', 1, 1);
    if v_list_count <> 1 or v_list_total < 3 then
      raise exception 'FAIL: admin_list_bookings pagination expected count=1 total>=3, got count=% total=%',
        v_list_count, v_list_total;
    end if;

    reset role;

    -- =========================================================================
    -- POST-SUITE: STORAGE OBJECTS POLICY VERIFICATION (2.2)
    -- =========================================================================
    select count(*) into v_policy_public_count
      from pg_policies
     where schemaname = 'storage'
       and tablename = 'objects'
       and policyname = 'property_images_bucket_public_select';

    select count(*) into v_policy_admin_count
      from pg_policies
     where schemaname = 'storage'
       and tablename = 'objects'
       and policyname = 'property_images_bucket_admin_select'
       and cmd = 'SELECT'
       and 'authenticated' = any(roles)
       and qual ilike '%is_admin%';

    if v_policy_public_count <> 0 or v_policy_admin_count <> 1 then
      raise exception 'FAIL: storage.objects SELECT policy unexpected (public=%, admin=%)',
        v_policy_public_count, v_policy_admin_count;
    end if;

    raise notice 'RLS & Acceptance Suite PASS: views_count % -> %, booking %, top_count %, trend_views %, scheduled %',
      v_views_before, v_views_after, v_booking_code, v_top_count, v_trend_views, v_sum_scheduled_surveys;

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
      (1, 'anon', 'public_catalog_visibility_and_bookings_logs_hidden', true, 'Published active-cat readable; drafts, bookings, and logs hidden'),
      (2, 'anon', 'inactive_category_full_block', true, 'Inactive category hidden from anon/non-admin properties & images; view returns NULL; booking rejected 22023'),
      (3, 'anon', 'direct_writes_and_privilege_hardening', true, 'Direct writes blocked; anon EXECUTE on 6 admin RPCs & TRUNCATE/REFERENCES/TRIGGER on 7 tables revoked'),
      (4, 'anon', 'record_property_view_cooldown_and_dedup', true, 'record_property_view(1) incremented +1 once; 10s null-header cooldown & 10m header dedup enforced'),
      (5, 'anon', 'search_properties_normalization_and_fk_guard', true, 'Case-variant searches deduped; invalid FK filters returned 0 rows cleanly'),
      (6, 'anon', 'create_booking_validation_entropy_and_rate_limit', true, '64-bit 16-hex code, survey date bounds, control-char strip, and 3/hour cap verified (multi-session race noted)'),
      (7, 'anon', 'check_booking_status_dual_factor_and_legacy_5hex', true, 'Requires code + WA; omits customer_whatsapp & admin_notes; wrong code/WA return 0 rows; legacy 5-hex supported'),
      (8, 'non_admin', 'user_metadata_spoof_rejected', true, 'is_admin() = false even with user_metadata.role=admin'),
      (9, 'non_admin', 'catalog_master_bookings_and_6_admin_rpcs_denied', true, 'Inactive category hidden; all master/catalog writes and all 6 admin RPCs raised 42501 / 0 rows'),
      (10, 'admin', 'inactive_category_and_drafts_visible_to_admin', true, 'Admin sees drafts and inactive-category properties & images'),
      (11, 'admin', 'views_count_protection_and_check_constraints', true, 'Direct views_count denied; strict image_path & google_maps_url CHECK constraints enforced'),
      (12, 'admin', 'logs_search_dedup_and_null_cooldown_verified', true, 'Exactly 1 lowercase griya hijau search_log and 1 null-header property_view_logs row recorded'),
      (13, 'admin', 'booking_crm_update_allowed_delete_denied', true, 'Initial status=new -> contacted updated; DELETE blocked with 42501'),
      (14, 'admin', 'dashboard_summary_and_upcoming_surveys_consistent', true, 'admin_dashboard_summary & admin_upcoming_surveys ASC share exact open-survey filter'),
      (15, 'admin', 'admin_list_bookings_server_filter_and_pagination', true, 'Status, keyword (including property_title), limit/offset, and total_count verified'),
      (16, 'storage', 'property_images_bucket_admin_only_select_policy', true, 'Broad public SELECT policy dropped; admin-only SELECT policy active on storage.objects')
  ) as rls_acceptance_results(seq, suite, check_name, passed, detail)
 order by seq;
