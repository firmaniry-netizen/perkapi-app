-- Struktur Organisasi PERKAPI + foto pengurus. Jalankan setelah 27 (atau kapan saja setelah RBAC). Aman dijalankan ulang.
-- Dilihat semua anggota; ditambah/diubah/dihapus oleh pengguna dengan izin manage_member.
create table if not exists public.org_structure (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  position text not null,                 -- jabatan, mis. Ketua Umum
  division text not null default 'Pengurus Harian',  -- pengelompokan, mis. Dewan Pembina / Pengurus Harian / Bidang Pendidikan
  sort_order int not null default 100,    -- kecil = tampil lebih awal
  is_leader boolean not null default false,  -- true = tampil di carousel 3D teratas
  period text not null default '2026-2031',
  bio text,
  photo_path text,                        -- path di bucket org-photos
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists org_structure_order_idx on public.org_structure(sort_order, name);
alter table public.org_structure enable row level security;

drop policy if exists os_select on public.org_structure;
drop policy if exists os_write on public.org_structure;
create policy os_select on public.org_structure for select to authenticated
  using (is_active or has_permission('manage_member'));
create policy os_write on public.org_structure for all to authenticated
  using (has_permission('manage_member')) with check (has_permission('manage_member'));

-- Bucket PUBLIK: foto pengurus ikut tampil di situs publik. Hanya unggah foto yang memang boleh dipublikasikan.
insert into storage.buckets(id, name, public) values ('org-photos', 'org-photos', true)
on conflict (id) do update set public = true;
drop policy if exists perkapi_orgphotos_write on storage.objects;
drop policy if exists perkapi_orgphotos_update on storage.objects;
drop policy if exists perkapi_orgphotos_delete on storage.objects;
create policy perkapi_orgphotos_write on storage.objects for insert to authenticated
  with check (bucket_id = 'org-photos' and has_permission('manage_member'));
create policy perkapi_orgphotos_update on storage.objects for update to authenticated
  using (bucket_id = 'org-photos' and has_permission('manage_member'));
create policy perkapi_orgphotos_delete on storage.objects for delete to authenticated
  using (bucket_id = 'org-photos' and has_permission('manage_member'));

-- Untuk situs publik (baca saja, hanya yang aktif).
create or replace function public.public_org_structure()
returns table(name text, "position" text, division text, sort_order int, is_leader boolean, period text, photo_path text)
language sql security definer set search_path = public as $$
  select o.name, o."position", o.division, o.sort_order, o.is_leader, o.period, o.photo_path
  from org_structure o where o.is_active order by o.sort_order, o.name;
$$;
revoke all on function public.public_org_structure() from public;
grant execute on function public.public_org_structure() to anon, authenticated;

-- Data awal: hanya Ketua Umum yang sumbernya jelas. Pengurus lain diisi lewat aplikasi.
insert into public.org_structure(name, "position", division, sort_order, is_leader)
select 'Siking Suryadi', 'Ketua Umum', 'Pengurus Harian', 1, true
where not exists (select 1 from public.org_structure x where x."position" = 'Ketua Umum');
