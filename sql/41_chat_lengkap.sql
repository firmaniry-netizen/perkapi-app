-- 41_chat_lengkap.sql — Chat seperti WhatsApp:
--   lampiran (foto, dokumen, pesan suara), balas/kutip, edit & hapus pesan, centang dibaca,
--   serta sinyal telepon/video call (WebRTC) yang aman lewat RLS.
-- Aman dijalankan ulang (idempotent).

-- ---------- 1) Kolom pesan ----------
alter table public.chat_messages
  add column if not exists kind text not null default 'text',
  add column if not exists attachment_path text,
  add column if not exists attachment_name text,
  add column if not exists attachment_size bigint,
  add column if not exists attachment_mime text,
  add column if not exists duration_ms integer,
  add column if not exists reply_to uuid references public.chat_messages(id) on delete set null,
  add column if not exists edited_at timestamptz,
  add column if not exists deleted_at timestamptz;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'chat_messages_kind_chk') then
    alter table public.chat_messages add constraint chat_messages_kind_chk
      check (kind in ('text', 'image', 'file', 'audio', 'call'));
  end if;
end $$;

-- Teks boleh kosong untuk lampiran (foto tanpa keterangan) dan pesan yang sudah dihapus.
do $$ declare c record; begin
  for c in select conname from pg_constraint
           where conrelid = 'public.chat_messages'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) ilike '%length(body)%' loop
    execute format('alter table public.chat_messages drop constraint %I', c.conname);
  end loop;
end $$;
alter table public.chat_messages add constraint chat_messages_body_len_chk
  check (length(body) <= 4000 and (length(body) >= 1 or kind <> 'text' or deleted_at is not null));

create index if not exists chat_messages_thread_created_idx on public.chat_messages(thread_id, created_at desc);

-- Pengirim boleh mengubah pesannya sendiri (edit teks / tandai terhapus). Kolom lain dikunci oleh trigger.
drop policy if exists cm_update_own on public.chat_messages;
create policy cm_update_own on public.chat_messages for update
  using (sender_id = current_member_id() and chat_is_member(thread_id))
  with check (sender_id = current_member_id() and chat_is_member(thread_id));

create or replace function public.chat_guard_update()
returns trigger language plpgsql as $$
begin
  if new.thread_id <> old.thread_id or new.sender_id <> old.sender_id or new.created_at <> old.created_at
     or new.kind <> old.kind or coalesce(new.reply_to::text, '') <> coalesce(old.reply_to::text, '') then
    raise exception 'Pesan hanya bisa diedit teksnya atau dihapus';
  end if;
  if old.deleted_at is not null then raise exception 'Pesan sudah dihapus'; end if;
  if new.deleted_at is not null then
    -- hapus untuk semua: kosongkan isi & lampiran
    new.body := ''; new.attachment_path := null; new.attachment_name := null;
    new.attachment_size := null; new.attachment_mime := null; new.duration_ms := null;
  elsif new.body is distinct from old.body then
    if old.kind <> 'text' and old.kind <> 'image' and old.kind <> 'file' then raise exception 'Pesan ini tidak bisa diedit'; end if;
    if now() - old.created_at > interval '15 minutes' then raise exception 'Pesan hanya bisa diedit dalam 15 menit'; end if;
    new.edited_at := now();
  end if;
  return new;
end $$;
drop trigger if exists chat_guard_update_trg on public.chat_messages;
create trigger chat_guard_update_trg before update on public.chat_messages
  for each row execute function public.chat_guard_update();

-- ---------- 2) Notifikasi & ringkasan: label untuk lampiran ----------
create or replace function public.chat_preview(p_kind text, p_body text, p_name text, p_deleted timestamptz)
returns text language sql immutable as $$
  select case
    when p_deleted is not null then 'Pesan dihapus'
    when p_kind = 'image' then '📷 Foto' || coalesce(nullif(' · ' || p_body, ' · '), '')
    when p_kind = 'file'  then '📄 ' || coalesce(p_name, 'Dokumen')
    when p_kind = 'audio' then '🎤 Pesan suara'
    when p_kind = 'call'  then coalesce(nullif(p_body, ''), '📞 Panggilan')
    else p_body end
$$;

create or replace function public.chat_after_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare nm text; ttl text; kind_ text;
begin
  update chat_threads set last_message_at = new.created_at where id = new.thread_id;
  begin
    select coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota') into nm from members m where m.id = new.sender_id;
    select t.kind, t.title into kind_, ttl from chat_threads t where t.id = new.thread_id;
    insert into notifications(member_id, type, title, body, link)
    select p.member_id, 'chat', case when kind_ = 'group' then coalesce(ttl, 'Grup') || ': ' || nm else nm end,
           left(chat_preview(new.kind, new.body, new.attachment_name, new.deleted_at), 120), '/chat/' || new.thread_id::text
    from chat_participants p
    where p.thread_id = new.thread_id and p.member_id <> new.sender_id and p.last_read_at < now() - interval '20 seconds';
  exception when others then null; end;
  return new;
