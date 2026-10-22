-- RLS untuk semua tabel. Tiap policy dibuat dalam blok aman: jika kolom/tabel tidak cocok,
-- policy dilewati dengan NOTICE (cek output) dan TIDAK menghentikan skrip.
-- PENTING: tabel dengan RLS aktif tanpa policy = tidak ada akses. Periksa NOTICE lalu perbaiki.
create or replace function _pol(t text, n text, cmd text, u text, c text default null) returns void
language plpgsql as $$
begin
  execute format('alter table public.%I enable row level security', t);
  execute format('drop policy if exists %I on public.%I', n, t);
  execute format('create policy %I on public.%I for %s %s %s', n, t, cmd,
    case when u is not null then 'using ('||u||')' else '' end,
    case when c is not null then 'with check ('||c||')' else '' end);
exception when others then raise notice 'SKIP %.%: %', t, n, sqlerrm;
end $$;

-- Catatan pribadi: hanya pemilik (dan penerima share untuk SELECT)
select _pol('personal_notes','pn_select','select','member_id = current_member_id() or exists(select 1 from personal_note_shares s where s.note_id = personal_notes.id and s.shared_with = current_member_id())');
select _pol('personal_notes','pn_insert','insert',null,'member_id = current_member_id()');
select _pol('personal_notes','pn_update','update','member_id = current_member_id()','member_id = current_member_id()');
select _pol('personal_notes','pn_delete','delete','member_id = current_member_id()');
select _pol('personal_note_categories','pnc_select','select','true');
select _pol('personal_note_categories','pnc_admin','all','has_permission(''manage_user'')','has_permission(''manage_user'')');
select _pol('personal_note_shares','pns_owner','all','exists(select 1 from personal_notes n where n.id = note_id and n.member_id = current_member_id())','exists(select 1 from personal_notes n where n.id = note_id and n.member_id = current_member_id())');
select _pol('personal_note_shares','pns_recipient','select','shared_with = current_member_id()');

-- Buku saku organisasi, info, event, cabang: baca semua anggota login, tulis by permission
select _pol('pocket_book_contents','pbc_select','select','is_published or has_permission(''manage_announcement'')');
select _pol('pocket_book_contents','pbc_write','all','has_permission(''manage_announcement'')','has_permission(''manage_announcement'')');
select _pol('announcements','an_select','select','is_published or has_permission(''manage_announcement'')');
select _pol('announcements','an_write','all','has_permission(''manage_announcement'')','has_permission(''manage_announcement'')');
select _pol('events','ev_select','select','true');
select _pol('events','ev_write','all','has_permission(''manage_event'')','has_permission(''manage_event'')');
select _pol('branches','br_select','select','true');
select _pol('branches','br_write','all','has_permission(''manage_user'')','has_permission(''manage_user'')');

-- Anggota & role
select _pol('members','mb_select','select','user_id = auth.uid() or has_permission(''view_member'') or has_permission(''manage_member'')');
select _pol('members','mb_insert','insert',null,'has_permission(''manage_member'')');
select _pol('members','mb_update','update','user_id = auth.uid() or has_permission(''manage_member'')','user_id = auth.uid() or has_permission(''manage_member'')');
select _pol('members','mb_delete','delete','has_permission(''manage_member'')');
select _pol('roles','rl_select','select','true');
select _pol('roles','rl_write','all','has_permission(''manage_role'')','has_permission(''manage_role'')');
select _pol('member_roles','mr_select','select','member_id = current_member_id() or has_permission(''manage_role'')');
select _pol('member_roles','mr_write','all','has_permission(''manage_role'')','has_permission(''manage_role'')');
select _pol('role_permissions','rp_select','select','true');
select _pol('role_permissions','rp_write','all','has_permission(''manage_role'')','has_permission(''manage_role'')');

