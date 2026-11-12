-- "Terakhir dilihat" di chat, seperti WhatsApp.
-- Aplikasi mencatat waktu terakhir anggota membuka aplikasi (touch_last_seen), dan halaman chat membacanya
-- lewat member_last_seen. Waktu hanya bisa dibaca oleh anggota yang punya percakapan bersama orang itu.
-- Aman dijalankan ulang. Jalankan di Supabase: SQL Editor.

alter table public.members add column if not exists last_seen_at timestamptz;

create or replace function public.touch_last_seen()
returns void
language sql
security definer
set search_path = public
as $$
  update members set last_seen_at = now() where id = current_member_id();
$$;

create or replace function public.member_last_seen(p_member uuid)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select m.last_seen_at
  from members m
  where m.id = p_member
    and exists (
      select 1
      from chat_participants a
      join chat_participants b on b.thread_id = a.thread_id
      where a.member_id = current_member_id() and b.member_id = p_member
    );
$$;

revoke all on function public.touch_last_seen() from public;
revoke all on function public.member_last_seen(uuid) from public;
grant execute on function public.touch_last_seen() to authenticated;
grant execute on function public.member_last_seen(uuid) to authenticated;
