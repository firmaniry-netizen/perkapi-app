-- 12_gps_tracking.sql  (jalankan SETELAH 03, 04, 08; aman dijalankan ulang)
-- Pelacakan lokasi anggota. Aturan privasi yang ditegakkan DI DATABASE:
--  * Hanya admin utama (SUPER_ADMIN) atau pemilik izin 'view_location' yang bisa MEMBACA lokasi.
--    (Tidak ada role_permissions bernama view_location, jadi praktisnya hanya SUPER_ADMIN.)
--  * Lokasi hanya tersimpan jika anggota memberi persetujuan DAN (admin meminta pelacakan ATAU anggota menekan SOS).
--  * Anggota tidak bisa menulis tabel langsung; semua lewat fungsi di bawah.
--  * Mencabut persetujuan menghapus semua data lokasi anggota itu.

create table if not exists public.member_location_state(
  member_id uuid primary key references public.members(id) on delete cascade,
  consent boolean not null default false,
  track_requested boolean not null default false,
  sos boolean not null default false,
  sos_note text,
  updated_at timestamptz not null default now());

create table if not exists public.member_locations(
  member_id uuid primary key references public.members(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  accuracy real,
  updated_at timestamptz not null default now());

create table if not exists public.member_location_history(
  id bigserial primary key,
  member_id uuid not null references public.members(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  accuracy real,
  recorded_at timestamptz not null default now());
create index if not exists member_location_history_idx on public.member_location_history(member_id, recorded_at desc);

create or replace function public.can_view_location() returns boolean
language sql stable security definer set search_path = public as
$$ select public.is_super() or public.has_permission('view_location') $$;

-- RLS: baca saja, tanpa policy tulis untuk klien
alter table public.member_location_state   enable row level security;
alter table public.member_locations        enable row level security;
alter table public.member_location_history enable row level security;

drop policy if exists mls_select on public.member_location_state;
create policy mls_select on public.member_location_state for select
  using (member_id = public.current_member_id() or public.can_view_location());
drop policy if exists ml_select on public.member_locations;
create policy ml_select on public.member_locations for select using (public.can_view_location());
drop policy if exists mlh_select on public.member_location_history;
create policy mlh_select on public.member_location_history for select using (public.can_view_location());

revoke insert, update, delete on public.member_location_state, public.member_locations, public.member_location_history from anon, authenticated;
revoke all on public.member_locations, public.member_location_history from anon;

do $$ declare t text; begin
  foreach t in array array['member_location_state','member_locations','member_location_history'] loop
    begin
      execute format('drop policy if exists perkapi_require_approved on public.%I', t);
      execute format('create policy perkapi_require_approved on public.%I as restrictive for all to authenticated using ((select public.is_approved()))', t);
    exception when others then raise notice 'SKIP require_approved %: %', t, sqlerrm; end;
  end loop;
end $$;

-- Status milik sendiri
create or replace function public.get_my_location_state() returns jsonb
language sql stable security definer set search_path = public as
$$ select coalesce((select to_jsonb(s) - 'member_id' from member_location_state s where s.member_id = current_member_id()),
                   jsonb_build_object('consent', false, 'track_requested', false, 'sos', false)) $$;

create or replace function public.set_location_consent(p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := current_member_id();
begin
  if me is null then raise exception 'not a member'; end if;
  insert into member_location_state(member_id, consent) values (me, p_on)
  on conflict (member_id) do update set consent = p_on, updated_at = now(),
    track_requested = case when p_on then member_location_state.track_requested else false end,
    sos = case when p_on then member_location_state.sos else false end;
  if not p_on then
    delete from member_locations where member_id = me;
    delete from member_location_history where member_id = me;
  end if;
  perform log_event(case when p_on then 'location_consent_on' else 'location_consent_off' end, 'tracking', me::text);
end $$;

create or replace function public.trigger_sos(p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := current_member_id(); nm text;
begin
  if me is null then raise exception 'not a member'; end if;
  insert into member_location_state(member_id, consent, sos, sos_note) values (me, false, true, left(p_note, 300))
  on conflict (member_id) do update set sos = true, sos_note = left(p_note, 300), updated_at = now();
  select coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota') into nm from members m where m.id = me;
  begin
    insert into notifications(member_id, type, title, body, link)
    select distinct mr.member_id, 'sos', 'SOS: ' || nm || ' butuh bantuan',
           coalesce(nullif(left(p_note, 300), ''), 'Anggota menekan tombol darurat.'), '/tracking'
    from member_roles mr join roles r on r.id = mr.role_id where r.code = 'SUPER_ADMIN';
  exception when others then null; end;
  perform log_event('sos_triggered', 'tracking', me::text);
end $$;

create or replace function public.cancel_sos() returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := current_member_id();
begin
  update member_location_state set sos = false, sos_note = null, updated_at = now() where member_id = me;
  -- tanpa persetujuan tetap, lokasi tidak boleh tersisa setelah SOS selesai
  delete from member_locations where member_id = me
    and not coalesce((select consent and track_requested from member_location_state where member_id = me), false);
end $$;

-- Admin meminta / menghentikan pelacakan. Efektif hanya bila anggota sudah menyetujui.
create or replace function public.admin_set_tracking(p_member uuid, p_on boolean) returns text
language plpgsql security definer set search_path = public as $$
declare has_consent boolean;
begin
  if not can_view_location() then raise exception 'forbidden'; end if;
  select coalesce(consent, false) into has_consent from member_location_state where member_id = p_member;
  if not coalesce(has_consent, false) and p_on then return 'no_consent'; end if;
  update member_location_state set track_requested = p_on, updated_at = now() where member_id = p_member;
  if p_on then
    insert into notifications(member_id, type, title, body, link)
    values (p_member, 'tracking', 'Admin meminta lokasi Anda',
            'Buka aplikasi agar lokasi terkirim. Anda bisa mencabut izin kapan saja di menu Keamanan.', '/safety');
  end if;
  perform log_event(case when p_on then 'tracking_start' else 'tracking_stop' end, 'tracking', p_member::text);
  return 'ok';
end $$;

-- Dipanggil aplikasi anggota (hanya menyimpan bila diizinkan)
create or replace function public.report_location(p_lat double precision, p_lng double precision, p_acc real default null)
returns boolean language plpgsql security definer set search_path = public as $$
declare me uuid := current_member_id(); s member_location_state%rowtype;
begin
  if me is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then return false; end if;
  select * into s from member_location_state where member_id = me;
  if not found or not (s.sos or (s.consent and s.track_requested)) then return false; end if;
  insert into member_locations(member_id, lat, lng, accuracy, updated_at) values (me, p_lat, p_lng, p_acc, now())
  on conflict (member_id) do update set lat = p_lat, lng = p_lng, accuracy = p_acc, updated_at = now();
  insert into member_location_history(member_id, lat, lng, accuracy) values (me, p_lat, p_lng, p_acc);
  if random() < 0.02 then delete from member_location_history where recorded_at < now() - interval '7 days'; end if;
  return true;
end $$;

-- Daftar untuk peta admin
create or replace function public.admin_tracked_members() returns table(
  member_id uuid, name text, consent boolean, track_requested boolean, sos boolean, sos_note text,
  lat double precision, lng double precision, accuracy real, located_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not can_view_location() then raise exception 'forbidden'; end if;
  return query
  select s.member_id, coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota'),
         s.consent, s.track_requested, s.sos, s.sos_note, l.lat, l.lng, l.accuracy, l.updated_at
  from member_location_state s join members m on m.id = s.member_id
  left join member_locations l on l.member_id = s.member_id
  where s.consent or s.sos
  order by s.sos desc, l.updated_at desc nulls last;
end $$;

revoke all on function public.admin_tracked_members(), public.admin_set_tracking(uuid, boolean) from public, anon;
grant execute on function public.get_my_location_state(), public.set_location_consent(boolean), public.trigger_sos(text),
  public.cancel_sos(), public.report_location(double precision, double precision, real),
  public.admin_tracked_members(), public.admin_set_tracking(uuid, boolean) to authenticated;

-- Realtime (notifikasi langsung + peta admin)
do $$ begin
  begin alter publication supabase_realtime add table public.notifications; exception when others then raise notice 'notifications: %', sqlerrm; end;
  begin alter publication supabase_realtime add table public.member_locations; exception when others then raise notice 'member_locations: %', sqlerrm; end;
end $$;