end $$;

create or replace function public.chat_threads_overview()
returns table(thread_id uuid, kind text, title text, last_body text, last_at timestamptz, unread bigint)
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
         chat_preview(lm.kind, lm.body, lm.attachment_name, lm.deleted_at), coalesce(lm.created_at, t.created_at),
         (select count(*) from chat_messages cm
           where cm.thread_id = t.id and cm.sender_id <> me and cm.created_at > p.last_read_at)
  from chat_threads t
  join chat_participants p on p.thread_id = t.id and p.member_id = me
  left join lateral (select x.kind, x.body, x.attachment_name, x.deleted_at, x.created_at
                     from chat_messages x where x.thread_id = t.id order by x.created_at desc limit 1) lm on true
  order by 5 desc;
end $$;

-- ---------- 3) Centang dibaca: waktu terakhir dibaca tiap peserta ----------
create or replace function public.chat_read_state(p_thread uuid)
returns table(member_id uuid, last_read_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not chat_is_member(p_thread) then raise exception 'forbidden'; end if;
  return query select p.member_id, p.last_read_at from chat_participants p where p.thread_id = p_thread;
end $$;
revoke all on function public.chat_read_state(uuid) from public, anon;
grant execute on function public.chat_read_state(uuid) to authenticated;

-- realtime: perubahan pesan (edit/hapus) dan status baca ikut terkirim langsung
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'chat_participants') then
    alter publication supabase_realtime add table public.chat_participants;
  end if;
end $$;

-- ---------- 4) Penyimpanan lampiran: bucket privat chat-files/<thread_id>/<member_id>/<berkas> ----------
insert into storage.buckets (id, name, public, file_size_limit)
values ('chat-files', 'chat-files', false, 26214400)   -- 25 MB per berkas
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;

create or replace function public.chat_file_ok(p_name text, p_own boolean)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare parts text[] := storage.foldername(p_name); tid uuid;
begin
  begin tid := parts[1]::uuid; exception when others then return false; end;
  if not chat_is_member(tid) then return false; end if;
  return (not p_own) or parts[2] = current_member_id()::text;
end $$;

drop policy if exists chat_files_read on storage.objects;
create policy chat_files_read on storage.objects for select to authenticated
  using (bucket_id = 'chat-files' and public.chat_file_ok(name, false));
drop policy if exists chat_files_insert on storage.objects;
create policy chat_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'chat-files' and public.chat_file_ok(name, true));
drop policy if exists chat_files_delete on storage.objects;
create policy chat_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'chat-files' and public.chat_file_ok(name, true));

-- ---------- 5) Sinyal panggilan (WebRTC): offer/answer/ice/end hanya untuk penerima yang dituju ----------
create table if not exists public.chat_call_signals (
  id bigint generated always as identity primary key,
  call_id uuid not null,
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  from_member uuid not null references public.members(id) on delete cascade,
  to_member uuid not null references public.members(id) on delete cascade,
  type text not null check (type in ('offer', 'answer', 'ice', 'end', 'decline', 'busy')),
  video boolean not null default false,
  payload jsonb,
  created_at timestamptz not null default now()
);
create index if not exists chat_call_signals_to_idx on public.chat_call_signals(to_member, created_at desc);
alter table public.chat_call_signals enable row level security;

drop policy if exists ccs_select on public.chat_call_signals;
create policy ccs_select on public.chat_call_signals for select
  using (to_member = current_member_id() or from_member = current_member_id());
drop policy if exists ccs_insert on public.chat_call_signals;
create policy ccs_insert on public.chat_call_signals for insert
  with check (from_member = current_member_id() and chat_is_member(thread_id)
              and exists (select 1 from chat_participants p where p.thread_id = chat_call_signals.thread_id and p.member_id = to_member));

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'chat_call_signals') then
    alter publication supabase_realtime add table public.chat_call_signals;
  end if;
end $$;

-- Panggilan masuk juga dikirim sebagai notifikasi (push) agar HP berdering walau aplikasi tertutup.
create or replace function public.chat_call_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare nm text;
begin
  if new.type = 'offer' then
    delete from chat_call_signals where created_at < now() - interval '1 day';   -- tabel sinyal tetap kecil
    select coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota') into nm from members m where m.id = new.from_member;
    insert into notifications(member_id, type, title, body, link)
    values (new.to_member, 'chat', nm, case when new.video then '📹 Panggilan video masuk' else '📞 Panggilan suara masuk' end,
            '/chat/' || new.thread_id::text);
  end if;
  return new;
exception when others then return new;
end $$;
drop trigger if exists chat_call_notify_trg on public.chat_call_signals;
create trigger chat_call_notify_trg after insert on public.chat_call_signals
  for each row execute function public.chat_call_notify();
