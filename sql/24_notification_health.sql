-- 24_notification_health.sql  (jalankan SETELAH 13 dan 14; aman dijalankan ulang)
-- 1) Pengingat berbasis TANGGAL hanya dikirim pukul 07.00-19.59 WIB (sebelumnya terkirim ~00:00 saat hari berganti).
--    Pengingat berbasis JAM (event 24 jam / 1 jam sebelum mulai) tetap sesuai waktunya.
-- 2) reminder_health(): dipakai halaman "Notifikasi & Pengingat" untuk memeriksa pg_cron dan perangkat terdaftar.
-- 3) send_test_notification(): kirim satu notifikasi uji ke akun yang sedang login (maks. 1 per 30 detik).

create or replace function public.run_reminders() returns void
language plpgsql security definer set search_path = public as $$
declare
  today date := (now() at time zone 'Asia/Jakarta')::date;
  daytime boolean := extract(hour from (now() at time zone 'Asia/Jakarta'))::int between 7 and 19;
begin
  -- Event: 24 jam dan 1 jam sebelum mulai, untuk anggota yang RSVP selain "Tidak"
  with cand as (
    select 'event'::text kind, e.id ref_id, r.member_id,
           case when e.starts_at <= now() + interval '1 hour' then 'h1' else 'h24' end bucket,
           e.title, e.starts_at
    from events e join event_rsvps r on r.event_id = e.id and r.status <> 'Tidak'
    where e.starts_at > now() and e.starts_at <= now() + interval '24 hours'),
  ins as (
    insert into reminder_log(kind, ref_id, member_id, bucket)
    select kind, ref_id, member_id, bucket from cand on conflict do nothing
    returning kind, ref_id, member_id, bucket)
  insert into notifications(member_id, type, title, body, link)
  select c.member_id, 'info',
         case when c.bucket = 'h1' then 'Event segera dimulai' else 'Event besok' end,
         c.title || ' · ' || to_char(c.starts_at at time zone 'Asia/Jakarta', 'DD Mon HH24:MI') || ' WIB', '/calendar'
  from ins join cand c using (kind, ref_id, member_id, bucket);

  if daytime then
    -- Tugas: jatuh tempo hari ini / besok, belum Done
    with cand as (
      select 'task'::text kind, t.id ref_id, t.assigned_to member_id,
             case when t.due_date <= today then 'd0' else 'd1' end bucket, t.title, t.due_date
      from tasks t
      where t.assigned_to is not null and coalesce(t.status, '') <> 'Done' and t.due_date between today and today + 1),
    ins as (
      insert into reminder_log(kind, ref_id, member_id, bucket)
      select kind, ref_id, member_id, bucket from cand on conflict do nothing
      returning kind, ref_id, member_id, bucket)
    insert into notifications(member_id, type, title, body, link)
    select c.member_id, 'warning',
           case when c.bucket = 'd0' then 'Tugas jatuh tempo hari ini' else 'Tugas jatuh tempo besok' end, c.title, '/tasks'
    from ins join cand c using (kind, ref_id, member_id, bucket);

    -- Perkara: deadline (3 hari dan 1 hari) dan tanggal perkara (1 hari), untuk yang ditugaskan
    with cand as (
      select 'case_deadline'::text kind, c.id ref_id, c.assigned_to member_id,
             case when c.deadline <= today + 1 then 'd1' else 'd3' end bucket, c.title, c.deadline dt
      from cases c where c.assigned_to is not null and c.deadline between today and today + 3
      union all
      select 'case_date', c.id, c.assigned_to, 'd1', c.title, c.case_date
      from cases c where c.assigned_to is not null and c.case_date between today and today + 1),
    ins as (
      insert into reminder_log(kind, ref_id, member_id, bucket)
      select kind, ref_id, member_id, bucket from cand on conflict do nothing
      returning kind, ref_id, member_id, bucket)
    insert into notifications(member_id, type, title, body, link)
    select c.member_id, 'warning',
           case when c.kind = 'case_date' then 'Tanggal perkara mendekat' else 'Deadline perkara mendekat' end,
           c.title || ' · ' || to_char(c.dt, 'DD Mon YYYY'), '/cases'
    from ins join cand c using (kind, ref_id, member_id, bucket);
  end if;

  delete from reminder_log where created_at < now() - interval '60 days';
end $$;
revoke all on function public.run_reminders() from public, anon, authenticated;

create or replace function public.reminder_health() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := current_member_id();
  scheduled boolean := false;
  last_run timestamptz := null;
  devices int := 0;
begin
  select count(*) into devices from device_tokens where member_id = me;
  begin
    execute 'select exists(select 1 from cron.job where jobname = ''perkapi-reminders'' and active)' into scheduled;
  exception when others then scheduled := false;
  end;
  begin
    execute 'select max(d.start_time) from cron.job_run_details d join cron.job j on j.jobid = d.jobid where j.jobname = ''perkapi-reminders''' into last_run;
  exception when others then last_run := null;
  end;
  return jsonb_build_object('cron_scheduled', scheduled, 'last_run', last_run, 'my_devices', devices);
end $$;
grant execute on function public.reminder_health() to authenticated;

create or replace function public.send_test_notification() returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := current_member_id();
begin
  if me is null then raise exception 'Akun Anda belum terhubung ke data anggota.'; end if;
  if exists (select 1 from notifications where member_id = me and title = 'Tes notifikasi PERKAPI'
             and created_at > now() - interval '30 seconds') then
    raise exception 'Tunggu 30 detik sebelum mengirim notifikasi uji lagi.';
  end if;
  insert into notifications(member_id, type, title, body, link)
  values (me, 'info', 'Tes notifikasi PERKAPI', 'Jika Anda menerima ini saat aplikasi tertutup, push sudah berfungsi.', '/notification-status');
end $$;
grant execute on function public.send_test_notification() to authenticated;
