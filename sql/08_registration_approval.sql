-- 08: Pendaftaran mandiri (register) + persetujuan ADMIN UTAMA (role SUPER_ADMIN).
-- ADITIF & AMAN: hanya "add column if not exists", fungsi baru, trigger baru, dan policy RESTRICTIVE.
-- Tidak membuat tabel baru. Anggota yang sudah ada otomatis berstatus 'approved' (default kolom).
-- Jalankan di Supabase SQL Editor SETELAH 03 dan 04 (butuh is_super(), current_member_id(), policy RLS).
-- Cadangkan database dulu. Baca semua NOTICE "SKIP".

-- 1) Kolom status persetujuan ------------------------------------------------------------------
alter table members add column if not exists approval_status text not null default 'approved';
alter table members add column if not exists registered_at timestamptz;
alter table members add column if not exists approved_by uuid references members(id) on delete set null;
alter table members add column if not exists approved_at timestamptz;
alter table members add column if not exists rejection_reason text;

do $$ begin
  alter table members add constraint members_approval_status_chk
    check (approval_status in ('pending','approved','rejected'));
exception when duplicate_object then null; end $$;

-- 2) Helper: apakah pengguna login sudah disetujui ----------------------------------------------
create or replace function public.is_approved() returns boolean
language sql stable security definer set search_path = public as
$$ select coalesce((select m.approval_status = 'approved' from members m where m.user_id = auth.uid() limit 1), false) $$;

create or replace function public.my_approval_status() returns text
language sql stable security definer set search_path = public as
$$ select m.approval_status from members m where m.user_id = auth.uid() limit 1 $$;

grant execute on function public.is_approved(), public.my_approval_status() to authenticated;

-- 3) Daftar cabang untuk form register (dibaca anon, hanya id + nama) ---------------------------
create or replace function public.public_branches() returns table(id uuid, name text)
language sql stable security definer set search_path = public as
$$ select b.id, b.name from branches b where b.name is not null order by b.name $$;

revoke all on function public.public_branches() from public;
grant execute on function public.public_branches() to anon, authenticated;

-- 4) Trigger: user baru dari form register -> baris members berstatus 'pending' ----------------
-- Hanya bila metadata signUp memuat self_register = true. User yang dibuat admin lewat dashboard
-- Supabase Auth TIDAK terpengaruh. Role TIDAK pernah dibaca dari metadata (aman dari eskalasi).
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  meta     jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_branch uuid;
  v_member uuid;
  v_name   text;
begin
  if coalesce(meta->>'self_register', '') <> 'true' then return new; end if;
  if exists (select 1 from members where user_id = new.id) then return new; end if;

  begin v_branch := nullif(meta->>'branch_id', '')::uuid;
  exception when others then v_branch := null; end;
  if v_branch is not null and not exists (select 1 from branches where id = v_branch) then
    v_branch := null;
  end if;

  v_name := left(nullif(trim(meta->>'full_name'), ''), 120);

  insert into members(user_id, full_name, email, phone, branch_id, status, approval_status, registered_at)
  values (new.id, coalesce(v_name, split_part(new.email, '@', 1)), new.email,
          left(nullif(trim(meta->>'phone'), ''), 30), v_branch,
          'Menunggu Persetujuan', 'pending', now())
  returning id into v_member;

  -- Beri tahu semua admin utama (gagal notifikasi tidak membatalkan pendaftaran)
  begin
    insert into notifications(member_id, type, title, body, link)
    select distinct mr.member_id, 'registration', 'Pendaftaran anggota baru',
           coalesce(v_name, new.email) || ' menunggu persetujuan Anda.', '/registrations'
    from member_roles mr join roles r on r.id = mr.role_id
    where r.code = 'SUPER_ADMIN';
  exception when others then null; end;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- 5) Pagar: hanya admin utama yang boleh mengubah status persetujuan -----------------------------
-- Policy mb_update mengizinkan pengguna mengubah barisnya sendiri; tanpa pagar ini pendaftar bisa
-- menyetujui dirinya sendiri. auth.uid() null = SQL Editor / service_role (diizinkan).
create or replace function public.members_guard_approval() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' and (
        new.approval_status  is distinct from old.approval_status
     or new.approved_by      is distinct from old.approved_by
     or new.approved_at      is distinct from old.approved_at
     or new.rejection_reason is distinct from old.rejection_reason) then
    if auth.uid() is not null and not public.is_super() then
      raise exception 'Hanya admin utama yang dapat mengubah status persetujuan.' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_members_guard_approval on members;
create trigger trg_members_guard_approval before update on members
  for each row execute function public.members_guard_approval();

