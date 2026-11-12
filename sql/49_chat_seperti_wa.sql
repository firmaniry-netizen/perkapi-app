-- Fitur chat ala WhatsApp: reaksi emoji, bintangi pesan, sematkan pesan, bisukan/arsipkan/sematkan percakapan,
-- dan privasi "terakhir dilihat". Aman dijalankan ulang. Jalankan di Supabase: SQL Editor.

-- 1. Reaksi emoji: satu reaksi per anggota per pesan (memilih emoji lain = mengganti).
create table if not exists public.chat_reactions (
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (message_id, member_id)
);
create index if not exists chat_reactions_thread_idx on public.chat_reactions(thread_id);
alter table public.chat_reactions enable row level security;
drop policy if exists cr_select on public.chat_reactions;
create policy cr_select on public.chat_reactions for select using (chat_is_member(thread_id));
drop policy if exists cr_insert on public.chat_reactions;
create policy cr_insert on public.chat_reactions for insert with check (
  member_id = current_member_id() and chat_is_member(thread_id)
  and exists (select 1 from chat_messages m where m.id = message_id and m.thread_id = chat_reactions.thread_id and m.deleted_at is null));
drop policy if exists cr_update on public.chat_reactions;
create policy cr_update on public.chat_reactions for update
  using (member_id = current_member_id()) with check (member_id = current_member_id() and chat_is_member(thread_id));
drop policy if exists cr_delete on public.chat_reactions;
create policy cr_delete on public.chat_reactions for delete using (member_id = current_member_id());
drop policy if exists perkapi_require_approved on public.chat_reactions;
create policy perkapi_require_approved on public.chat_reactions as restrictive for all using ((select is_approved()));

-- 2. Bintangi pesan: pribadi, hanya terlihat oleh yang membintangi.
create table if not exists public.chat_stars (
  member_id uuid not null references public.members(id) on delete cascade,
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (member_id, message_id)
);
alter table public.chat_stars enable row level security;
drop policy if exists cs_own on public.chat_stars;
create policy cs_own on public.chat_stars for all
  using (member_id = current_member_id())
  with check (member_id = current_member_id() and chat_is_member(thread_id));
drop policy if exists perkapi_require_approved on public.chat_stars;
create policy perkapi_require_approved on public.chat_stars as restrictive for all using ((select is_approved()));

