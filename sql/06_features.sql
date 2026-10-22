-- =====================================================================
-- PERKAPI - FITUR TAMBAHAN (jalankan SETELAH perkapi_complete.sql)
-- Aman dijalankan ulang. Isi:
--   1. Member Alert (peringatan anggota manual + otomatis)
--   2. Balasan pengaduan -> notifikasi ke pelapor
--   3. Forum: like
--   4. Event: RSVP
--   5. Tugas: checklist
--   6. Lampiran (catatan, pengaduan, event)
--   7. Berbagi catatan -> notifikasi ke penerima
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Permission baru: manage_alert (kirim peringatan ke anggota)
--    SUPER_ADMIN otomatis punya semua permission.
-- ---------------------------------------------------------------------
insert into public.role_permissions(role_id, permission)
select r.id, 'manage_alert'
from public.roles r
where r.code in ('ADMIN_PUSAT','ADMIN_CABANG','PENGURUS')
on conflict do nothing;


-- ---------------------------------------------------------------------
-- 1. MEMBER ALERT
-- ---------------------------------------------------------------------
create table if not exists public.member_alerts (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  body        text,
  severity    text not null default 'info',    -- info | warning | urgent
  target_type text not null default 'all',     -- all | branch | role | member
  target_id   uuid,                            -- id cabang / role / anggota
  is_active   boolean not null default true,
  starts_at   timestamptz not null default now(),
  expires_at  timestamptz,
  created_by  uuid references public.members(id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint member_alerts_severity_chk check (severity in ('info','warning','urgent')),
  constraint member_alerts_target_chk   check (target_type in ('all','branch','role','member'))
);

create table if not exists public.member_alert_reads (
  alert_id  uuid not null references public.member_alerts(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  read_at   timestamptz not null default now(),
  primary key (alert_id, member_id)
);

create index if not exists idx_member_alerts_active on public.member_alerts(is_active, starts_at);
create index if not exists idx_alert_reads_member   on public.member_alert_reads(member_id);

alter table public.member_alerts      enable row level security;
alter table public.member_alert_reads enable row level security;
revoke all on public.member_alerts, public.member_alert_reads from anon;

-- isi created_by otomatis
create or replace function public.set_alert_creator() returns trigger
language plpgsql security definer set search_path = public as
$$ begin
  if new.created_by is null then new.created_by := public.current_member_id(); end if;
  return new;
end $$;
drop trigger if exists trg_alert_creator on public.member_alerts;
create trigger trg_alert_creator before insert on public.member_alerts
  for each row execute function public.set_alert_creator();

-- kirim juga sebagai notifikasi (muncul di menu Notifikasi)
create or replace function public.fanout_member_alert() returns trigger
language plpgsql security definer set search_path = public as
$$ begin
  insert into public.notifications(member_id, type, title, body, link)
  select m.id, 'alert',
         (case new.severity when 'urgent' then '[PENTING] '
                            when 'warning' then '[PERINGATAN] ' else '' end) || new.title,
         new.body, '/alerts'
  from public.members m
  where m.status = 'Aktif' and (
        new.target_type = 'all'
     or (new.target_type = 'branch' and m.branch_id = new.target_id)
     or (new.target_type = 'member' and m.id = new.target_id)
     or (new.target_type = 'role' and exists(
           select 1 from public.member_roles mr
           where mr.member_id = m.id and mr.role_id = new.target_id)));
  return new;
exception when others then return new; end $$;
drop trigger if exists trg_alert_fanout on public.member_alerts;
create trigger trg_alert_fanout after insert on public.member_alerts
  for each row execute function public.fanout_member_alert();

drop trigger if exists trg_audit on public.member_alerts;
create trigger trg_audit after insert or update or delete on public.member_alerts
  for each row execute function public.audit_row();

-- RLS: hanya pengelola yang boleh membaca/menulis tabel langsung.
-- Anggota membaca lewat fungsi my_alerts() di bawah.
drop policy if exists ma_admin on public.member_alerts;
create policy ma_admin on public.member_alerts for all to authenticated
  using (public.has_permission('manage_alert'))
  with check (public.has_permission('manage_alert'));

drop policy if exists mar_own on public.member_alert_reads;
create policy mar_own on public.member_alert_reads for select to authenticated
  using (member_id = public.current_member_id());

-- Peringatan untuk saya: manual (dari pengelola) + otomatis (sistem)
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

  if coalesce(m.status,'Aktif') <> 'Aktif' then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:status','kind','system',
      'title','Status keanggotaan: ' || m.status,
      'body','Beberapa layanan mungkin dibatasi. Hubungi pengurus bila ada kekeliruan.',
      'severity','warning','created_at', now(),'is_read', false));
  end if;

  select count(*) into n from public.tasks
   where assigned_to = me and due_date < current_date and status <> 'Done';
  if n > 0 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:tasks_overdue','kind','system',
      'title', n || ' tugas melewati deadline','body','Buka menu Tugas untuk menyelesaikannya.',
      'severity','urgent','created_at', now(),'is_read', false));
  end if;

  select count(*) into n from public.tasks
   where assigned_to = me and status <> 'Done'
     and due_date between current_date and current_date + 2;
  if n > 0 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:tasks_soon','kind','system',
      'title', n || ' tugas jatuh tempo dalam 2 hari','body','Segera selesaikan agar tidak terlambat.',
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
      'title', n || ' agenda dalam 24 jam ke depan','body','Cek menu Event dan jangan lupa check-in.',
      'severity','info','created_at', now(),'is_read', false));
  end if;

  select count(*) into n from public.complaints where member_id = me and status = 'Menunggu';
  if n > 0 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:complaints_wait','kind','system',
      'title', n || ' pengaduan menunggu tanggapan Anda','body','Buka menu Pengaduan untuk membalas.',
      'severity','warning','created_at', now(),'is_read', false));
  end if;

  return sys || manual;
