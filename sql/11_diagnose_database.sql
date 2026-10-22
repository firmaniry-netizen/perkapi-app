-- 11: PEMERIKSA DATABASE PERKAPI (READ ONLY: hanya membaca, tidak mengubah apa pun).
-- Jalankan SEKALI di Supabase SQL Editor. Hasil: satu tabel berisi MASALAH saja.
-- Bila hanya muncul satu baris "SEMUA OK", database sudah sesuai dengan yang diminta aplikasi.
-- Daftar tabel/kolom/fungsi/bucket di bawah dihasilkan dari kode aplikasi (lib/).

with
need_tables(t) as (values ('ai_conversations'), ('ai_messages'), ('announcements'), ('attachments'), ('attendance'), ('audit_logs'), ('branches'), ('cases'), ('complaint_messages'), ('complaints'), ('creditors'), ('debtors'), ('document_versions'), ('documents'), ('event_rsvps'), ('events'), ('forum_comments'), ('forum_likes'), ('forum_posts'), ('member_alert_reads'), ('member_alerts'), ('member_roles'), ('members'), ('notifications'), ('personal_note_categories'), ('personal_note_shares'), ('personal_notes'), ('pocket_book_contents'), ('role_permissions'), ('roles'), ('task_items'), ('tasks')),
need_cols(t, c) as (values
    ('announcements','body'),
    ('announcements','category'),
    ('announcements','created_at'),
    ('announcements','created_by'),
    ('announcements','id'),
    ('announcements','is_published'),
    ('announcements','title'),
    ('audit_logs','action'),
    ('audit_logs','created_at'),
    ('audit_logs','id'),
    ('audit_logs','module'),
    ('audit_logs','record_id'),
    ('branches','city'),
    ('branches','code'),
    ('branches','id'),
    ('branches','name'),
    ('cases','assigned_to'),
    ('cases','case_date'),
    ('cases','case_number'),
    ('cases','case_type'),
    ('cases','court'),
    ('cases','created_at'),
    ('cases','deadline'),
    ('cases','id'),
    ('cases','notes'),
    ('cases','status'),
    ('cases','title'),
    ('complaints','category'),
    ('complaints','created_at'),
    ('complaints','description'),
    ('complaints','id'),
    ('complaints','member_id'),
    ('complaints','priority'),
    ('complaints','status'),
    ('complaints','ticket_number'),
    ('complaints','title'),
    ('creditors','address'),
    ('creditors','case_id'),
    ('creditors','created_at'),
    ('creditors','creditor_type'),
    ('creditors','email'),
    ('creditors','id'),
    ('creditors','identity_number'),
    ('creditors','name'),
    ('creditors','phone'),
    ('creditors','status'),
    ('debtors','address'),
    ('debtors','case_id'),
    ('debtors','created_at'),
    ('debtors','debtor_type'),
    ('debtors','email'),
    ('debtors','id'),
    ('debtors','identity_number'),
    ('debtors','name'),
    ('debtors','phone'),
    ('debtors','status'),
    ('events','description'),
    ('events','ends_at'),
    ('events','id'),
    ('events','latitude'),
    ('events','location'),
    ('events','longitude'),
    ('events','starts_at'),
    ('events','title'),
    ('forum_posts','author_id'),
    ('forum_posts','body'),
    ('forum_posts','category'),
    ('forum_posts','created_at'),
    ('forum_posts','id'),
    ('forum_posts','is_hidden'),
    ('forum_posts','title'),
    ('members','approval_status'),
    ('members','avatar_path'),
    ('members','branch_id'),
    ('members','email'),
    ('members','full_name'),
    ('members','id'),
    ('members','member_number'),
    ('members','phone'),
    ('members','qr_token'),
    ('members','status'),
    ('members','user_id'),
    ('members','valid_until'),
    ('notifications','body'),
    ('notifications','created_at'),
    ('notifications','id'),
    ('notifications','member_id'),
    ('notifications','title'),
    ('personal_notes','category_id'),
    ('personal_notes','content'),
    ('personal_notes','created_at'),
    ('personal_notes','id'),
    ('personal_notes','is_archived'),
    ('personal_notes','is_favorite'),
    ('personal_notes','is_pinned'),
    ('personal_notes','member_id'),
    ('personal_notes','reminder_at'),
    ('personal_notes','tags'),
    ('personal_notes','title'),
    ('pocket_book_contents','category'),
    ('pocket_book_contents','content'),
    ('pocket_book_contents','created_at'),
    ('pocket_book_contents','id'),
    ('pocket_book_contents','is_published'),
    ('pocket_book_contents','title'),
    ('tasks','assigned_to'),
    ('tasks','created_at'),
    ('tasks','created_by'),
    ('tasks','description'),
    ('tasks','due_date'),
    ('tasks','id'),
    ('tasks','priority'),
    ('tasks','status'),
    ('tasks','title')
),
need_funcs(f) as (values ('audit_row'), ('can_attach'), ('can_view_attachment'), ('current_member_id'), ('delete_my_account'), ('fanout_member_alert'), ('handle_new_user'), ('has_permission'), ('is_approved'), ('is_super'), ('list_registrations'), ('log_event'), ('mark_alert_read'), ('mark_all_alerts_read'), ('members_guard_approval'), ('my_access'), ('my_alerts'), ('my_approval_status'), ('notify_complaint_reply'), ('notify_note_share'), ('pending_registration_count'), ('public_branches'), ('resolve_login_email'), ('review_registration'), ('set_alert_creator'), ('set_ticket_number'), ('set_updated_at'), ('snapshot_document_version'), ('verify_member_qr')),
need_buckets(b) as (values ('avatars'), ('case-documents'), ('complaint-attachments'), ('documents'), ('event-attachments'), ('note-attachments')),
masalah as (
  -- 1) tabel hilang
  select 1 as urut, 'TABEL HILANG' as jenis, n.t as item,
         'Tabel belum ada. Tabel dasar berasal dari perkapi_complete.sql (di luar folder sql/ ini).' as keterangan
    from need_tables n
   where not exists (select 1 from information_schema.tables x where x.table_schema='public' and x.table_name=n.t)
  union all
  -- 2) kolom hilang (hanya untuk tabel yang ada)
  select 2, 'KOLOM HILANG', n.t || '.' || n.c,
         'Jalankan 02_additive_columns.sql, atau ubah nama kolom di lib/shared/models/modules.dart.'
    from need_cols n
   where exists (select 1 from information_schema.tables x where x.table_schema='public' and x.table_name=n.t)
     and not exists (select 1 from information_schema.columns x where x.table_schema='public' and x.table_name=n.t and x.column_name=n.c)
  union all
  -- 3) fungsi hilang
  select 3, 'FUNGSI HILANG', n.f,
         case when n.f = 'delete_my_account' then 'Jalankan 10_delete_account.sql.'
              when n.f in ('current_member_id','has_permission','is_super','log_event','my_access','verify_member_qr') then 'Jalankan 03_rbac_functions.sql.'
              when n.f in ('resolve_login_email') then 'Jalankan 01_resolve_login_email.sql.'
              when n.f in ('audit_row','set_ticket_number','set_updated_at') then 'Jalankan 05_triggers_storage.sql.'
              when n.f in ('snapshot_document_version') then 'Jalankan 07_document_versions.sql.'
              when n.f in ('handle_new_user','is_approved','list_registrations','members_guard_approval','my_approval_status','pending_registration_count','public_branches','review_registration') then 'Jalankan 08_registration_approval.sql.'
              else 'Jalankan 06_features.sql.' end
    from need_funcs n
   where not exists (select 1 from information_schema.routines x where x.routine_schema='public' and x.routine_name=n.f)
  union all
  -- 4) bucket storage hilang
  select 4, 'BUCKET HILANG', n.b, 'Jalankan 05_triggers_storage.sql (dan 09_member_avatars.sql untuk avatars).'
    from need_buckets n
   where not exists (select 1 from storage.buckets x where x.id=n.b)
  union all
  -- 5) RLS aktif tetapi tanpa policy = semua akses ditolak
  select 5, 'RLS TANPA POLICY', c.relname::text,
         'RLS aktif tetapi tidak ada policy, jadi semua akses ditolak. Jalankan 04_rls_policies.sql dan baca NOTICE SKIP-nya.'
    from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
   where ns.nspname='public' and c.relkind='r' and c.relrowsecurity
     and c.relname in (select t from need_tables)
     and not exists (select 1 from pg_policies p where p.schemaname='public' and p.tablename=c.relname)
  union all
  -- 6) RLS mati = data terbuka bagi siapa pun yang punya anon key
  select 6, 'RLS MATI (BERBAHAYA)', c.relname::text,
         'Tanpa RLS, siapa pun dengan anon key dapat membaca/ubah tabel ini. Jalankan 04_rls_policies.sql.'
    from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
   where ns.nspname='public' and c.relkind='r' and not c.relrowsecurity
     and c.relname in (select t from need_tables)
  union all
  -- 7) akun login yang belum terhubung ke baris members (penyebab Buku Saku/data pribadi gagal)
  select 7, 'AKUN TANPA DATA ANGGOTA', coalesce(u.email, u.id::text),
         'Isi members.user_id dengan: ' || u.id::text
    from auth.users u
   where exists (select 1 from information_schema.columns x where x.table_schema='public' and x.table_name='members' and x.column_name='user_id')
     and not exists (select 1 from public.members m where m.user_id = u.id)
)
select jenis, item, keterangan from masalah
union all
select 'SEMUA OK', '-', 'Tidak ada masalah yang terdeteksi.' where not exists (select 1 from masalah)
order by 1, 2;
