-- 16_member_number_auto.sql  (aman dijalankan ulang)
-- Nomor anggota otomatis, format: PRK-TAHUN-NNNN  (contoh PRK-2026-0001), urutan reset tiap tahun.
-- Diberikan saat anggota berstatus 'approved' dan nomornya masih kosong:
--   * anggota baru yang ditambahkan admin (langsung approved)
--   * pendaftar yang disetujui lewat review_registration
-- Nomor yang diisi manual oleh admin tidak diubah. Untuk mengganti awalan, ubah 'PRK' di fungsi di bawah.

create table if not exists public.member_number_counter(
  year integer primary key,
  last_value integer not null default 0);
alter table public.member_number_counter enable row level security;
revoke all on public.member_number_counter from anon, authenticated;

create or replace function public.next_member_number() returns text
language plpgsql security definer set search_path = public as $$
declare y integer := extract(year from (now() at time zone 'Asia/Jakarta'))::int;
        n integer; cand text;
begin
  loop
    insert into member_number_counter(year, last_value) values (y, 1)
    on conflict (year) do update set last_value = member_number_counter.last_value + 1
    returning last_value into n;
    cand := 'PRK-' || y::text || '-' || lpad(n::text, 4, '0');
    exit when not exists (select 1 from members where member_number = cand);
  end loop;
  return cand;
end $$;
revoke all on function public.next_member_number() from public, anon, authenticated;

-- Mulai hitungan dari nomor tertinggi yang sudah ada pada pola yang sama (agar tidak bentrok)
insert into member_number_counter(year, last_value)
select substring(member_number from '^PRK-(\d{4})-\d+$')::int,
       max(substring(member_number from '^PRK-\d{4}-(\d+)$')::int)
from members where member_number ~ '^PRK-\d{4}-\d+$'
group by 1
on conflict (year) do update set last_value = greatest(member_number_counter.last_value, excluded.last_value);

create or replace function public.members_assign_number() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.approval_status = 'approved' and coalesce(trim(new.member_number), '') = '' then
    new.member_number := public.next_member_number();
  end if;
  return new;
end $$;

drop trigger if exists members_assign_number_trg on public.members;
create trigger members_assign_number_trg
  before insert or update of approval_status, member_number on public.members
  for each row execute function public.members_assign_number();

-- OPSIONAL: beri nomor ke anggota lama yang disetujui tapi belum bernomor (urut sesuai tanggal dibuat).
-- Hapus tanda komentar bila ingin menjalankannya.
-- do $$ declare r record; begin
--   for r in select m.id from members m
--            where m.approval_status = 'approved' and coalesce(trim(m.member_number), '') = ''
--            order by (to_jsonb(m)->>'created_at'), m.id
--   loop update members set member_number = public.next_member_number() where id = r.id; end loop;
-- end $$;