end $$;

create or replace function public.mark_alert_read(p_id uuid) returns void
language plpgsql security definer set search_path = public as
$$ declare me uuid := public.current_member_id();
begin
  if me is null then return; end if;
  insert into public.member_alert_reads(alert_id, member_id) values (p_id, me)
  on conflict do nothing;
exception when foreign_key_violation then null; end $$;

create or replace function public.mark_all_alerts_read() returns void
language plpgsql security definer set search_path = public as
$$ declare me uuid := public.current_member_id();
begin
  if me is null then return; end if;
  insert into public.member_alert_reads(alert_id, member_id)
  select (e->>'id')::uuid, me
  from jsonb_array_elements(public.my_alerts()) e
  where e->>'kind' = 'manual' and not (e->>'is_read')::boolean
  on conflict do nothing;
end $$;

revoke all on function public.my_alerts(), public.mark_alert_read(uuid),
  public.mark_all_alerts_read() from public;
grant execute on function public.my_alerts(), public.mark_alert_read(uuid),
  public.mark_all_alerts_read() to authenticated;


-- ---------------------------------------------------------------------
-- 2. FORUM: LIKE
-- ---------------------------------------------------------------------
create table if not exists public.forum_likes (
  post_id    uuid not null references public.forum_posts(id) on delete cascade,
  member_id  uuid not null references public.members(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, member_id)
);
alter table public.forum_likes enable row level security;
revoke all on public.forum_likes from anon;
drop policy if exists fl_select on public.forum_likes;
drop policy if exists fl_insert on public.forum_likes;
drop policy if exists fl_delete on public.forum_likes;
create policy fl_select on public.forum_likes for select to authenticated using (true);
create policy fl_insert on public.forum_likes for insert to authenticated
  with check (member_id = public.current_member_id());
create policy fl_delete on public.forum_likes for delete to authenticated
  using (member_id = public.current_member_id());


-- ---------------------------------------------------------------------
-- 3. EVENT: RSVP
-- ---------------------------------------------------------------------
create table if not exists public.event_rsvps (
  event_id   uuid not null references public.events(id) on delete cascade,
  member_id  uuid not null references public.members(id) on delete cascade,
  status     text not null default 'Hadir',
  updated_at timestamptz not null default now(),
  primary key (event_id, member_id),
  constraint event_rsvps_status_chk check (status in ('Hadir','Mungkin','Tidak'))
);
alter table public.event_rsvps enable row level security;
revoke all on public.event_rsvps from anon;
drop policy if exists rv_select on public.event_rsvps;
drop policy if exists rv_insert on public.event_rsvps;
drop policy if exists rv_update on public.event_rsvps;
drop policy if exists rv_delete on public.event_rsvps;
create policy rv_select on public.event_rsvps for select to authenticated using (true);
create policy rv_insert on public.event_rsvps for insert to authenticated
  with check (member_id = public.current_member_id());
create policy rv_update on public.event_rsvps for update to authenticated
  using (member_id = public.current_member_id()) with check (member_id = public.current_member_id());
create policy rv_delete on public.event_rsvps for delete to authenticated
  using (member_id = public.current_member_id());


