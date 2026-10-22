-- 15_fix_personal_notes_recursion.sql
-- Memutus rekursi tak berujung (kode 42P17) antara policy personal_notes dan personal_note_shares.
create or replace function public.note_is_mine(p_note uuid) returns boolean
language sql stable security definer set search_path = public as
$$ select exists(select 1 from personal_notes n where n.id = p_note and n.member_id = current_member_id()) $$;

create or replace function public.note_shared_with_me(p_note uuid) returns boolean
language sql stable security definer set search_path = public as
$$ select exists(select 1 from personal_note_shares s where s.note_id = p_note and s.shared_with = current_member_id()) $$;

grant execute on function public.note_is_mine(uuid), public.note_shared_with_me(uuid) to authenticated;

drop policy if exists pn_select on public.personal_notes;
create policy pn_select on public.personal_notes for select
  using (member_id = current_member_id() or public.note_shared_with_me(id));

drop policy if exists pns_owner on public.personal_note_shares;
create policy pns_owner on public.personal_note_shares for all
  using (public.note_is_mine(note_id)) with check (public.note_is_mine(note_id));
