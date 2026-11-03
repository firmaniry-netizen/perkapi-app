-- 45_donasi.sql
-- Fitur donasi di aplikasi: kampanye (event, sosial, bencana, pendidikan, organisasi, lainnya)
-- dan donasi anggota lewat transfer bank / QRIS dengan unggah bukti, diverifikasi pengurus.
--
-- Keamanan:
--  * Kampanye dibaca semua anggota yang login; dibuat/diubah hanya oleh pengelola
--    (izin 'manage_donation', atau admin SUPER_ADMIN / ADMIN_PUSAT).
--  * Donasi & bukti transfer hanya terlihat oleh pemberi donasi sendiri dan pengelola.
--  * Anggota lain hanya melihat total terkumpul dan daftar donatur terverifikasi
--    (nama disembunyikan bila memilih anonim) lewat fungsi donation_stats / donation_donors.
--  * Status donasi hanya bisa diubah pengelola lewat fungsi admin_verify_donation.
-- Aman dijalankan ulang.

-- ---------- izin ----------
create or replace function public.can_manage_donation()
returns boolean language sql stable security definer set search_path to 'public' as $$
  select public.has_permission('manage_donation') or exists(
    select 1 from member_roles mr join roles r on r.id = mr.role_id
    where mr.member_id = public.current_member_id() and r.code in ('SUPER_ADMIN', 'ADMIN_PUSAT'));
$$;

