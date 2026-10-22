-- 22: Data pendaftaran AHU (Kurator dan Pengurus) per anggota.
-- Jalankan setelah 03, 06, 08, 09. Aman dijalankan ulang.
--
-- Anggota mengisi nomor Surat Bukti Pendaftaran Kurator dan Pengurus (mis. AHU-123.AH.04.03-2021), tanggal terbit,
-- dan masa berlaku (opsional). Lencana "Terverifikasi AHU" HANYA bisa diberikan oleh pengelola anggota (manage_member)
-- atau admin utama, setelah mencocokkan dengan dokumen/situs AHU. Bila anggota mengubah data AHU-nya sendiri,
-- status verifikasi otomatis dicabut sampai diverifikasi ulang. Ditegakkan di database, bukan hanya di aplikasi.

alter table public.members add column if not exists ahu_registration_number text;
alter table public.members add column if not exists ahu_registration_date date;
alter table public.members add column if not exists ahu_valid_until date;
alter table public.members add column if not exists ahu_verified boolean not null default false;
alter table public.members add column if not exists ahu_verified_at timestamptz;
alter table public.members add column if not exists ahu_verified_by uuid;

create or replace function public.members_guard_ahu() returns trigger
language plpgsql as $$
declare priv boolean := (auth.uid() is null) or public.is_super() or public.has_permission('manage_member');
begin
  if tg_op = 'INSERT' then
    if not priv then
      new.ahu_verified := false; new.ahu_verified_at := null; new.ahu_verified_by := null;
    end if;
    return new;
  end if;

  if new.ahu_verified is distinct from old.ahu_verified
     or new.ahu_verified_at is distinct from old.ahu_verified_at
     or new.ahu_verified_by is distinct from old.ahu_verified_by then
    if not priv then
      raise exception 'Hanya pengelola anggota yang dapat memverifikasi pendaftaran AHU.' using errcode = '42501';
    end if;
  elsif new.ahu_registration_number is distinct from old.ahu_registration_number
     or new.ahu_registration_date   is distinct from old.ahu_registration_date
     or new.ahu_valid_until         is distinct from old.ahu_valid_until then
    -- data berubah tanpa verifikasi ulang: cabut verifikasi
    new.ahu_verified := false; new.ahu_verified_at := null; new.ahu_verified_by := null;
  end if;

  if new.ahu_verified and not coalesce(old.ahu_verified, false) then
    new.ahu_verified_at := now();
    new.ahu_verified_by := public.current_member_id();
  elsif not new.ahu_verified then
    new.ahu_verified_at := null; new.ahu_verified_by := null;
  end if;

  -- nomor dikosongkan = verifikasi tidak berlaku
  if nullif(btrim(coalesce(new.ahu_registration_number,'')),'') is null then
    new.ahu_registration_number := null;
    new.ahu_verified := false; new.ahu_verified_at := null; new.ahu_verified_by := null;
  end if;
  return new;
end $$;

drop trigger if exists trg_members_guard_ahu on public.members;
create trigger trg_members_guard_ahu before insert or update on public.members
  for each row execute function public.members_guard_ahu();

-- Verifikasi QR ikut menampilkan data AHU (untuk pengelola anggota).
create or replace function verify_member_qr(p_token uuid) returns jsonb
language sql stable security definer set search_path = public as
$$ select case when has_permission('manage_member') then
     (select jsonb_build_object('full_name', full_name, 'member_number', member_number, 'status', status,
                                'valid_until', valid_until, 'avatar_path', avatar_path,
                                'ahu_registration_number', ahu_registration_number,
                                'ahu_valid_until', ahu_valid_until,
                                'ahu_verified', ahu_verified)
      from members where qr_token = p_token) else null end $$;
grant execute on function verify_member_qr(uuid) to authenticated;

-- Peringatan otomatis masa berlaku AHU (ikut fungsi my_alerts dari skrip 06, ditambah blok AHU)
create or replace function public.my_alerts() returns jsonb
language plpgsql stable security definer set search_path = public as
$$
declare
  me   uuid := public.current_member_id();
  m    public.members;
  manual jsonb;
  sys    jsonb := '[]'::jsonb;
  n    int;
