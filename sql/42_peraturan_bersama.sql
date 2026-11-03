-- 42_peraturan_bersama.sql — satu daftar peraturan untuk situs (peraturan.html) dan aplikasi (menu Peraturan & Hukum).
-- Dikelola dari panel admin situs (menu "Peraturan"); admin aplikasi juga boleh mengubah.
create table if not exists public.site_regulations (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('Undang-Undang', 'Peraturan Menteri', 'Putusan MK', 'Rancangan')),
  number text not null,
  summary text not null default '',
  pdf_url text,
  page_url text,
  page_label text default 'Lihat',
  sort_order int not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.site_regulations enable row level security;
drop policy if exists sr_public_read on public.site_regulations;
create policy sr_public_read on public.site_regulations for select using (is_active);
drop policy if exists sr_siteadmin on public.site_regulations;
create policy sr_siteadmin on public.site_regulations for all using (is_site_admin()) with check (is_site_admin());
drop policy if exists sr_appadmin on public.site_regulations;
create policy sr_appadmin on public.site_regulations for all using (is_admin()) with check (is_admin());
grant select on public.site_regulations to anon, authenticated;
grant insert, update, delete on public.site_regulations to authenticated;

create or replace function public.public_regulations()
returns table(id uuid, kind text, number text, summary text, pdf_url text, page_url text, page_label text)
language sql stable security definer set search_path = public as $$
  select r.id, r.kind, r.number, r.summary, r.pdf_url, r.page_url, r.page_label
  from site_regulations r where r.is_active order by r.sort_order, r.created_at;
$$;
grant execute on function public.public_regulations() to anon, authenticated;

insert into public.site_regulations (kind, number, summary, pdf_url, page_url, page_label, sort_order)
select * from (values
  ('Undang-Undang', 'UU No. 37 Tahun 2004', 'Kepailitan dan Penundaan Kewajiban Pembayaran Utang. Pasal 223 dicabut oleh UU No. 4 Tahun 2023 (P2SK). Beberapa pasal telah ditafsirkan Mahkamah Konstitusi, lihat putusan di bawah.', 'https://peraturan.go.id/files/uu37-2004.pdf', 'https://peraturan.bpk.go.id/Details/40784/uu-no-37-tahun-2004', 'Status', 10),
  ('Peraturan Menteri', 'Permenkum No. 20 Tahun 2025', 'Pedoman imbalan jasa bagi kurator dan pengurus. Berlaku sejak 27 Mei 2025, menggantikan Permenkumham No. 18 Tahun 2021.', null, 'https://pasal.id/peraturan/permen/permenkum-no-20-tahun-2025', 'Lihat', 20),
  ('Peraturan Menteri', 'Permenkumham No. 37 Tahun 2018', 'Syarat dan tata cara pendaftaran serta penyampaian laporan kurator dan pengurus. Masih berlaku.', 'https://peraturan.go.id/files/bn1686-2018.pdf', 'https://pasal.id/peraturan/permen/permenkumham-no-37-tahun-2018', 'Status', 30),
  ('Putusan MK', 'Putusan MK No. 243/PUU-XXIV/2026', '29 September 2026. Pasal 127 ayat (1) dan penjelasannya: bila hakim pengawas tidak dapat mendamaikan, perselisihan diselesaikan di pengadilan (pengadilan negeri, pengadilan tinggi, atau MA) untuk perkara yang diajukan sebelum putusan pailit.', null, 'https://pasal.id/peraturan/putusan-mk/puu-mk-243-2026', 'Lihat', 40),
  ('Putusan MK', 'Putusan MK No. 181/PUU-XXIII/2025', '25 Mei 2026. Penjelasan Pasal 292: harta pailit berada dalam keadaan insolvensi sejak dinyatakan hakim pengawas dalam rapat kreditor dan dicatat dalam berita acara.', null, 'https://pasal.id/peraturan/putusan-mk/puu-mk-181-2025', 'Lihat', 50),
  ('Putusan MK', 'Putusan MK No. 14/PUU-XXIV/2026', '25 Mei 2026. Permohonan atas Pasal 292 ditolak: rujukan ke Pasal 286 dan larangan menawarkan perdamaian kembali tetap berlaku.', null, 'https://pasal.id/peraturan/putusan-mk/puu-mk-14-2026', 'Lihat', 60),
  ('Putusan MK', 'Putusan MK No. 74/PUU-XXIV/2026', '29 April 2026. Pasal 74 ayat (1): kurator melapor ke hakim pengawas tiap 3 bulan, dengan tembusan kepada kreditor dan debitor pailit.', 'https://s.mkri.id/public/content/persidangan/putusan/putusan_mkri_14183_1777450375.pdf', null, null, 70),
  ('Rancangan', 'RUU Profesi Kurator', 'Usul inisiatif DPR sejak April 2026. PERKAPI mendorongnya masuk Prolegnas Prioritas. Masih rancangan dan belum berlaku.', null, 'https://www.hukumonline.com/berita/a/pemerintah-dpr-sepakat-6-ruu-ini-jadi-usul-inisiatif-dpr-lt69e0455bc1771/', 'Baca beritanya', 80)
) v(kind, number, summary, pdf_url, page_url, page_label, sort_order)
where not exists (select 1 from public.site_regulations);
