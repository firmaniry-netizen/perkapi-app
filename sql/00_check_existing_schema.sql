-- Jalankan di Supabase SQL Editor (READ ONLY). Hanya memeriksa, tidak mengubah.
-- 1) Tabel yang ada di schema public
select table_name
from information_schema.tables
where table_schema = 'public'
order by table_name;

-- 2) Kolom tabel members (untuk menyesuaikan sql/01)
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'members'
order by ordinal_position;

-- 3) Status RLS per tabel
select relname as table_name, relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by relname;

-- 4) Policy yang sudah ada
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
order by tablename, policyname;
