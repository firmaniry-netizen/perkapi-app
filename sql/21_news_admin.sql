-- 21: Berita -- HAPUS BERITA/FOTO HANYA ADMIN + berita terbaca semua pengguna yang sudah disetujui.
-- Jalankan di Supabase SQL Editor SETELAH 18_gallery.sql dan 20_gallery_news.sql. Aman dijalankan ulang.
--
-- Definisi "admin" (ubah daftar kode role di fungsi is_admin() bila perlu):
--   SUPER_ADMIN (admin utama), ADMIN_PUSAT, ADMIN_CABANG.
-- Penegakan ada di DATABASE (RLS + Storage), bukan hanya di tampilan aplikasi.

-- 1) Fungsi admin ---------------------------------------------------------------------------------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as
$$ select exists(
     select 1 from member_roles mr join roles r on r.id = mr.role_id
     where mr.member_id = current_member_id()
       and r.code in ('SUPER_ADMIN','ADMIN_PUSAT','ADMIN_CABANG')) $$;
grant execute on function public.is_admin() to authenticated;

-- 2) Tabel berita: semua pengguna terautentikasi boleh MEMBACA, hanya admin yang boleh MENGHAPUS ----
alter table public.gallery_photos enable row level security;
drop policy if exists gp_select on public.gallery_photos;
drop policy if exists gp_delete on public.gallery_photos;
create policy gp_select on public.gallery_photos for select to authenticated using (true);
create policy gp_delete on public.gallery_photos for delete to authenticated using (public.is_admin());

-- 3) Storage: hanya admin yang boleh menghapus berkas di bucket 'gallery'.
--    Pengecualian: pengunggah boleh membersihkan berkas YATIM miliknya (belum punya baris berita),
--    dipakai aplikasi bila unggah gagal di tengah jalan.
drop policy if exists perkapi_gallery_delete on storage.objects;
create policy perkapi_gallery_delete on storage.objects for delete to authenticated
  using (
    bucket_id = 'gallery' and (
      public.is_admin()
      or ((storage.foldername(name))[1] = auth.uid()::text
          and not exists (select 1 from public.gallery_photos g where g.file_path = storage.objects.name))
    )
  );

-- 4) Pagari tabel berita agar akun yang belum disetujui admin utama tidak bisa membacanya -----------
do $$ begin
  execute 'drop policy if exists perkapi_require_approved on public.gallery_photos';
  execute 'create policy perkapi_require_approved on public.gallery_photos as restrictive for all to authenticated using ((select public.is_approved()))';
exception when others then raise notice 'SKIP require_approved gallery_photos: %', sqlerrm; end $$;

-- 5) Indeks untuk daftar "berita terbaru" di dashboard
create index if not exists gallery_photos_created_idx on public.gallery_photos(created_at desc);
