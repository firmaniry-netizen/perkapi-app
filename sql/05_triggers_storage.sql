-- updated_at otomatis (hanya jika kolom ada), nomor tiket, audit trigger, bucket storage privat.
create or replace function set_updated_at() returns trigger language plpgsql as
$$ begin new.updated_at = now(); return new; end $$;

do $$ declare t text; begin
  foreach t in array array['members','personal_notes','cases','debtors','creditors','documents','complaints','announcements','events','forum_posts','tasks','pocket_book_contents'] loop
    begin
      execute format('alter table public.%I add column if not exists updated_at timestamptz default now()', t);
      execute format('drop trigger if exists trg_updated_at on public.%I', t);
      execute format('create trigger trg_updated_at before update on public.%I for each row execute function set_updated_at()', t);
    exception when others then raise notice 'skip updated_at %: %', t, sqlerrm; end;
  end loop; end $$;

create or replace function set_ticket_number() returns trigger language plpgsql as
$$ begin
  if new.ticket_number is null then
    new.ticket_number := 'PKP-' || to_char(now(),'YYYYMM') || '-' || lpad(nextval('complaint_ticket_seq')::text, 5, '0');
  end if; return new; end $$;
drop trigger if exists trg_ticket on complaints;
create trigger trg_ticket before insert on complaints for each row execute function set_ticket_number();

create or replace function audit_row() returns trigger language plpgsql security definer set search_path = public as
$$ begin
  insert into audit_logs(member_id, action, module, record_id, metadata)
  values (current_member_id(), lower(tg_op), tg_table_name,
          coalesce((case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end)->>'id',''), '{}'::jsonb);
  return coalesce(new, old);
exception when others then return coalesce(new, old); end $$;

do $$ declare t text; begin
  foreach t in array array['members','member_roles','role_permissions','cases','debtors','creditors','documents','complaints','announcements','events','forum_posts','tasks'] loop
    begin
      execute format('drop trigger if exists trg_audit on public.%I', t);
      execute format('create trigger trg_audit after insert or update or delete on public.%I for each row execute function audit_row()', t);
    exception when others then raise notice 'skip audit %: %', t, sqlerrm; end;
  end loop; end $$;

-- Bucket PRIVAT (public = false). Path file: <member_id atau auth.uid()>/<nama>
insert into storage.buckets(id, name, public) values
 ('avatars','avatars',false),('documents','documents',false),('complaint-attachments','complaint-attachments',false),
 ('case-documents','case-documents',false),('note-attachments','note-attachments',false),('event-attachments','event-attachments',false)
on conflict (id) do update set public = false;

drop policy if exists perkapi_storage_read on storage.objects;
drop policy if exists perkapi_storage_write on storage.objects;
drop policy if exists perkapi_storage_update on storage.objects;
drop policy if exists perkapi_storage_delete on storage.objects;

create policy perkapi_storage_read on storage.objects for select to authenticated using (
  (bucket_id in ('avatars','event-attachments'))
  or (bucket_id in ('note-attachments') and (storage.foldername(name))[1] = auth.uid()::text)
  or (bucket_id = 'complaint-attachments' and ((storage.foldername(name))[1] = auth.uid()::text or has_permission('manage_complaint')))
  or (bucket_id in ('documents','case-documents') and (has_permission('view_document') or (storage.foldername(name))[1] = auth.uid()::text)));

create policy perkapi_storage_write on storage.objects for insert to authenticated with check (
  ((storage.foldername(name))[1] = auth.uid()::text and bucket_id in ('avatars','note-attachments','complaint-attachments'))
  or (bucket_id in ('documents','case-documents') and has_permission('manage_document'))
  or (bucket_id = 'event-attachments' and has_permission('manage_event')));

create policy perkapi_storage_update on storage.objects for update to authenticated using (
  (storage.foldername(name))[1] = auth.uid()::text and bucket_id in ('avatars','note-attachments'));

create policy perkapi_storage_delete on storage.objects for delete to authenticated using (
  ((storage.foldername(name))[1] = auth.uid()::text and bucket_id in ('avatars','note-attachments','complaint-attachments'))
  or (bucket_id in ('documents','case-documents') and has_permission('manage_document'))
  or (bucket_id = 'event-attachments' and has_permission('manage_event')));
