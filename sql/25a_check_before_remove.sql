-- 25a: PEMERIKSAAN SEBELUM MENGHAPUS FITUR (hanya membaca; tidak mengubah apa pun).
-- Jalankan di Supabase SQL Editor SEBELUM 25_remove_unused_features.sql, lalu simpan hasilnya.
-- Fitur yang dihapus: Perkara (+ tahapan & tagihan), Debitur, Kreditur, Dokumen (+ versi & tanda tangan),
-- Pengaduan (+ balasan), Tugas (+ checklist), Absensi.

-- 1) Jumlah baris di tiap tabel yang akan dihapus (tabel yang tidak ada ditampilkan sebagai "tidak ada").
select t.name as tabel,
       case when to_regclass('public.' || t.name) is null then 'tidak ada'
            else (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from public.%I', t.name), false, true, '')))[1]::text
       end as jumlah_baris
from (values ('cases'), ('case_stages'), ('case_claims'), ('debtors'), ('creditors'),
             ('documents'), ('document_versions'), ('document_signatures'),
             ('complaints'), ('complaint_messages'), ('tasks'), ('task_items'), ('attendance')) as t(name)
order by 1;

-- 2) Tabel LAIN yang punya foreign key ke tabel-tabel di atas.
--    Jika ada baris di luar daftar tabel yang akan dihapus, skrip 25 akan berhenti dengan galat
--    (itu disengaja, agar tidak ada yang terhapus diam-diam). Kirim hasil ini bila perlu bantuan.
select conrelid::regclass as tabel_anak, confrelid::regclass as tabel_induk, conname as nama_constraint
from pg_constraint
where contype = 'f'
  and confrelid::regclass::text in ('cases','case_stages','case_claims','debtors','creditors','documents',
        'document_versions','document_signatures','complaints','complaint_messages','tasks','task_items','attendance')
  and conrelid::regclass::text not in ('cases','case_stages','case_claims','debtors','creditors','documents',
        'document_versions','document_signatures','complaints','complaint_messages','tasks','task_items','attendance')
order by 2, 1;

-- 3) Jumlah berkas di bucket Storage yang akan dikosongkan (dihapus lewat Dashboard, bukan SQL).
select bucket_id, count(*) as jumlah_berkas
from storage.objects
where bucket_id in ('documents', 'case-documents', 'complaint-attachments', 'signatures')
group by bucket_id
order by 1;
