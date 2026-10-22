-- Galeri Dokumentasi: foto kegiatan/perkara. Bucket privat + tabel + RLS.
-- Jalankan setelah 05_triggers_storage.sql. Aman dijalankan ulang.
create table if not exists public.gallery_photos (
  id uuid primary key default gen_random_uuid(),
  album text not null default 'Umum',
  caption text,
  file_path text not null,
  file_name text,
  size_bytes bigint,
  uploaded_by uuid,            -- members.id (current_member_id())
  created_at timestamptz not null default now()
);
create index if not exists gallery_photos_album_idx on public.gallery_photos(album, created_at desc);

alter table public.gallery_photos enable row level security;
drop policy if exists gp_select on public.gallery_photos;
drop policy if exists gp_insert on public.gallery_photos;
drop policy if exists gp_delete on public.gallery_photos;
create policy gp_select on public.gallery_photos for select to authenticated using (true);
create policy gp_insert on public.gallery_photos for insert to authenticated
  with check (uploaded_by = current_member_id());
create policy gp_delete on public.gallery_photos for delete to authenticated
  using (uploaded_by = current_member_id() or has_permission('manage_document'));

insert into storage.buckets(id, name, public) values ('gallery','gallery',false)
on conflict (id) do nothing;

drop policy if exists perkapi_gallery_read on storage.objects;
drop policy if exists perkapi_gallery_write on storage.objects;
drop policy if exists perkapi_gallery_delete on storage.objects;
create policy perkapi_gallery_read on storage.objects for select to authenticated
  using (bucket_id = 'gallery');
create policy perkapi_gallery_write on storage.objects for insert to authenticated
  with check (bucket_id = 'gallery' and (storage.foldername(name))[1] = auth.uid()::text);
create policy perkapi_gallery_delete on storage.objects for delete to authenticated
  using (bucket_id = 'gallery' and ((storage.foldername(name))[1] = auth.uid()::text or has_permission('manage_document')));
