-- 23: Ruang Kerja Perkara: (1) linimasa tahapan + pengingat, (2) daftar tagihan kreditur. Surat dibuat di aplikasi (tanpa tabel).
-- Jalankan setelah 02, 04, 06, 22 (skrip ini memakai ulang fungsi my_alerts dari 22). Aman dijalankan ulang.
-- Akses mengikuti perkara: baca = view_case atau kurator yang ditugaskan; ubah = manage_case.

create table if not exists public.case_stages (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases(id) on delete cascade,
  title text not null,
  due_date date,
  done_at date,
  notes text,
  sort_order int not null default 0,
  created_by uuid,
  created_at timestamptz not null default now()
);
create index if not exists case_stages_case_idx on public.case_stages(case_id, sort_order, due_date);
create index if not exists case_stages_due_idx on public.case_stages(due_date) where done_at is null;

create table if not exists public.case_claims (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases(id) on delete cascade,
  creditor_id uuid references public.creditors(id) on delete set null,
  creditor_name text not null,
  claim_type text not null default 'Konkuren',         -- Separatis | Preferen | Konkuren
  amount numeric(18,2) not null default 0,             -- jumlah tagihan diajukan
  recognized_amount numeric(18,2),                      -- jumlah diakui (bila status Diakui/Bersyarat)
  status text not null default 'Diajukan',              -- Diajukan | Diakui | Bersyarat | Dibantah
  notes text,
  created_by uuid,
  created_at timestamptz not null default now(),
  constraint case_claims_status_chk check (status in ('Diajukan','Diakui','Bersyarat','Dibantah')),
  constraint case_claims_type_chk check (claim_type in ('Separatis','Preferen','Konkuren')),
  constraint case_claims_amount_chk check (amount >= 0 and (recognized_amount is null or recognized_amount >= 0))
);
create index if not exists case_claims_case_idx on public.case_claims(case_id, created_at);

alter table public.case_stages enable row level security;
alter table public.case_claims enable row level security;

drop policy if exists cst_select on public.case_stages;
drop policy if exists cst_write on public.case_stages;
create policy cst_select on public.case_stages for select to authenticated
  using (has_permission('view_case') or exists(select 1 from public.cases c where c.id = case_id and c.assigned_to = current_member_id()));
create policy cst_write on public.case_stages for all to authenticated
  using (has_permission('manage_case')) with check (has_permission('manage_case'));

drop policy if exists ccl_select on public.case_claims;
drop policy if exists ccl_write on public.case_claims;
create policy ccl_select on public.case_claims for select to authenticated
  using (has_permission('view_case') or exists(select 1 from public.cases c where c.id = case_id and c.assigned_to = current_member_id()));
create policy ccl_write on public.case_claims for all to authenticated
  using (has_permission('manage_case')) with check (has_permission('manage_case'));

-- Pagari akun yang belum disetujui admin utama (fungsi is_approved dari skrip 08)
do $$ begin
  execute 'drop policy if exists perkapi_require_approved on public.case_stages';
  execute 'create policy perkapi_require_approved on public.case_stages as restrictive for all to authenticated using ((select public.is_approved()))';
  execute 'drop policy if exists perkapi_require_approved on public.case_claims';
  execute 'create policy perkapi_require_approved on public.case_claims as restrictive for all to authenticated using ((select public.is_approved()))';
exception when others then raise notice 'SKIP require_approved case_*: %', sqlerrm; end $$;

-- my_alerts: skrip 06 + blok AHU (skrip 22) + blok tahapan perkara (skrip 23)
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

  -- Tahapan perkara yang jatuh tempo / terlambat pada perkara yang saya tangani
  select count(*) into n from public.case_stages s join public.cases c on c.id = s.case_id
   where c.assigned_to = me and s.done_at is null and s.due_date < current_date;
  if n > 0 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:stages_overdue','kind','system',
      'title', n || ' tahapan perkara terlambat','body','Buka Perkara, Ruang kerja, Linimasa untuk menyelesaikan atau menjadwalkan ulang.',
      'severity','urgent','created_at', now(),'is_read', false));
  end if;
  select count(*) into n from public.case_stages s join public.cases c on c.id = s.case_id
   where c.assigned_to = me and s.done_at is null and s.due_date between current_date and current_date + 3;
  if n > 0 then
    sys := sys || jsonb_build_array(jsonb_build_object('id','sys:stages_soon','kind','system',
      'title', n || ' tahapan perkara jatuh tempo dalam 3 hari','body','Cek Linimasa pada Ruang kerja perkara.',
      'severity','warning','created_at', now(),'is_read', false));
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
