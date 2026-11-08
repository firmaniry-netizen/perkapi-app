-- 46: status pesan ala WhatsApp (terkirim ✓, sampai ✓✓, dibaca ✓✓ biru) + log hasil kirim push.

-- 1) Kapan pesan terakhir SAMPAI di HP peserta (aplikasi menerima pesan, walau chat belum dibuka)
alter table public.chat_participants add column if not exists last_delivered_at timestamptz;

-- Tandai semua percakapan saya sebagai "sudah sampai" (dipanggil saat aplikasi aktif / menerima pesan)
create or replace function public.chat_mark_delivered()
returns void language sql security definer set search_path = public as $$
  update chat_participants set last_delivered_at = now()
  where member_id = current_member_id()
    and (last_delivered_at is null or last_delivered_at < now() - interval '2 seconds');
$$;
revoke all on function public.chat_mark_delivered() from public, anon;
grant execute on function public.chat_mark_delivered() to authenticated;

-- Membaca berarti juga sudah sampai
create or replace function public.chat_mark_read(p_thread uuid)
returns void language sql security definer set search_path = public as $$
  update chat_participants set last_read_at = now(), last_delivered_at = now()
  where thread_id = p_thread and member_id = current_member_id()
$$;

-- Status baca & sampai tiap peserta (tipe kembalian berubah, jadi drop dulu)
drop function if exists public.chat_read_state(uuid);
create function public.chat_read_state(p_thread uuid)
returns table(member_id uuid, last_read_at timestamptz, last_delivered_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not chat_is_member(p_thread) then raise exception 'forbidden'; end if;
  return query select p.member_id, p.last_read_at, p.last_delivered_at from chat_participants p where p.thread_id = p_thread;
end $$;
revoke all on function public.chat_read_state(uuid) from public, anon;
grant execute on function public.chat_read_state(uuid) to authenticated;

-- 2) Log hasil kirim FCM (diagnosis notifikasi). Hanya service role yang bisa membaca/menulis.
create table if not exists public.push_log (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  member_id uuid,
  platform text,
  kind text,
  status int,
  detail text
);
alter table public.push_log enable row level security;
