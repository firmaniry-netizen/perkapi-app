-- 25: HAPUS PERMANEN fitur yang tidak dipakai lagi.
--   Perkara (+ tahapan & tagihan), Debitur, Kreditur, Dokumen (+ versi & tanda tangan),
--   Pengaduan (+ balasan), Tugas (+ checklist), Absensi.
--
-- !!! TIDAK DAPAT DIBATALKAN. Data di tabel-tabel itu hilang selamanya. !!!
-- Sebelum menjalankan:
--   1. Buat backup: Supabase Dashboard > Database > Backups (atau ekspor tabelnya ke CSV).
--   2. Jalankan 25a_check_before_remove.sql dan baca hasilnya.
--   3. Pastikan APK versi baru (tanpa fitur-fitur ini) sudah terpasang di semua pengguna.
--      APK lama yang masih memanggil tabel-tabel ini akan mengalami galat setelah skrip ini jalan.
--
-- Seluruh skrip berjalan dalam SATU transaksi: bila ada langkah yang gagal, TIDAK ADA yang berubah.
-- Tabel dihapus TANPA "cascade" (disengaja), jadi bila ada objek lain yang masih bergantung,
-- skrip berhenti dengan pesan galat. Kirim pesan itu bila terjadi.

begin;

-- 1) Notifikasi dan jejak pengingat lama yang tautannya ke menu yang sudah tidak ada.
delete from public.notifications
 where type = 'complaint'
    or link ~ '^/(cases|tasks|documents|complaints|attendance)'
    or link ~ '^/module/(cases|tasks|complaints|debtors|creditors)';
delete from public.reminder_log where kind in ('task', 'case_deadline', 'case_date');
delete from public.attachments where entity_type = 'complaint';

-- 2) Ganti fungsi yang masih menyebut tabel-tabel itu (WAJIB sebelum tabel dihapus,
--    karena pengingat otomatis berjalan tiap 15 menit lewat pg_cron).

-- 2a) Pengingat otomatis: tinggal event.
create or replace function public.run_reminders() returns void
language plpgsql security definer set search_path = public as $$
begin
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

  delete from reminder_log where created_at < now() - interval '60 days';
end $$;
revoke all on function public.run_reminders() from public, anon, authenticated;

-- 2b) Peringatan otomatis di aplikasi: buang blok tahapan perkara, tugas, dan pengaduan.
create or replace function public.my_alerts() returns jsonb
language plpgsql stable security definer set search_path = public as
$$
declare
  me   uuid := public.current_member_id();
  m    public.members;
  manual jsonb;
  sys    jsonb := '[]'::jsonb;
  n    int;
begin
  if me is null then return '[]'::jsonb; end if;
  select * into m from public.members where id = me;

  -- 1) peringatan manual yang ditujukan ke saya
  select coalesce(jsonb_agg(x order by (x->>'created_at') desc), '[]'::jsonb) into manual
  from (
    select jsonb_build_object(
             'id', a.id::text, 'kind', 'manual', 'title', a.title, 'body', a.body,
             'severity', a.severity, 'created_at', a.created_at,
             'is_read', exists(select 1 from public.member_alert_reads r
                               where r.alert_id = a.id and r.member_id = me)) as x
    from public.member_alerts a
    where a.is_active and a.starts_at <= now()
      and (a.expires_at is null or a.expires_at > now())
      and (   a.target_type = 'all'
           or (a.target_type = 'branch' and a.target_id = m.branch_id)
           or (a.target_type = 'member' and a.target_id = me)
           or (a.target_type = 'role' and exists(
                 select 1 from public.member_roles mr
                 where mr.member_id = me and mr.role_id = a.target_id)))
  ) s;

  -- 2) peringatan otomatis (dihitung saat dibaca, tidak disimpan)
  if m.valid_until is not null and m.valid_until < current_date then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:membership','kind','system',
      'title','Keanggotaan Anda sudah berakhir',
      'body','Masa berlaku berakhir pada ' || to_char(m.valid_until,'DD-MM-YYYY') || '. Hubungi pengurus untuk perpanjangan.',
      'severity','urgent','created_at', now(),'is_read', false));
  elsif m.valid_until is not null and m.valid_until <= current_date + 30 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:membership','kind','system',
      'title','Keanggotaan segera berakhir',
      'body','Masa berlaku berakhir pada ' || to_char(m.valid_until,'DD-MM-YYYY') || ' (' || (m.valid_until - current_date) || ' hari lagi).',
      'severity','warning','created_at', now(),'is_read', false));
  end if;

  -- AHU: pendaftaran kurator/pengurus akan / sudah berakhir (hanya bila anggota mengisi masa berlaku)
  if m.ahu_registration_number is not null and m.ahu_valid_until is not null then
    if m.ahu_valid_until < current_date then
      sys := sys || jsonb_build_array(jsonb_build_object('id','sys:ahu','kind','system',
        'title','Pendaftaran AHU Anda sudah berakhir',
        'body','Masa berlaku pendaftaran kurator/pengurus berakhir pada ' || to_char(m.ahu_valid_until,'DD-MM-YYYY') || '. Segera perpanjang di AHU Online lalu perbarui datanya di aplikasi.',
        'severity','urgent','created_at', now(),'is_read', false));
    elsif m.ahu_valid_until <= current_date + 60 then
      sys := sys || jsonb_build_array(jsonb_build_object('id','sys:ahu','kind','system',
        'title','Pendaftaran AHU segera berakhir',
        'body','Berakhir pada ' || to_char(m.ahu_valid_until,'DD-MM-YYYY') || ' (' || (m.ahu_valid_until - current_date) || ' hari lagi). Siapkan perpanjangan di AHU Online.',
        'severity','warning','created_at', now(),'is_read', false));
    end if;
  end if;

  if coalesce(m.status,'Aktif') <> 'Aktif' then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:status','kind','system',
      'title','Status keanggotaan: ' || m.status,
      'body','Beberapa layanan mungkin dibatasi. Hubungi pengurus bila ada kekeliruan.',
      'severity','warning','created_at', now(),'is_read', false));
  end if;

  select count(*) into n from public.personal_notes
   where member_id = me and not is_archived and reminder_at is not null
     and reminder_at <= now() and reminder_at > now() - interval '7 days';
  if n > 0 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:note_reminder','kind','system',
      'title', n || ' pengingat catatan','body','Ada catatan Buku Saku yang waktunya telah tiba.',
      'severity','info','created_at', now(),'is_read', false));
  end if;

  select count(*) into n from public.events
   where starts_at between now() and now() + interval '24 hours';
  if n > 0 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:events_soon','kind','system',
      'title', n || ' agenda dalam 24 jam ke depan','body','Cek menu Event untuk detailnya.',
      'severity','info','created_at', now(),'is_read', false));
  end if;

  return sys || manual;
