-- 14_geofence_broadcast_reminders_reports.sql  (jalankan SETELAH 12 dan 13; aman dijalankan ulang)
-- Isi: geofence + check-in "Saya aman", pengumuman massal, pengingat otomatis, rekap absensi.

-- ---------- Util ----------
create or replace function public.geo_distance_m(lat1 double precision, lng1 double precision, lat2 double precision, lng2 double precision)
returns double precision language sql immutable as $$
  select 6371000 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2))) $$;

create or replace function public.notify_admins(p_type text, p_title text, p_body text, p_link text) returns void
language sql security definer set search_path = public as $$
  insert into notifications(member_id, type, title, body, link)
  select distinct mr.member_id, p_type, p_title, p_body, p_link
  from member_roles mr join roles r on r.id = mr.role_id where r.code = 'SUPER_ADMIN' $$;
revoke all on function public.notify_admins(text, text, text, text) from public, anon, authenticated;

-- ---------- Geofence ----------
create table if not exists public.geofences(
  id uuid primary key default gen_random_uuid(),
  name text not null,
  lat double precision not null,
  lng double precision not null,
  radius_m integer not null check (radius_m between 50 and 50000),
  active boolean not null default true,
  created_by uuid references public.members(id) on delete set null,
  created_at timestamptz not null default now());

create table if not exists public.member_geofence_state(
  member_id uuid not null references public.members(id) on delete cascade,
  geofence_id uuid not null references public.geofences(id) on delete cascade,
  inside boolean not null,
  changed_at timestamptz not null default now(),
  primary key (member_id, geofence_id));

alter table public.geofences enable row level security;
alter table public.member_geofence_state enable row level security;
drop policy if exists gf_select on public.geofences;
create policy gf_select on public.geofences for select using (public.can_view_location());
drop policy if exists gfs_select on public.member_geofence_state;
create policy gfs_select on public.member_geofence_state for select using (public.can_view_location());
revoke insert, update, delete on public.geofences, public.member_geofence_state from anon, authenticated;
revoke all on public.geofences, public.member_geofence_state from anon;

create or replace function public.admin_save_geofence(p_id uuid, p_name text, p_lat double precision, p_lng double precision, p_radius integer, p_active boolean default true)
returns uuid language plpgsql security definer set search_path = public as $$
declare rid uuid;
begin
  if not can_view_location() then raise exception 'forbidden'; end if;
  if coalesce(trim(p_name), '') = '' or p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'invalid'; end if;
  if p_id is null then
    insert into geofences(name, lat, lng, radius_m, active, created_by)
    values (left(trim(p_name), 80), p_lat, p_lng, p_radius, p_active, current_member_id()) returning id into rid;
  else
    update geofences set name = left(trim(p_name), 80), lat = p_lat, lng = p_lng, radius_m = p_radius, active = p_active
    where id = p_id returning id into rid;
  end if;
  perform log_event('geofence_save', 'tracking', rid::text);
  return rid;
end $$;