-- ---------- tabel ----------
create table if not exists public.donation_campaigns (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(trim(title)) between 3 and 140),
  category text not null default 'Event'
    check (category in ('Event', 'Sosial', 'Bencana', 'Pendidikan', 'Organisasi', 'Lainnya')),
  description text check (description is null or length(description) <= 5000),
  target_amount bigint check (target_amount is null or target_amount >= 0),
  ends_at date,
  event_id uuid references public.events(id) on delete set null,
  cover_path text,
  bank_name text check (bank_name is null or length(bank_name) <= 60),
  account_number text check (account_number is null or length(account_number) <= 40),
  account_holder text check (account_holder is null or length(account_holder) <= 100),
  qris_path text,
  is_active boolean not null default true,
  created_by uuid default public.current_member_id() references public.members(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.donations (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.donation_campaigns(id) on delete cascade,
  member_id uuid default public.current_member_id() references public.members(id) on delete set null,
  amount bigint not null check (amount between 1000 and 10000000000),
  is_anonymous boolean not null default false,
  message text check (message is null or length(message) <= 300),
  proof_path text,
  status text not null default 'menunggu' check (status in ('menunggu', 'terverifikasi', 'ditolak')),
  reject_reason text,
  verified_by uuid references public.members(id) on delete set null,
  verified_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists donations_campaign_idx on public.donations(campaign_id, status);
create index if not exists donations_member_idx on public.donations(member_id, created_at desc);

drop trigger if exists trg_updated_at on public.donation_campaigns;
create trigger trg_updated_at before update on public.donation_campaigns
  for each row execute function public.set_updated_at();

-- ---------- RLS ----------
alter table public.donation_campaigns enable row level security;
alter table public.donations enable row level security;

drop policy if exists dc_read on public.donation_campaigns;
create policy dc_read on public.donation_campaigns for select to authenticated
  using (is_active or public.can_manage_donation());
drop policy if exists dc_write on public.donation_campaigns;
create policy dc_write on public.donation_campaigns for all to authenticated
  using (public.can_manage_donation()) with check (public.can_manage_donation());

drop policy if exists dn_read on public.donations;
create policy dn_read on public.donations for select to authenticated
  using (member_id = public.current_member_id() or public.can_manage_donation());
drop policy if exists dn_insert on public.donations;
create policy dn_insert on public.donations for insert to authenticated
  with check (
    member_id = public.current_member_id()
    and status = 'menunggu' and verified_by is null and verified_at is null
    and exists (select 1 from public.donation_campaigns c where c.id = campaign_id and c.is_active
                and (c.ends_at is null or c.ends_at >= current_date)));
-- pemberi donasi boleh membatalkan donasinya selama belum diverifikasi
drop policy if exists dn_delete on public.donations;
create policy dn_delete on public.donations for delete to authenticated
  using ((member_id = public.current_member_id() and status = 'menunggu') or public.can_manage_donation());
-- tidak ada kebijakan UPDATE: status hanya lewat admin_verify_donation()

-- ---------- ringkasan untuk semua anggota ----------
create or replace function public.donation_stats()
returns table(campaign_id uuid, collected bigint, donors bigint, pending bigint)
language sql stable security definer set search_path to 'public' as $$
  select c.id,
         coalesce(sum(d.amount) filter (where d.status = 'terverifikasi'), 0)::bigint,
         count(distinct coalesce(d.member_id::text, d.id::text)) filter (where d.status = 'terverifikasi'),
         count(*) filter (where d.status = 'menunggu')
  from donation_campaigns c left join donations d on d.campaign_id = c.id
  where auth.uid() is not null and (c.is_active or can_manage_donation())
  group by c.id;
$$;

create or replace function public.donation_donors(p_campaign uuid, p_limit int default 30)
returns table(name text, amount bigint, message text, created_at timestamptz)
language sql stable security definer set search_path to 'public' as $$
  select case when d.is_anonymous then 'Hamba Allah' else coalesce(m.full_name, 'Anggota') end,
         d.amount, d.message, d.created_at
  from donations d left join members m on m.id = d.member_id
  where auth.uid() is not null and d.campaign_id = p_campaign and d.status = 'terverifikasi'
  order by d.created_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

-- ---------- verifikasi oleh pengelola ----------
create or replace function public.admin_verify_donation(p_id uuid, p_ok boolean, p_reason text default null)
returns void language plpgsql security definer set search_path to 'public' as $$
declare d donations; c donation_campaigns;
begin
  if not can_manage_donation() then raise exception 'forbidden'; end if;
  update donations set status = case when p_ok then 'terverifikasi' else 'ditolak' end,
         reject_reason = case when p_ok then null else left(nullif(trim(p_reason), ''), 300) end,
         verified_by = current_member_id(), verified_at = now()
   where id = p_id returning * into d;
  if d.id is null then raise exception 'not found'; end if;
  select * into c from donation_campaigns where id = d.campaign_id;
  if d.member_id is not null then
    insert into notifications(member_id, type, title, body, link)
    values (d.member_id, 'donasi',
            case when p_ok then 'Donasi Anda diterima' else 'Donasi perlu diperiksa' end,
            case when p_ok then 'Terima kasih! Donasi Rp ' || replace(to_char(d.amount, 'FM999G999G999G999'), ',', '.') || ' untuk "' || c.title || '" sudah diverifikasi.'
                 else 'Donasi untuk "' || c.title || '" belum dapat diverifikasi' || coalesce(': ' || d.reject_reason, '.') end,
            '/donations/' || c.id::text);
  end if;
end $$;

-- ---------- notifikasi otomatis ----------
-- donasi baru → pengelola diberi tahu untuk memverifikasi
create or replace function public.donation_after_insert()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare t text; nm text;
begin
  select title into t from donation_campaigns where id = new.campaign_id;
  select full_name into nm from members where id = new.member_id;
  insert into notifications(member_id, type, title, body, link)
  select distinct mr.member_id, 'donasi', 'Donasi baru menunggu verifikasi',
         coalesce(nm, 'Anggota') || ' · Rp ' || replace(to_char(new.amount, 'FM999G999G999G999'), ',', '.') || ' · ' || coalesce(t, ''),
         '/donations/' || new.campaign_id::text
  from member_roles mr join roles r on r.id = mr.role_id
  where (r.code in ('SUPER_ADMIN', 'ADMIN_PUSAT')
         or exists (select 1 from role_permissions rp where rp.role_id = r.id and rp.permission = 'manage_donation'))
    and mr.member_id is distinct from new.member_id;
  return new;
exception when others then return new;
end $$;
drop trigger if exists trg_donation_after_insert on public.donations;
create trigger trg_donation_after_insert after insert on public.donations
  for each row execute function public.donation_after_insert();

-- kampanye baru yang aktif → semua anggota disetujui diberi tahu
create or replace function public.donation_campaign_announce()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if new.is_active then
    insert into notifications(member_id, type, title, body, link)
    select m.id, 'donasi', 'Ajakan donasi: ' || left(new.title, 60),
           left(coalesce(nullif(new.description, ''), 'Mari berpartisipasi dalam donasi ' || lower(new.category) || ' PERKAPI.'), 160),
           '/donations/' || new.id::text
    from members m where m.approval_status = 'approved';
  end if;
  return new;
exception when others then return new;
end $$;
drop trigger if exists trg_donation_campaign_announce on public.donation_campaigns;
create trigger trg_donation_campaign_announce after insert on public.donation_campaigns
  for each row execute function public.donation_campaign_announce();

-- ---------- penyimpanan ----------
-- donasi-publik: sampul kampanye & gambar QRIS (dibaca anggota yang login, ditulis pengelola)
-- donasi-bukti : bukti transfer (hanya pemilik & pengelola); jalur: <member_id>/<nama-file>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('donasi-publik', 'donasi-publik', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
       ('donasi-bukti', 'donasi-bukti', false, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do nothing;

drop policy if exists "donasi publik baca" on storage.objects;
create policy "donasi publik baca" on storage.objects for select to authenticated
  using (bucket_id = 'donasi-publik');
drop policy if exists "donasi publik tulis" on storage.objects;
create policy "donasi publik tulis" on storage.objects for insert to authenticated
  with check (bucket_id = 'donasi-publik' and public.can_manage_donation());
drop policy if exists "donasi publik ubah" on storage.objects;
create policy "donasi publik ubah" on storage.objects for update to authenticated
  using (bucket_id = 'donasi-publik' and public.can_manage_donation());
drop policy if exists "donasi publik hapus" on storage.objects;
create policy "donasi publik hapus" on storage.objects for delete to authenticated
  using (bucket_id = 'donasi-publik' and public.can_manage_donation());

drop policy if exists "donasi bukti unggah" on storage.objects;
create policy "donasi bukti unggah" on storage.objects for insert to authenticated
  with check (bucket_id = 'donasi-bukti' and (storage.foldername(name))[1] = public.current_member_id()::text);
drop policy if exists "donasi bukti baca" on storage.objects;
create policy "donasi bukti baca" on storage.objects for select to authenticated
  using (bucket_id = 'donasi-bukti'
         and ((storage.foldername(name))[1] = public.current_member_id()::text or public.can_manage_donation()));
drop policy if exists "donasi bukti hapus" on storage.objects;
create policy "donasi bukti hapus" on storage.objects for delete to authenticated
  using (bucket_id = 'donasi-bukti'
         and ((storage.foldername(name))[1] = public.current_member_id()::text or public.can_manage_donation()));

-- izin pengelola donasi untuk peran admin & pengurus pusat
insert into public.role_permissions(role_id, permission)
select r.id, 'manage_donation' from public.roles r
where r.code in ('SUPER_ADMIN', 'ADMIN_PUSAT')
  and not exists (select 1 from public.role_permissions rp where rp.role_id = r.id and rp.permission = 'manage_donation');

grant execute on function public.donation_stats() to authenticated;
grant execute on function public.donation_donors(uuid, int) to authenticated;
grant execute on function public.admin_verify_donation(uuid, boolean, text) to authenticated;
grant execute on function public.can_manage_donation() to authenticated;
