-- 13_push_tokens.sql (setelah 03, 04, 08; aman dijalankan ulang)
-- Menyimpan token perangkat untuk notifikasi push (FCM). Klien tidak bisa menulis langsung.
create table if not exists public.device_tokens(
  token text primary key,
  member_id uuid not null references public.members(id) on delete cascade,
  platform text not null default 'android',
  updated_at timestamptz not null default now());
create index if not exists device_tokens_member_idx on public.device_tokens(member_id);

alter table public.device_tokens enable row level security;
drop policy if exists dt_select on public.device_tokens;
create policy dt_select on public.device_tokens for select using (member_id = public.current_member_id());
revoke insert, update, delete on public.device_tokens from anon, authenticated;
revoke all on public.device_tokens from anon;

do $$ begin
  execute 'drop policy if exists perkapi_require_approved on public.device_tokens';
  execute 'create policy perkapi_require_approved on public.device_tokens as restrictive for all to authenticated using ((select public.is_approved()))';
exception when others then raise notice 'SKIP require_approved device_tokens: %', sqlerrm; end $$;

-- Satu token hanya milik satu anggota: login ganti akun di HP yang sama memindahkan token.
create or replace function public.register_device_token(p_token text, p_platform text default 'android') returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := current_member_id();
begin
  if me is null or p_token is null or length(p_token) < 20 or length(p_token) > 4096 then return; end if;
  insert into device_tokens(token, member_id, platform, updated_at) values (p_token, me, left(p_platform, 20), now())
  on conflict (token) do update set member_id = me, platform = left(p_platform, 20), updated_at = now();
end $$;

create or replace function public.unregister_device_token(p_token text) returns void
language sql security definer set search_path = public as
$$ delete from device_tokens where token = p_token and member_id = current_member_id() $$;

grant execute on function public.register_device_token(text, text), public.unregister_device_token(text) to authenticated;
