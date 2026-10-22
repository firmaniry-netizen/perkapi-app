-- 17_chat_signature_search.sql (setelah 03, 04, 08, 12; aman dijalankan ulang)
-- Isi: chat anggota (pribadi + grup), tanda tangan elektronik dokumen, kolom indeks isi PDF.

-- ================= CHAT =================
create table if not exists public.chat_threads(
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('direct','group')),
  title text,
  created_by uuid references public.members(id) on delete set null,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now());

create table if not exists public.chat_participants(
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (thread_id, member_id));
create index if not exists chat_participants_member_idx on public.chat_participants(member_id);

create table if not exists public.chat_messages(
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  sender_id uuid not null references public.members(id) on delete cascade,
  body text not null check (length(body) between 1 and 2000),
  created_at timestamptz not null default now());
create index if not exists chat_messages_thread_idx on public.chat_messages(thread_id, created_at desc);

-- Helper SECURITY DEFINER agar policy tidak saling merujuk (hindari error 42P17)
create or replace function public.chat_is_member(p_thread uuid) returns boolean
language sql stable security definer set search_path = public as
$$ select exists(select 1 from chat_participants where thread_id = p_thread and member_id = current_member_id()) $$;
grant execute on function public.chat_is_member(uuid) to authenticated;

alter table public.chat_threads enable row level security;
alter table public.chat_participants enable row level security;
alter table public.chat_messages enable row level security;

drop policy if exists ct_select on public.chat_threads;
create policy ct_select on public.chat_threads for select using (public.chat_is_member(id));
drop policy if exists cp_select on public.chat_participants;
create policy cp_select on public.chat_participants for select using (public.chat_is_member(thread_id));
drop policy if exists cm_select_chat on public.chat_messages;
create policy cm_select_chat on public.chat_messages for select using (public.chat_is_member(thread_id));
drop policy if exists cm_insert_chat on public.chat_messages;
create policy cm_insert_chat on public.chat_messages for insert
  with check (sender_id = current_member_id() and public.chat_is_member(thread_id));

revoke insert, update, delete on public.chat_threads, public.chat_participants from anon, authenticated;
revoke update, delete on public.chat_messages from anon, authenticated;
revoke all on public.chat_threads, public.chat_participants, public.chat_messages from anon;

do $$ declare t text; begin
  foreach t in array array['chat_threads','chat_participants','chat_messages'] loop
    begin
      execute format('drop policy if exists perkapi_require_approved on public.%I', t);
      execute format('create policy perkapi_require_approved on public.%I as restrictive for all to authenticated using ((select public.is_approved()))', t);
    exception when others then raise notice 'SKIP require_approved %: %', t, sqlerrm; end;
  end loop;
end $$;

create or replace function public.chat_directory() returns table(member_id uuid, name text)
language sql stable security definer set search_path = public as $$
  select m.id, coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota')
  from members m where m.approval_status = 'approved' and m.id <> current_member_id()
  order by 2 $$;