begin
  if me is null then return '[]'::jsonb; end if;
  select * into m from public.members where id = me;

  -- 1) peringatan manual yang ditujukan ke saya
  select coalesce(jsonb_agg(x order by (x->>'created_at') desc), '[]'::jsonb) into manual
  from (
    select jsonb_build_object(
             'id', a.id::text, 'kind', 'manual', 'title', a.title, 'body', a.body,
             'severity', a.severity, 'created_at', a.created_at,
             'is_read', exists(select 1 from public.member_alert_reads r
                               where r.alert_id = a.id and r.member_id = me)) as x
    from public.member_alerts a
    where a.is_active and a.starts_at <= now()
      and (a.expires_at is null or a.expires_at > now())
      and (   a.target_type = 'all'
           or (a.target_type = 'branch' and a.target_id = m.branch_id)
           or (a.target_type = 'member' and a.target_id = me)
           or (a.target_type = 'role' and exists(
                 select 1 from public.member_roles mr
                 where mr.member_id = me and mr.role_id = a.target_id)))
  ) s;

  -- 2) peringatan otomatis (dihitung saat dibaca, tidak disimpan)
  if m.valid_until is not null and m.valid_until < current_date then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:membership','kind','system',
      'title','Keanggotaan Anda sudah berakhir',
      'body','Masa berlaku berakhir pada ' || to_char(m.valid_until,'DD-MM-YYYY') || '. Hubungi pengurus untuk perpanjangan.',
      'severity','urgent','created_at', now(),'is_read', false));
  elsif m.valid_until is not null and m.valid_until <= current_date + 30 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:membership','kind','system',
      'title','Keanggotaan segera berakhir',
      'body','Masa berlaku berakhir pada ' || to_char(m.valid_until,'DD-MM-YYYY') || ' (' || (m.valid_until - current_date) || ' hari lagi).',
      'severity','warning','created_at', now(),'is_read', false));
  end if;

  -- AHU: pendaftaran kurator/pengurus akan / sudah berakhir (hanya bila anggota mengisi masa berlaku)
  if m.ahu_registration_number is not null and m.ahu_valid_until is not null then
    if m.ahu_valid_until < current_date then
      sys := sys || jsonb_build_array(jsonb_build_object('id','sys:ahu','kind','system',
        'title','Pendaftaran AHU Anda sudah berakhir',
        'body','Masa berlaku pendaftaran kurator/pengurus berakhir pada ' || to_char(m.ahu_valid_until,'DD-MM-YYYY') || '. Segera perpanjang di AHU Online lalu perbarui datanya di aplikasi.',
        'severity','urgent','created_at', now(),'is_read', false));
    elsif m.ahu_valid_until <= current_date + 60 then
      sys := sys || jsonb_build_array(jsonb_build_object('id','sys:ahu','kind','system',
        'title','Pendaftaran AHU segera berakhir',
        'body','Berakhir pada ' || to_char(m.ahu_valid_until,'DD-MM-YYYY') || ' (' || (m.ahu_valid_until - current_date) || ' hari lagi). Siapkan perpanjangan di AHU Online.',
        'severity','warning','created_at', now(),'is_read', false));
    end if;
  end if;

  if coalesce(m.status,'Aktif') <> 'Aktif' then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:status','kind','system',
      'title','Status keanggotaan: ' || m.status,
      'body','Beberapa layanan mungkin dibatasi. Hubungi pengurus bila ada kekeliruan.',
      'severity','warning','created_at', now(),'is_read', false));
  end if;

  select count(*) into n from public.tasks
   where assigned_to = me and due_date < current_date and status <> 'Done';
  if n > 0 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:tasks_overdue','kind','system',
      'title', n || ' tugas melewati deadline','body','Buka menu Tugas untuk menyelesaikannya.',
      'severity','urgent','created_at', now(),'is_read', false));
  end if;

  select count(*) into n from public.tasks
   where assigned_to = me and status <> 'Done'
     and due_date between current_date and current_date + 2;
  if n > 0 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:tasks_soon','kind','system',
      'title', n || ' tugas jatuh tempo dalam 2 hari','body','Segera selesaikan agar tidak terlambat.',
      'severity','warning','created_at', now(),'is_read', false));
  end if;

  select count(*) into n from public.personal_notes
   where member_id = me and not is_archived and reminder_at is not null
     and reminder_at <= now() and reminder_at > now() - interval '7 days';
  if n > 0 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:note_reminder','kind','system',
      'title', n || ' pengingat catatan','body','Ada catatan Buku Saku yang waktunya telah tiba.',
      'severity','info','created_at', now(),'is_read', false));
  end if;

  select count(*) into n from public.events
   where starts_at between now() and now() + interval '24 hours';
  if n > 0 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:events_soon','kind','system',
      'title', n || ' agenda dalam 24 jam ke depan','body','Cek menu Event dan jangan lupa check-in.',
      'severity','info','created_at', now(),'is_read', false));
  end if;

  select count(*) into n from public.complaints where member_id = me and status = 'Menunggu';
  if n > 0 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:complaints_wait','kind','system',
      'title', n || ' pengaduan menunggu tanggapan Anda','body','Buka menu Pengaduan untuk membalas.',
      'severity','warning','created_at', now(),'is_read', false));
  end if;

  return sys || manual;
end $$;
