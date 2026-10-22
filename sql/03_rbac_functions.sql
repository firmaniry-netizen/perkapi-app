-- RBAC: tabel baru role_permissions (belum ada di daftar tabel Anda) + fungsi helper.
update roles set code = upper(replace(trim(name),' ','_')) where code is null and name is not null;

create table if not exists role_permissions(
  role_id uuid not null references roles(id) on delete cascade,
  permission text not null,
  primary key (role_id, permission)
);

create or replace function current_member_id() returns uuid
language sql stable security definer set search_path = public as
$$ select id from members where user_id = auth.uid() limit 1 $$;

create or replace function is_super() returns boolean
language sql stable security definer set search_path = public as
$$ select exists(select 1 from member_roles mr join roles r on r.id = mr.role_id
                 where mr.member_id = current_member_id() and r.code = 'SUPER_ADMIN') $$;

create or replace function has_permission(p text) returns boolean
language sql stable security definer set search_path = public as
$$ select is_super() or exists(
     select 1 from member_roles mr join role_permissions rp on rp.role_id = mr.role_id
     where mr.member_id = current_member_id() and rp.permission = p) $$;

create or replace function my_access() returns jsonb
language sql stable security definer set search_path = public as
$$ select jsonb_build_object(
     'member', to_jsonb(m),
     'roles', coalesce((select jsonb_agg(r.code) from member_roles mr join roles r on r.id = mr.role_id where mr.member_id = m.id), '[]'::jsonb),
     'permissions', coalesce((select jsonb_agg(distinct rp.permission) from member_roles mr join role_permissions rp on rp.role_id = mr.role_id where mr.member_id = m.id), '[]'::jsonb),
     'is_super', is_super())
   from members m where m.user_id = auth.uid() limit 1 $$;

create or replace function verify_member_qr(p_token uuid) returns jsonb
language sql stable security definer set search_path = public as
$$ select case when has_permission('manage_member') then
     (select jsonb_build_object('full_name', full_name, 'member_number', member_number, 'status', status, 'valid_until', valid_until)
      from members where qr_token = p_token) else null end $$;

create or replace function log_event(p_action text, p_module text, p_record text default null, p_meta jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = public as
$$ begin
  insert into audit_logs(member_id, action, module, record_id, metadata)
  values (current_member_id(), p_action, p_module, p_record, p_meta);
exception when others then null; end $$;

grant execute on function my_access(), verify_member_qr(uuid), log_event(text,text,text,jsonb), has_permission(text), current_member_id() to authenticated;

-- Seed permission default. Sesuaikan kapan saja. SUPER_ADMIN otomatis semua.
insert into role_permissions(role_id, permission)
select r.id, p from roles r,
unnest(case r.code
  when 'ADMIN_PUSAT' then array['view_case','manage_case','view_document','manage_document','manage_complaint','manage_event','manage_announcement','manage_member','manage_user','manage_task','moderate_forum','view_audit_log','view_member']
  when 'ADMIN_CABANG' then array['view_case','view_document','manage_complaint','manage_event','manage_announcement','manage_task','moderate_forum','view_member']
  when 'PENGURUS' then array['view_case','view_document','manage_event','manage_announcement','manage_task','view_member']
  when 'KURATOR' then array['view_case','manage_case','view_document','manage_document','manage_task','view_member']
  when 'PENGURUS_PKPU' then array['view_case','manage_case','view_document','manage_document','manage_task','view_member']
  when 'STAFF' then array['view_case','view_document','manage_task','view_member']
  when 'ANGGOTA' then array['view_member']
  else array[]::text[] end) p
on conflict do nothing;
