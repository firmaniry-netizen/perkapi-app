-- 43_chat_profil.sql — profil anggota di chat (ketuk nama di chat, seperti WhatsApp).
-- Anggota biasa tidak bisa membaca tabel members (RLS), jadi profil diambil lewat fungsi ini:
-- hanya untuk anggota yang sudah disetujui; nomor HP & email hanya tampil bila keduanya
-- sudah pernah satu percakapan (chat pribadi/grup).
create or replace function public.chat_member_profile(p_member uuid)
returns table(member_id uuid, name text, member_number text, avatar_path text, branch text,
              status text, ahu_verified boolean, ahu_registration_number text, joined_at timestamptz,
              phone text, email text)
language plpgsql stable security definer set search_path = public as $$
declare me uuid := current_member_id(); shared boolean;
begin
  if me is null or not is_approved() then raise exception 'forbidden'; end if;
  select exists (select 1 from chat_participants a join chat_participants b on a.thread_id = b.thread_id
                 where a.member_id = me and b.member_id = p_member) into shared;
  return query
  select m.id, coalesce(m.full_name, 'Anggota'), m.member_number, m.avatar_path, br.name,
         m.status, coalesce(m.ahu_verified, false), m.ahu_registration_number, coalesce(m.approved_at, m.created_at),
         case when shared or p_member = me then m.phone end,
         case when shared or p_member = me then m.email end
  from members m left join branches br on br.id = m.branch_id
  where m.id = p_member and m.approval_status = 'approved';
end $$;
revoke all on function public.chat_member_profile(uuid) from public, anon;
grant execute on function public.chat_member_profile(uuid) to authenticated;
