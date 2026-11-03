-- 44_panggilan_push.sql
-- Panggilan masuk berdering walau aplikasi tertutup.
--  * notifications.data (jsonb): data tambahan untuk push (id panggilan, nama penelepon, video/suara).
--  * offer   → notifikasi bertipe 'call'        → send-push mengirim pesan data berprioritas tinggi
--              (Android: layar dering bawaan; iPhone: notifikasi berbunyi).
--  * end tanpa pernah dijawab (penelepon membatalkan / 45 detik habis)
--            → notifikasi 'call_missed' "Panggilan tak terjawab" + menutup layar dering di HP penerima.
-- Aman dijalankan ulang.

alter table public.notifications add column if not exists data jsonb;

create or replace function public.chat_call_notify()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare nm text;
begin
  if new.type = 'offer' then
    delete from chat_call_signals where created_at < now() - interval '1 day';
    select coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota') into nm from members m where m.id = new.from_member;
    insert into notifications(member_id, type, title, body, link, data)
    values (new.to_member, 'call', nm,
            case when new.video then '📹 Panggilan video masuk' else '📞 Panggilan suara masuk' end,
            '/chat/' || new.thread_id::text,
            jsonb_build_object('call_id', new.call_id::text, 'thread_id', new.thread_id::text, 'caller', nm,
                               'video', case when new.video then '1' else '0' end));
  elsif new.type = 'end'
    and exists (select 1 from chat_call_signals s where s.call_id = new.call_id and s.type = 'offer' and s.from_member = new.from_member)
    and not exists (select 1 from chat_call_signals s where s.call_id = new.call_id and s.type in ('answer', 'decline', 'busy')) then
    -- penelepon menutup sebelum diangkat → tak terjawab bagi penerima
    select coalesce(to_jsonb(m)->>'full_name', to_jsonb(m)->>'name', 'Anggota') into nm from members m where m.id = new.from_member;
    insert into notifications(member_id, type, title, body, link, data)
    values (new.to_member, 'call_missed', nm,
            case when new.video then '📹 Panggilan video tak terjawab' else '📞 Panggilan suara tak terjawab' end,
            '/chat/' || new.thread_id::text,
            jsonb_build_object('call_id', new.call_id::text));
  end if;
  return new;
exception when others then return new;
end $function$;
