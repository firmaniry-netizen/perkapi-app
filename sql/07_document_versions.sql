-- =====================================================================
-- PERKAPI - VERSI DOKUMEN (jalankan setelah perkapi_complete.sql)
-- Aman dijalankan ulang.
-- Cara kerja: saat file_path sebuah dokumen diganti (upload versi baru),
-- trigger menyimpan versi lama ke document_versions dan menaikkan nomor versi.
-- =====================================================================
create table if not exists public.document_versions (
  id          uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  version     int  not null,
  bucket      text not null default 'documents',
  file_path   text not null,
  file_name   text,
  mime_type   text,
  size_bytes  bigint,
  uploaded_by uuid references public.members(id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists idx_doc_versions_doc on public.document_versions(document_id, version desc);

alter table public.document_versions enable row level security;
revoke all on public.document_versions from anon;

-- Hanya baca (mengikuti akses ke dokumen induknya). Penulisan hanya lewat trigger.
drop policy if exists dv_select on public.document_versions;
create policy dv_select on public.document_versions for select to authenticated
  using (exists(select 1 from public.documents d where d.id = document_id));

create or replace function public.snapshot_document_version() returns trigger
language plpgsql security definer set search_path = public as
$$ begin
  if new.file_path is distinct from old.file_path then
    insert into public.document_versions
      (document_id, version, bucket, file_path, file_name, mime_type, size_bytes, uploaded_by, created_at)
    values
      (old.id, coalesce(old.version, 1), old.bucket, old.file_path, old.title,
       old.mime_type, old.size_bytes, old.uploaded_by, coalesce(old.updated_at, old.created_at));
    new.version := coalesce(old.version, 1) + 1;
  end if;
  return new;
end $$;

drop trigger if exists trg_doc_version on public.documents;
create trigger trg_doc_version before update on public.documents
  for each row execute function public.snapshot_document_version();