end $$;

-- 2c) Lampiran: buang cabang "complaint" (lampiran catatan dan event tetap seperti semula).
create or replace function public.can_view_attachment(p_type text, p_id uuid) returns boolean
language sql stable security definer set search_path = public as
$$ select case p_type
     when 'note' then exists(select 1 from public.personal_notes n
                             where n.id = p_id and (n.member_id = public.current_member_id()
                                or exists(select 1 from public.personal_note_shares s
                                          where s.note_id = n.id and s.shared_with = public.current_member_id())))
     when 'event' then true
     else false end $$;

create or replace function public.can_attach(p_type text, p_id uuid) returns boolean
language sql stable security definer set search_path = public as
$$ select case p_type
     when 'note' then exists(select 1 from public.personal_notes n
                             where n.id = p_id and n.member_id = public.current_member_id())
     when 'event' then public.has_permission('manage_event')
     else false end $$;

grant execute on function public.can_view_attachment(text,uuid), public.can_attach(text,uuid) to authenticated;

-- 2d) Kebijakan Storage: buang bucket documents, case-documents, complaint-attachments.
drop policy if exists perkapi_docs_member_upload on storage.objects;
drop policy if exists perkapi_storage_read on storage.objects;
drop policy if exists perkapi_storage_write on storage.objects;
drop policy if exists perkapi_storage_delete on storage.objects;

create policy perkapi_storage_read on storage.objects for select to authenticated using (
  (bucket_id in ('avatars','event-attachments'))
  or (bucket_id in ('note-attachments') and (storage.foldername(name))[1] = auth.uid()::text));

create policy perkapi_storage_write on storage.objects for insert to authenticated with check (
  ((storage.foldername(name))[1] = auth.uid()::text and bucket_id in ('avatars','note-attachments'))
  or (bucket_id = 'event-attachments' and has_permission('manage_event')));

create policy perkapi_storage_delete on storage.objects for delete to authenticated using (
  ((storage.foldername(name))[1] = auth.uid()::text and bucket_id in ('avatars','note-attachments'))
  or (bucket_id = 'event-attachments' and has_permission('manage_event')));

-- 4) Hapus tabel (anak lebih dulu). TANPA cascade: bila ada ketergantungan lain, skrip berhenti.
-- Urutan: tabel yang merujuk ke perkara (cases) dihapus lebih dulu, perkara paling akhir.
drop table if exists public.attendance;
drop table if exists public.task_items;
drop table if exists public.tasks;
drop table if exists public.complaint_messages;
drop table if exists public.complaints;
drop table if exists public.document_signatures;
drop table if exists public.document_versions;
drop table if exists public.documents;
drop table if exists public.case_claims;
drop table if exists public.case_stages;
drop table if exists public.debtors;
drop table if exists public.creditors;
drop table if exists public.cases;

-- 5) Hapus fungsi khusus fitur yang dihapus. Dilakukan SETELAH tabel dihapus, karena trigger di tabel
--    (mis. trg_complaint_reply) bergantung pada fungsinya dan ikut hilang bersama tabelnya.
drop function if exists public.attendance_summary(date, date);
drop function if exists public.attendance_by_month(date, date);
drop function if exists public.sign_document(uuid, text);
drop function if exists public.document_signers(uuid);
drop function if exists public.notify_complaint_reply();
drop function if exists public.can_see_document(uuid);

commit;

-- 6) Verifikasi: hasilnya harus KOSONG (tidak ada baris).
select name as tabel_yang_masih_ada
from (values ('cases'), ('case_stages'), ('case_claims'), ('debtors'), ('creditors'), ('documents'),
             ('document_versions'), ('document_signatures'), ('complaints'), ('complaint_messages'),
             ('tasks'), ('task_items'), ('attendance')) as t(name)
where to_regclass('public.' || name) is not null;

-- SETELAH skrip ini sukses, lakukan lewat Dashboard / CLI (tidak bisa lewat SQL):
--   * Storage > hapus bucket: documents, case-documents, complaint-attachments, signatures
--     (kosongkan dulu isinya: "Empty bucket", lalu "Delete bucket").
--   * Edge Functions: supabase functions delete index-document
--                     supabase functions delete ai-summarize-document
