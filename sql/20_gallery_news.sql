-- Galeri bergaya berita: satu "berita" = judul + isi tulisan + beberapa foto.
-- Foto yang diunggah bersamaan berbagi post_id yang sama. Foto lama (post_id kosong) tetap tampil.
-- Aman dijalankan ulang. Jalankan di Supabase SQL Editor setelah 18_gallery.sql.
alter table public.gallery_photos add column if not exists post_id uuid;
alter table public.gallery_photos add column if not exists title text;
alter table public.gallery_photos add column if not exists body text;
create index if not exists gallery_photos_post_idx on public.gallery_photos(post_id);