-- 6) RPC khusus admin utama ------------------------------------------------------------------------
create or replace function public.list_registrations(p_status text default 'pending')
returns table(id uuid, full_name text, email text, phone text, branch_name text,
              approval_status text, registered_at timestamptz, rejection_reason text)
language sql stable security definer set search_path = public as $$
  select m.id, m.full_name, m.email, m.phone, b.name, m.approval_status, m.registered_at, m.rejection_reason
  from members m left join branches b on b.id = m.branch_id
  where public.is_super() and m.approval_status = p_status
  order by m.registered_at desc nulls last
$$;

create or replace function public.pending_registration_count() returns int
language sql stable security definer set search_path = public as
$$ select case when public.is_super()
               then (select count(*)::int from members where approval_status = 'pending')
               else 0 end $$;

create or replace function public.review_registration(
  p_member_id uuid, p_approve boolean,
  p_role_code text default 'ANGGOTA', p_member_number text default null, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_me   uuid := current_member_id();
  v_row  members%rowtype;
  v_role uuid;
  v_code text := upper(coalesce(nullif(trim(p_role_code), ''), 'ANGGOTA'));
begin
  if not is_super() then
    raise exception 'Hanya admin utama yang dapat memproses pendaftaran.' using errcode = '42501';
  end if;

  select * into v_row from members where id = p_member_id;
  if not found then raise exception 'Pendaftar tidak ditemukan.'; end if;
  if v_row.approval_status = 'approved' then raise exception 'Pendaftar ini sudah disetujui.'; end if;

  if p_approve then
    if v_code = 'SUPER_ADMIN' then
      raise exception 'Role SUPER_ADMIN tidak dapat diberikan lewat persetujuan pendaftaran.';
    end if;
    select id into v_role from roles where code = v_code limit 1;
    if v_role is null then raise exception 'Role % tidak ditemukan.', v_code; end if;

    update members set
      approval_status = 'approved', status = 'Aktif',
      approved_by = v_me, approved_at = now(), rejection_reason = null,
      member_number = coalesce(nullif(trim(p_member_number), ''), member_number)
    where id = p_member_id;

    insert into member_roles(member_id, role_id)
    select p_member_id, v_role
    where not exists (select 1 from member_roles where member_id = p_member_id and role_id = v_role);
  else
    update members set
      approval_status = 'rejected', status = 'Ditolak',
      approved_by = v_me, approved_at = now(), rejection_reason = nullif(trim(p_reason), '')
    where id = p_member_id;
  end if;

  begin
    insert into notifications(member_id, type, title, body)
    values (p_member_id, 'registration',
            case when p_approve then 'Pendaftaran disetujui' else 'Pendaftaran ditolak' end,
            case when p_approve then 'Selamat datang di PERKAPI. Akun Anda sudah aktif.'
                 else 'Pendaftaran Anda tidak disetujui.' end);
  exception when others then null; end;

  perform log_event(case when p_approve then 'registration_approved' else 'registration_rejected' end,
                    'members', p_member_id::text,
                    jsonb_build_object('role', v_code));
end $$;

revoke all on function public.list_registrations(text), public.pending_registration_count(),
  public.review_registration(uuid, boolean, text, text, text) from public;
grant execute on function public.list_registrations(text), public.pending_registration_count(),
  public.review_registration(uuid, boolean, text, text, text) to authenticated;

-- 7) RLS: akun yang belum disetujui tidak boleh membaca/menulis data apa pun ----------------------
-- Policy RESTRICTIVE (digabung AND dengan policy lama). Tabel members dikecualikan agar pendaftar
-- tetap bisa membaca baris miliknya sendiri; perubahan status sudah dipagari trigger di atas.
-- Jalankan ulang bagian ini bila kelak menambah tabel baru.
do $$ declare t text; begin
  for t in select tablename from pg_tables
           where schemaname = 'public' and rowsecurity and tablename <> 'members' loop
    begin
      execute format('drop policy if exists perkapi_require_approved on public.%I', t);
      execute format('create policy perkapi_require_approved on public.%I as restrictive for all to authenticated using ((select public.is_approved()))', t);
    exception when others then raise notice 'SKIP require_approved %: %', t, sqlerrm; end;
  end loop;
end $$;

do $$ begin
  drop policy if exists perkapi_storage_require_approved on storage.objects;
  create policy perkapi_storage_require_approved on storage.objects
    as restrictive for all to authenticated using ((select public.is_approved()));
exception when others then raise notice 'SKIP storage require_approved: %', sqlerrm; end $$;

-- Pengaturan Supabase (Dashboard > Authentication):
--  * Providers > Email: "Allow new users to sign up" harus AKTIF.
--  * Disarankan "Confirm email" AKTIF dan CAPTCHA (Turnstile/hCaptcha) AKTIF untuk mencegah bot.
--  * Password minimum length: atur >= 8.