-- ---------------------------------------------------------------------
-- 4. TUGAS: CHECKLIST
--    Akses mengikuti akses ke tugas induknya (RLS tabel tasks berlaku
--    di dalam subquery untuk pengguna yang sedang login).
-- ---------------------------------------------------------------------
create table if not exists public.task_items (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid not null references public.tasks(id) on delete cascade,
  title      text not null,
  is_done    boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists idx_task_items_task on public.task_items(task_id, sort_order);
alter table public.task_items enable row level security;
revoke all on public.task_items from anon;
drop policy if exists ti_all on public.task_items;
create policy ti_all on public.task_items for all to authenticated
  using (exists(select 1 from public.tasks t where t.id = task_id))
  with check (exists(select 1 from public.tasks t where t.id = task_id));


-- ---------------------------------------------------------------------
-- 5. LAMPIRAN (catatan, pengaduan, event)
-- ---------------------------------------------------------------------
create table if not exists public.attachments (
  id          uuid primary key default gen_random_uuid(),
  entity_type text not null,                 -- note | complaint | event
  entity_id   uuid not null,
  bucket      text not null,
  file_path   text not null,
  file_name   text,
  mime_type   text,
  size_bytes  bigint,
  uploaded_by uuid references public.members(id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint attachments_type_chk check (entity_type in ('note','complaint','event'))
);
create index if not exists idx_attachments_entity on public.attachments(entity_type, entity_id);
alter table public.attachments enable row level security;
revoke all on public.attachments from anon;

create or replace function public.can_view_attachment(p_type text, p_id uuid) returns boolean
language sql stable security definer set search_path = public as
$$ select case p_type
     when 'note' then exists(select 1 from public.personal_notes n
                             where n.id = p_id and (n.member_id = public.current_member_id()
                                or exists(select 1 from public.personal_note_shares s
                                          where s.note_id = n.id and s.shared_with = public.current_member_id())))
     when 'complaint' then exists(select 1 from public.complaints c
                             where c.id = p_id and (c.member_id = public.current_member_id()
                                or public.has_permission('manage_complaint')))
     when 'event' then true
     else false end $$;

create or replace function public.can_attach(p_type text, p_id uuid) returns boolean
language sql stable security definer set search_path = public as
$$ select case p_type
     when 'note' then exists(select 1 from public.personal_notes n
                             where n.id = p_id and n.member_id = public.current_member_id())
     when 'complaint' then exists(select 1 from public.complaints c
                             where c.id = p_id and (c.member_id = public.current_member_id()
                                or public.has_permission('manage_complaint')))
     when 'event' then public.has_permission('manage_event')
     else false end $$;

grant execute on function public.can_view_attachment(text,uuid), public.can_attach(text,uuid) to authenticated;

drop policy if exists att_select on public.attachments;
drop policy if exists att_insert on public.attachments;
drop policy if exists att_delete on public.attachments;
create policy att_select on public.attachments for select to authenticated
  using (uploaded_by = public.current_member_id() or public.can_view_attachment(entity_type, entity_id));
create policy att_insert on public.attachments for insert to authenticated
  with check (uploaded_by = public.current_member_id() and public.can_attach(entity_type, entity_id));
create policy att_delete on public.attachments for delete to authenticated
  using (uploaded_by = public.current_member_id());

-- Penerima/pemilik boleh membaca file lampiran yang terdaftar & boleh dilihatnya
drop policy if exists perkapi_storage_attach_read on storage.objects;
create policy perkapi_storage_attach_read on storage.objects for select to authenticated
using (
  exists(select 1 from public.attachments a
         where a.bucket = bucket_id and a.file_path = name
           and public.can_view_attachment(a.entity_type, a.entity_id))
);


-- ---------------------------------------------------------------------
-- 6. NOTIFIKASI OTOMATIS: balasan pengaduan & catatan dibagikan
-- ---------------------------------------------------------------------
create or replace function public.notify_complaint_reply() returns trigger
language plpgsql security definer set search_path = public as
$$ declare c public.complaints;
begin
  select * into c from public.complaints where id = new.complaint_id;
  if c.id is not null and c.member_id <> new.sender_id then
    insert into public.notifications(member_id, type, title, body, link)
    values (c.member_id, 'complaint', 'Balasan pengaduan ' || coalesce(c.ticket_number,''),
            left(new.message, 140), '/module/complaints/' || c.id::text);
  end if;
  return new;
exception when others then return new; end $$;
drop trigger if exists trg_complaint_reply on public.complaint_messages;
create trigger trg_complaint_reply after insert on public.complaint_messages
  for each row execute function public.notify_complaint_reply();

create or replace function public.notify_note_share() returns trigger
language plpgsql security definer set search_path = public as
$$ declare n public.personal_notes;
begin
  select * into n from public.personal_notes where id = new.note_id;
  insert into public.notifications(member_id, type, title, body, link)
  values (new.shared_with, 'note_share', 'Catatan dibagikan kepada Anda',
          coalesce(n.title,''), '/pocket-book/' || new.note_id::text);
  return new;
exception when others then return new; end $$;
drop trigger if exists trg_note_share on public.personal_note_shares;
create trigger trg_note_share after insert on public.personal_note_shares
  for each row execute function public.notify_note_share();

-- SELESAI