-- 3. Sematkan pesan: satu pesan tersemat per percakapan, terlihat semua peserta.
alter table public.chat_threads add column if not exists pinned_message_id uuid references public.chat_messages(id) on delete set null;
create or replace function public.chat_pin_message(p_thread uuid, p_message uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not chat_is_member(p_thread) then raise exception 'Bukan peserta percakapan'; end if;
  if p_message is not null and not exists (select 1 from chat_messages where id = p_message and thread_id = p_thread and deleted_at is null) then
    raise exception 'Pesan tidak ditemukan';
  end if;
  update chat_threads set pinned_message_id = p_message where id = p_thread;
end $$;

-- 4. Pengaturan percakapan per anggota: bisukan, arsipkan, sematkan di daftar chat.
alter table public.chat_participants add column if not exists muted_until timestamptz;
alter table public.chat_participants add column if not exists archived boolean not null default false;
alter table public.chat_participants add column if not exists pinned boolean not null default false;
create or replace function public.chat_set_thread_prefs(
  p_thread uuid, p_archived boolean default null, p_pinned boolean default null,
  p_set_mute boolean default false, p_muted_until timestamptz default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  update chat_participants set
    archived = coalesce(p_archived, archived),
    pinned = coalesce(p_pinned, pinned),
    muted_until = case when p_set_mute then p_muted_until else muted_until end
  where thread_id = p_thread and member_id = current_member_id();
end $$;

-- Daftar chat ikut mengembalikan status bisu/arsip/sematan; yang disematkan tampil paling atas.
drop function if exists public.chat_threads_overview();
create function public.chat_threads_overview()
returns table(thread_id uuid, kind text, title text, last_body text, last_at timestamptz, unread bigint,
              muted_until timestamptz, archived boolean, pinned boolean)
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
           where cm.thread_id = t.id and cm.sender_id <> me and cm.created_at > p.last_read_at),
         p.muted_until, p.archived, p.pinned
  from chat_threads t
  join chat_participants p on p.thread_id = t.id and p.member_id = me
  left join lateral (select x.kind, x.body, x.attachment_name, x.deleted_at, x.created_at
                     from chat_messages x where x.thread_id = t.id order by x.created_at desc limit 1) lm on true
  order by p.pinned desc, 5 desc;
end $$;

-- Percakapan yang dibisukan tidak membuat notifikasi (dan push) baru.
create or replace function public.chat_after_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare nm text; ttl text; kind_ text;
begin
  update chat_threads set last_message_at = new.created_at where id = new.thread_id;
  -- Pesan baru mengeluarkan percakapan dari arsip, seperti WhatsApp.
  update chat_participants set archived = false where thread_id = new.thread_id and archived and member_id <> new.sender_id;
  begin
    select coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota') into nm from members m where m.id = new.sender_id;
    select t.kind, t.title into kind_, ttl from chat_threads t where t.id = new.thread_id;
    insert into notifications(member_id, type, title, body, link)
    select p.member_id, 'chat', case when kind_ = 'group' then coalesce(ttl, 'Grup') || ': ' || nm else nm end,
           left(chat_preview(new.kind, new.body, new.attachment_name, new.deleted_at), 120), '/chat/' || new.thread_id::text
    from chat_participants p
    where p.thread_id = new.thread_id and p.member_id <> new.sender_id and p.last_read_at < now() - interval '20 seconds'
      and (p.muted_until is null or p.muted_until < now());
  exception when others then null; end;
  return new;
end $$;

-- 5. Privasi "terakhir dilihat": bila disembunyikan, orang lain tidak melihat waktu Anda,
-- dan Anda juga tidak melihat waktu orang lain (aturan yang sama dengan WhatsApp).
alter table public.members add column if not exists hide_last_seen boolean not null default false;
create or replace function public.member_last_seen(p_member uuid)
returns timestamptz language sql stable security definer set search_path = public as $$
  select m.last_seen_at
  from members m
  where m.id = p_member
    and not m.hide_last_seen
    and not coalesce((select me.hide_last_seen from members me where me.id = current_member_id()), false)
    and exists (
      select 1 from chat_participants a join chat_participants b on b.thread_id = a.thread_id
      where a.member_id = current_member_id() and b.member_id = p_member);
$$;
create or replace function public.chat_privacy()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select hide_last_seen from members where id = current_member_id()), false);
$$;
create or replace function public.chat_set_hide_last_seen(p_hide boolean)
returns void language sql security definer set search_path = public as $$
  update members set hide_last_seen = p_hide where id = current_member_id();
$$;

-- Hak akses fungsi: hanya pengguna yang masuk.
do $$
declare f text;
begin
  foreach f in array array[
    'public.chat_pin_message(uuid, uuid)',
    'public.chat_set_thread_prefs(uuid, boolean, boolean, boolean, timestamptz)',
    'public.chat_threads_overview()',
    'public.member_last_seen(uuid)',
    'public.chat_privacy()',
    'public.chat_set_hide_last_seen(boolean)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

-- Reaksi tampil langsung di HP lawan bicara (Realtime).
do $$ begin
  alter publication supabase_realtime add table public.chat_reactions;
exception when duplicate_object then null; end $$;

-- 6. Label "Diteruskan" pada pesan yang diteruskan dari percakapan lain.
alter table public.chat_messages add column if not exists forwarded boolean not null default false;

-- 7. Pesan tersemat berganti langsung di HP semua peserta (Realtime pada chat_threads).
do $$ begin
  alter publication supabase_realtime add table public.chat_threads;
exception when duplicate_object then null; end $$;
