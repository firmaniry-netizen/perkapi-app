-- TEMPLATE: sesuaikan nama kolom setelah menjalankan 00_check_existing_schema.sql.
-- Asumsi: members.member_number (text), members.email (text).
-- Fungsi ini hanya mengembalikan email untuk login dengan nomor anggota.
-- Ini adalah fungsi baru, bukan tabel baru.
create or replace function public.resolve_login_email(p_member_number text)
returns text
language sql
security definer
set search_path = public
stable
as $$
  select m.email
  from public.members m
  where m.member_number = trim(p_member_number)
  limit 1;
$$;

revoke all on function public.resolve_login_email(text) from public;
grant execute on function public.resolve_login_email(text) to anon, authenticated;

-- Catatan keamanan: fungsi ini memungkinkan orang menebak nomor anggota
-- (enumeration). Tambahkan rate limiting (Edge Function) di STAGE 9.