create or replace function public.chat_start_direct(p_other uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare me uuid := current_member_id(); tid uuid;
begin
  if me is null or p_other is null or p_other = me then raise exception 'invalid'; end if;
  if not exists (select 1 from members where id = p_other and approval_status = 'approved') then raise exception 'invalid'; end if;
  select t.id into tid from chat_threads t
  where t.kind = 'direct'
    and exists (select 1 from chat_participants a where a.thread_id = t.id and a.member_id = me)
    and exists (select 1 from chat_participants b where b.thread_id = t.id and b.member_id = p_other)
  limit 1;
  if tid is null then
    insert into chat_threads(kind, created_by) values ('direct', me) returning id into tid;
    insert into chat_participants(thread_id, member_id) values (tid, me), (tid, p_other);
  end if;
  return tid;
end $$;

create or replace function public.chat_create_group(p_title text, p_members uuid[]) returns uuid
language plpgsql security definer set search_path = public as $$
declare me uuid := current_member_id(); tid uuid;
begin
  if me is null or coalesce(trim(p_title), '') = '' then raise exception 'invalid'; end if;
  if coalesce(array_length(p_members, 1), 0) < 1 or array_length(p_members, 1) > 100 then raise exception 'invalid'; end if;
  insert into chat_threads(kind, title, created_by) values ('group', left(trim(p_title), 60), me) returning id into tid;
  insert into chat_participants(thread_id, member_id)
  select distinct tid, s.x from (select me as x union select unnest(p_members)) s
  where exists (select 1 from members m where m.id = s.x and m.approval_status = 'approved')
  on conflict do nothing;
  return tid;
end $$;

create or replace function public.chat_thread_members(p_thread uuid) returns table(member_id uuid, name text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not chat_is_member(p_thread) then raise exception 'forbidden'; end if;
  return query select m.id, coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota')
               from chat_participants p join members m on m.id = p.member_id where p.thread_id = p_thread;
end $$;

create or replace function public.chat_threads_overview() returns table(
  thread_id uuid, kind text, title text, last_body text, last_at timestamptz, unread bigint)
language plpgsql stable security definer set search_path = public as $$
declare me uuid := current_member_id();
begin
  return query
  select t.id, t.kind,
         case when t.kind = 'direct'
              then coalesce((select coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota')
                             from chat_participants p2 join members m on m.id = p2.member_id
                             where p2.thread_id = t.id and p2.member_id <> me limit 1), 'Anggota')
              else coalesce(t.title, 'Grup') end,
         lm.body, coalesce(lm.created_at, t.created_at),
         (select count(*) from chat_messages cm
           where cm.thread_id = t.id and cm.sender_id <> me and cm.created_at > p.last_read_at)
  from chat_threads t
  join chat_participants p on p.thread_id = t.id and p.member_id = me
  left join lateral (select x.body, x.created_at from chat_messages x where x.thread_id = t.id order by x.created_at desc limit 1) lm on true
  order by 5 desc;
end $$;

create or replace function public.chat_mark_read(p_thread uuid) returns void
language sql security definer set search_path = public as
$$ update chat_participants set last_read_at = now() where thread_id = p_thread and member_id = current_member_id() $$;

grant execute on function public.chat_directory(), public.chat_start_direct(uuid), public.chat_create_group(text, uuid[]),
  public.chat_thread_members(uuid), public.chat_threads_overview(), public.chat_mark_read(uuid) to authenticated;

-- Pesan baru: perbarui thread + notifikasi ke peserta lain (dilewati bila penerima baru saja membuka chat)
create or replace function public.chat_after_message() returns trigger
language plpgsql security definer set search_path = public as $$
declare nm text; ttl text; kind_ text;
begin
  update chat_threads set last_message_at = new.created_at where id = new.thread_id;
  begin
    select coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota') into nm from members m where m.id = new.sender_id;
    select t.kind, t.title into kind_, ttl from chat_threads t where t.id = new.thread_id;
    insert into notifications(member_id, type, title, body, link)
    select p.member_id, 'chat', case when kind_ = 'group' then coalesce(ttl, 'Grup') || ': ' || nm else nm end,
           left(new.body, 120), '/chat/' || new.thread_id::text
    from chat_participants p
    where p.thread_id = new.thread_id and p.member_id <> new.sender_id and p.last_read_at < now() - interval '20 seconds';
  exception when others then null; end;
  return new;
end $$;
drop trigger if exists chat_after_message_trg on public.chat_messages;
create trigger chat_after_message_trg after insert on public.chat_messages
  for each row execute function public.chat_after_message();

do $$ begin
  begin alter publication supabase_realtime add table public.chat_messages; exception when others then raise notice 'chat_messages realtime: %', sqlerrm; end;
end $$;

-- ================= TANDA TANGAN ELEKTRONIK =================
insert into storage.buckets(id, name, public) values ('signatures', 'signatures', false) on conflict (id) do nothing;

drop policy if exists perkapi_sig_insert on storage.objects;
create policy perkapi_sig_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'signatures' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists perkapi_sig_read on storage.objects;
create policy perkapi_sig_read on storage.objects for select to authenticated
  using (bucket_id = 'signatures' and ((storage.foldername(name))[1] = auth.uid()::text
         or public.is_super() or public.has_permission('view_document')));

create table if not exists public.document_signatures(
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  signature_path text not null,
  doc_file_path text not null,
  signed_at timestamptz not null default now(),
  unique (document_id, member_id, doc_file_path));
alter table public.document_signatures enable row level security;
revoke insert, update, delete on public.document_signatures from anon, authenticated;
revoke all on public.document_signatures from anon;

create or replace function public.can_see_document(p_doc uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_super() or public.has_permission('view_document')
      or exists (select 1 from documents d where d.id = p_doc and d.uploaded_by = current_member_id()) $$;
grant execute on function public.can_see_document(uuid) to authenticated;

drop policy if exists ds_select on public.document_signatures;
create policy ds_select on public.document_signatures for select using (public.can_see_document(document_id));

create or replace function public.sign_document(p_document uuid, p_signature_path text) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := current_member_id(); fp text;
begin
  if me is null or not can_see_document(p_document) then raise exception 'forbidden'; end if;
  if p_signature_path is null or split_part(p_signature_path, '/', 1) <> auth.uid()::text then raise exception 'invalid path'; end if;
  select file_path into fp from documents where id = p_document;
  if fp is null then raise exception 'document not found'; end if;
  insert into document_signatures(document_id, member_id, signature_path, doc_file_path)
  values (p_document, me, p_signature_path, fp) on conflict do nothing;
  perform log_event('document_signed', 'documents', p_document::text);
end $$;

create or replace function public.document_signers(p_doc uuid) returns table(
  signer_name text, signed_at timestamptz, signature_path text, is_current boolean, is_mine boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not can_see_document(p_doc) then raise exception 'forbidden'; end if;
  return query
  select coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota'), s.signed_at, s.signature_path,
         (s.doc_file_path = d.file_path), (s.member_id = current_member_id())
  from document_signatures s join members m on m.id = s.member_id join documents d on d.id = s.document_id
  where s.document_id = p_doc order by s.signed_at;
end $$;
grant execute on function public.sign_document(uuid, text), public.document_signers(uuid) to authenticated;

-- ================= INDEKS ISI PDF =================
alter table public.documents add column if not exists content_text text;
alter table public.documents add column if not exists content_indexed_at timestamptz;