create or replace function public.admin_delete_geofence(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not can_view_location() then raise exception 'forbidden'; end if;
  delete from geofences where id = p_id;
  perform log_event('geofence_delete', 'tracking', p_id::text);
end $$;

-- ---------- Check-in "Saya aman" ----------
alter table public.member_location_state add column if not exists last_checkin_at timestamptz;
alter table public.member_location_state add column if not exists last_checkin_note text;

create or replace function public.check_in_safe(p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := current_member_id(); was_sos boolean; nm text;
begin
  if me is null then raise exception 'not a member'; end if;
  select coalesce(sos, false) into was_sos from member_location_state where member_id = me;
  insert into member_location_state(member_id, consent, last_checkin_at, last_checkin_note)
  values (me, false, now(), left(p_note, 200))
  on conflict (member_id) do update set last_checkin_at = now(), last_checkin_note = left(p_note, 200),
    sos = false, sos_note = null, updated_at = now();
  if coalesce(was_sos, false) then
    select coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota') into nm from members m where m.id = me;
    perform notify_admins('info', nm || ' menandai dirinya aman', 'SOS dibatalkan oleh anggota.', '/tracking');
  end if;
  perform log_event('checkin_safe', 'tracking', me::text);
end $$;

-- Tabel lokasi untuk admin (kolom bertambah, jadi fungsi lama dihapus dulu)
drop function if exists public.admin_tracked_members();
create function public.admin_tracked_members() returns table(
  member_id uuid, name text, consent boolean, track_requested boolean, sos boolean, sos_note text,
  lat double precision, lng double precision, accuracy real, located_at timestamptz, last_checkin_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not can_view_location() then raise exception 'forbidden'; end if;
  return query
  select s.member_id, coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota'),
         s.consent, s.track_requested, s.sos, s.sos_note, l.lat, l.lng, l.accuracy, l.updated_at, s.last_checkin_at
  from member_location_state s join members m on m.id = s.member_id
  left join member_locations l on l.member_id = s.member_id
  where s.consent or s.sos or s.last_checkin_at > now() - interval '2 days'
  order by s.sos desc, l.updated_at desc nulls last;
end $$;
revoke all on function public.admin_tracked_members() from public, anon;
grant execute on function public.admin_tracked_members(), public.check_in_safe(text) to authenticated;
grant execute on function public.admin_save_geofence(uuid, text, double precision, double precision, integer, boolean), public.admin_delete_geofence(uuid) to authenticated;

-- report_location + evaluasi geofence (tanda tangan sama dengan skrip 12)
create or replace function public.report_location(p_lat double precision, p_lng double precision, p_acc real default null)
returns boolean language plpgsql security definer set search_path = public as $$
declare me uuid := current_member_id(); s member_location_state%rowtype; g record; d double precision;
        now_in boolean; was_in boolean; nm text;
begin
  if me is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then return false; end if;
  select * into s from member_location_state where member_id = me;
  if not found or not (s.sos or (s.consent and s.track_requested)) then return false; end if;
  insert into member_locations(member_id, lat, lng, accuracy, updated_at) values (me, p_lat, p_lng, p_acc, now())
  on conflict (member_id) do update set lat = p_lat, lng = p_lng, accuracy = p_acc, updated_at = now();
  insert into member_location_history(member_id, lat, lng, accuracy) values (me, p_lat, p_lng, p_acc);
  if random() < 0.02 then delete from member_location_history where recorded_at < now() - interval '7 days'; end if;

  select coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota') into nm from members m where m.id = me;
  for g in select * from geofences where active loop
    d := geo_distance_m(p_lat, p_lng, g.lat, g.lng);
    now_in := d <= g.radius_m;
    select inside into was_in from member_geofence_state where member_id = me and geofence_id = g.id;
    if was_in is null then
      insert into member_geofence_state(member_id, geofence_id, inside) values (me, g.id, now_in);
    elsif was_in <> now_in then
      update member_geofence_state set inside = now_in, changed_at = now() where member_id = me and geofence_id = g.id;
      perform notify_admins(case when now_in then 'info' else 'warning' end,
        nm || (case when now_in then ' masuk area ' else ' keluar dari area ' end) || g.name,
        'Jarak dari pusat area sekitar ' || round(d)::text || ' m.', '/tracking');
    end if;
  end loop;
  return true;
end $$;

-- ---------- Pengumuman massal ----------
create or replace function public.admin_broadcast(p_title text, p_body text, p_branch uuid default null) returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if not (is_super() or has_permission('broadcast')) then raise exception 'forbidden'; end if;
  if coalesce(trim(p_title), '') = '' then raise exception 'title required'; end if;
  insert into notifications(member_id, type, title, body, link)
  select m.id, 'info', left(trim(p_title), 80), left(coalesce(p_body, ''), 500), '/notifications'
  from members m
  where m.approval_status = 'approved' and (p_branch is null or m.branch_id = p_branch);
  get diagnostics n = row_count;
  perform log_event('broadcast', 'notifications', coalesce(p_branch::text, 'all'));
  return n;
end $$;
revoke all on function public.admin_broadcast(text, text, uuid) from public, anon;
grant execute on function public.admin_broadcast(text, text, uuid) to authenticated;

-- ---------- Pengingat otomatis ----------
create table if not exists public.reminder_log(
  kind text not null, ref_id uuid not null, member_id uuid not null, bucket text not null,
  created_at timestamptz not null default now(),
  primary key (kind, ref_id, member_id, bucket));
alter table public.reminder_log enable row level security;
revoke all on public.reminder_log from anon, authenticated;

create or replace function public.run_reminders() returns void
language plpgsql security definer set search_path = public as $$
declare today date := (now() at time zone 'Asia/Jakarta')::date;
begin
  -- Event: 24 jam dan 1 jam sebelum mulai, untuk anggota yang RSVP selain "Tidak"
  with cand as (
    select 'event'::text kind, e.id ref_id, r.member_id,
           case when e.starts_at <= now() + interval '1 hour' then 'h1' else 'h24' end bucket,
           e.title, e.starts_at
    from events e join event_rsvps r on r.event_id = e.id and r.status <> 'Tidak'
    where e.starts_at > now() and e.starts_at <= now() + interval '24 hours'),
  ins as (
    insert into reminder_log(kind, ref_id, member_id, bucket)
    select kind, ref_id, member_id, bucket from cand on conflict do nothing
    returning kind, ref_id, member_id, bucket)
  insert into notifications(member_id, type, title, body, link)
  select c.member_id, 'info',
         case when c.bucket = 'h1' then 'Event segera dimulai' else 'Event besok' end,
         c.title || ' · ' || to_char(c.starts_at at time zone 'Asia/Jakarta', 'DD Mon HH24:MI') || ' WIB', '/calendar'
  from ins join cand c using (kind, ref_id, member_id, bucket);

  -- Tugas: jatuh tempo hari ini / besok, belum Done
  with cand as (
    select 'task'::text kind, t.id ref_id, t.assigned_to member_id,
           case when t.due_date <= today then 'd0' else 'd1' end bucket, t.title, t.due_date
    from tasks t
    where t.assigned_to is not null and coalesce(t.status, '') <> 'Done' and t.due_date between today and today + 1),
  ins as (
    insert into reminder_log(kind, ref_id, member_id, bucket)
    select kind, ref_id, member_id, bucket from cand on conflict do nothing
    returning kind, ref_id, member_id, bucket)
  insert into notifications(member_id, type, title, body, link)
  select c.member_id, 'warning',
         case when c.bucket = 'd0' then 'Tugas jatuh tempo hari ini' else 'Tugas jatuh tempo besok' end, c.title, '/tasks'
  from ins join cand c using (kind, ref_id, member_id, bucket);

  -- Perkara: deadline (3 hari dan 1 hari) dan tanggal perkara (1 hari), untuk yang ditugaskan
  with cand as (
    select 'case_deadline'::text kind, c.id ref_id, c.assigned_to member_id,
           case when c.deadline <= today + 1 then 'd1' else 'd3' end bucket, c.title, c.deadline dt
    from cases c where c.assigned_to is not null and c.deadline between today and today + 3
    union all
    select 'case_date', c.id, c.assigned_to, 'd1', c.title, c.case_date
    from cases c where c.assigned_to is not null and c.case_date between today and today + 1),
  ins as (
    insert into reminder_log(kind, ref_id, member_id, bucket)
    select kind, ref_id, member_id, bucket from cand on conflict do nothing
    returning kind, ref_id, member_id, bucket)
  insert into notifications(member_id, type, title, body, link)
  select c.member_id, 'warning',
         case when c.kind = 'case_date' then 'Tanggal perkara mendekat' else 'Deadline perkara mendekat' end,
         c.title || ' · ' || to_char(c.dt, 'DD Mon YYYY'), '/cases'
  from ins join cand c using (kind, ref_id, member_id, bucket);

  delete from reminder_log where created_at < now() - interval '60 days';
end $$;
revoke all on function public.run_reminders() from public, anon, authenticated;

-- Jadwal tiap 15 menit lewat pg_cron (aktifkan dulu di Dashboard: Integrations > Cron)
do $$ begin
  begin
    create extension if not exists pg_cron;
    perform cron.unschedule('perkapi-reminders');
  exception when others then null; end;
  begin
    perform cron.schedule('perkapi-reminders', '*/15 * * * *', 'select public.run_reminders()');
  exception when others then
    raise notice 'pg_cron belum aktif. Aktifkan di Dashboard > Integrations > Cron, lalu jalankan ulang skrip ini. (%)', sqlerrm;
  end;
end $$;

-- ---------- Rekap absensi ----------
create or replace function public.attendance_summary(p_from date, p_to date)
returns table(member_id uuid, name text, hadir bigint, total_event bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (is_super() or has_permission('view_reports')) then raise exception 'forbidden'; end if;
  return query
  with ev as (
    select e.id from events e
    where (e.starts_at at time zone 'Asia/Jakarta')::date between p_from and p_to and e.starts_at <= now())
  select m.id, coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota'),
         (select count(distinct a.event_id) from attendance a
            where a.member_id = m.id and a.event_id in (select id from ev) and coalesce(a.status, 'Hadir') = 'Hadir'),
         (select count(*) from ev)
  from members m where m.approval_status = 'approved'
  order by 3 desc, 2;
end $$;

create or replace function public.attendance_by_month(p_from date, p_to date)
returns table(bulan text, hadir bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (is_super() or has_permission('view_reports')) then raise exception 'forbidden'; end if;
  return query
  select to_char(date_trunc('month', a.checked_in_at at time zone 'Asia/Jakarta'), 'YYYY-MM'), count(*)
  from attendance a
  where (a.checked_in_at at time zone 'Asia/Jakarta')::date between p_from and p_to and coalesce(a.status, 'Hadir') = 'Hadir'
  group by 1 order by 1;
end $$;
revoke all on function public.attendance_summary(date, date), public.attendance_by_month(date, date) from public, anon;
grant execute on function public.attendance_summary(date, date), public.attendance_by_month(date, date) to authenticated;
