// turn-credentials — memberi kredensial TURN Cloudflare sementara (berlaku 24 jam) untuk telepon/video call.
// Kunci Cloudflare tersimpan sebagai rahasia Supabase (CF_TURN_KEY_ID, CF_TURN_API_TOKEN), tidak pernah ada di aplikasi.
// Hanya pengguna yang sudah login (JWT valid) yang bisa memanggil fungsi ini.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const auth = req.headers.get("Authorization") ?? "";
  const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await supa.auth.getUser();
  if (!user) return json({ error: "Harus login." }, 401);

  const keyId = Deno.env.get("CF_TURN_KEY_ID"), token = Deno.env.get("CF_TURN_API_TOKEN");
  if (!keyId || !token) return json({ error: "TURN belum dikonfigurasi." }, 503);

  const r = await fetch(`https://rtc.live.cloudflare.com/v1/turn/keys/${keyId}/credentials/generate-ice-servers`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ ttl: 86400 }),
  });
  if (!r.ok) return json({ error: "Gagal meminta kredensial TURN.", status: r.status }, 502);
  const data = await r.json();
  // buang alamat port 53 (sering diblokir dan memperlambat sambungan)
  const list = Array.isArray(data.iceServers) ? data.iceServers : [data.iceServers];
  const iceServers = list.filter(Boolean).map((s: { urls: string | string[] }) => ({
    ...s,
    urls: (Array.isArray(s.urls) ? s.urls : [s.urls]).filter((u) => !/:53(\?|$)/.test(u)),
  }));
  return json({ iceServers });
});