-- Perkara, debitur, kreditur, dokumen (sensitif)
select _pol('cases','cs_select','select','has_permission(''view_case'') or assigned_to = current_member_id()');
select _pol('cases','cs_write','all','has_permission(''manage_case'')','has_permission(''manage_case'')');
select _pol('debtors','db_select','select','has_permission(''view_case'')');
select _pol('debtors','db_write','all','has_permission(''manage_case'')','has_permission(''manage_case'')');
select _pol('creditors','cr_select','select','has_permission(''view_case'')');
select _pol('creditors','cr_write','all','has_permission(''manage_case'')','has_permission(''manage_case'')');
select _pol('documents','dc_select','select','has_permission(''view_document'') or uploaded_by = current_member_id()');
select _pol('documents','dc_write','all','has_permission(''manage_document'')','has_permission(''manage_document'')');

-- Pengaduan
select _pol('complaints','cp_select','select','member_id = current_member_id() or has_permission(''manage_complaint'')');
select _pol('complaints','cp_insert','insert',null,'member_id = current_member_id()');
select _pol('complaints','cp_update','update','has_permission(''manage_complaint'')','has_permission(''manage_complaint'')');
select _pol('complaint_messages','cm_select','select','exists(select 1 from complaints c where c.id = complaint_id and (c.member_id = current_member_id() or has_permission(''manage_complaint'')))');
select _pol('complaint_messages','cm_insert','insert',null,'sender_id = current_member_id() and exists(select 1 from complaints c where c.id = complaint_id and (c.member_id = current_member_id() or has_permission(''manage_complaint'')))');

-- Absensi, notifikasi, tugas, forum, AI, audit
select _pol('attendance','at_select','select','member_id = current_member_id() or has_permission(''manage_event'')');
select _pol('attendance','at_insert','insert',null,'member_id = current_member_id()');
select _pol('attendance','at_update','update','member_id = current_member_id()','member_id = current_member_id()');
select _pol('notifications','nt_select','select','member_id = current_member_id()');
select _pol('notifications','nt_update','update','member_id = current_member_id()','member_id = current_member_id()');
select _pol('notifications','nt_admin_insert','insert',null,'has_permission(''manage_announcement'') or has_permission(''manage_task'')');
select _pol('tasks','tk_select','select','assigned_to = current_member_id() or created_by = current_member_id() or has_permission(''manage_task'')');
select _pol('tasks','tk_insert','insert',null,'created_by = current_member_id()');
select _pol('tasks','tk_update','update','assigned_to = current_member_id() or created_by = current_member_id() or has_permission(''manage_task'')','assigned_to = current_member_id() or created_by = current_member_id() or has_permission(''manage_task'')');
select _pol('tasks','tk_delete','delete','created_by = current_member_id() or has_permission(''manage_task'')');
select _pol('forum_posts','fp_select','select','not coalesce(is_hidden,false) or has_permission(''moderate_forum'')');
select _pol('forum_posts','fp_insert','insert',null,'author_id = current_member_id()');
select _pol('forum_posts','fp_update','update','author_id = current_member_id() or has_permission(''moderate_forum'')','author_id = current_member_id() or has_permission(''moderate_forum'')');
select _pol('forum_posts','fp_delete','delete','author_id = current_member_id() or has_permission(''moderate_forum'')');
select _pol('forum_comments','fc_select','select','true');
select _pol('forum_comments','fc_insert','insert',null,'author_id = current_member_id()');
select _pol('forum_comments','fc_delete','delete','author_id = current_member_id() or has_permission(''moderate_forum'')');
select _pol('ai_conversations','aic_owner','all','member_id = current_member_id()','member_id = current_member_id()');
select _pol('ai_messages','aim_owner','all','exists(select 1 from ai_conversations c where c.id = conversation_id and c.member_id = current_member_id())','exists(select 1 from ai_conversations c where c.id = conversation_id and c.member_id = current_member_id())');
select _pol('audit_logs','al_select','select','has_permission(''view_audit_log'')');
-- audit_logs: tanpa policy insert/update/delete untuk client; tulis lewat log_event()/trigger (security definer).
