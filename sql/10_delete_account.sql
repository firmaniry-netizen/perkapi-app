-- 10: Hapus akun sendiri (syarat Google Play untuk aplikasi yang punya pendaftaran akun).
-- Jalankan setelah 03 dan 06. ADITIF: hanya membuat satu fungsi, tidak mengubah tabel.
--
-- Prinsip: akun login & data pribadi dihapus; baris `members` DIANONIMKAN (bukan dihapus) karena
-- perkara, dokumen, forum, dan log audit merujuk ke members tanpa cascade. Riwayat organisasi tetap utuh
-- tanpa identitas orang tersebut. Seluruh fungsi atomik: bila satu langkah gagal, tidak ada yang berubah.
--
-- Diverifikasi terhadap skema asli: satu-satunya FK ke auth.users adalah members.user_id (tanpa cascade);
-- fungsi ini mengosongkannya sebelum menghapus akun. Bila tetap gagal, pesan galat tampil di aplikasi
-- dan akun tetap utuh (fungsi atomik).

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
declare
  v_uid     uuid := auth.uid();
  v_member  uuid;
  v_supers  int;
  v_is_super boolean;
begin
  if v_uid is null then
    raise exception 'Tidak ada sesi masuk.' using errcode = '28000';
  end if;

  select id into v_member from members where user_id = v_uid limit 1;

  if v_member is not null then
    -- Cegah organisasi kehilangan seluruh admin utama.
    select exists(select 1 from member_roles mr join roles r on r.id = mr.role_id
                  where mr.member_id = v_member and r.code = 'SUPER_ADMIN') into v_is_super;
    if v_is_super then
      select count(distinct mr.member_id) into v_supers
        from member_roles mr join roles r on r.id = mr.role_id where r.code = 'SUPER_ADMIN';
      if v_supers <= 1 then
        raise exception 'Anda satu-satunya admin utama. Alihkan peran admin utama ke anggota lain sebelum menghapus akun.'
          using errcode = 'P0001';
      end if;
    end if;

    -- Data pribadi milik anggota ini. FK di skema ini TANPA cascade, jadi anak dihapus lebih dulu.
    delete from personal_note_shares
     where note_id in (select id from personal_notes where member_id = v_member)
        or shared_with = v_member;
    -- Lampiran catatan (baris saja; berkas di bucket note-attachments tidak dapat dihapus lewat SQL).
    delete from attachments
     where entity_type = 'note'
       and entity_id in (select id from personal_notes where member_id = v_member);
    delete from personal_notes     where member_id = v_member;
    delete from ai_messages
     where conversation_id in (select id from ai_conversations where member_id = v_member);
    delete from ai_conversations   where member_id = v_member;
    delete from notifications      where member_id = v_member;
    delete from member_alert_reads where member_id = v_member;
    delete from forum_likes        where member_id = v_member;
    delete from event_rsvps        where member_id = v_member;
    delete from member_roles       where member_id = v_member;

    -- Koordinat lokasi absensi adalah data pribadi; catatan kehadirannya tetap.
    begin
      update attendance set latitude = null, longitude = null where member_id = v_member;
    exception when others then null; end;

    -- Anonimkan baris anggota. approval_status & kolom persetujuan sengaja TIDAK disentuh
    -- (dijaga trigger members_guard_approval).
    update members
       set full_name   = 'Anggota terhapus',
           email       = 'terhapus-' || id::text || '@invalid.local',
           phone       = null,
           avatar_path = null,
           status      = 'Dihapus',
           qr_token    = gen_random_uuid(),
           user_id     = null
     where id = v_member;
  end if;

  delete from auth.users where id = v_uid;
end $$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
