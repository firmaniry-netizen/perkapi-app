import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const b64u = (b: ArrayBuffer | string) => {
  const bytes = typeof b === "string" ? new TextEncoder().encode(b) : new Uint8Array(b);
  let s = "";
  bytes.forEach((x) => (s += String.fromCharCode(x)));
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

async function accessToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const head = b64u(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64u(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${head}.${claim}`));
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${head}.${claim}.${b64u(sig)}`,
    }),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error("no access token");
  return j.access_token as string;
}

// FCM: semua nilai di "data" wajib berupa teks
const asData = (o: Record<string, unknown>) =>
  Object.fromEntries(Object.entries(o).filter(([, v]) => v !== null && v !== undefined).map(([k, v]) => [k, String(v).slice(0, 200)]));

Deno.serve(async (req) => {
  try {
    if (req.headers.get("x-webhook-secret") !== (Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "\u0000")) {
      return new Response("forbidden", { status: 403 });
    }
    const payload = await req.json();
    const rec = payload?.record;
    if (payload?.type !== "INSERT" || !rec?.member_id) return new Response("skip");

    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: toks } = await db.from("device_tokens").select("token, platform").eq("member_id", rec.member_id);
    if (!toks?.length) return new Response("no tokens");

    const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}");
    const bearer = await accessToken(sa);
    const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
    const title = String(rec.title ?? "PERKAPI").slice(0, 80);
    const body = String(rec.body ?? "").slice(0, 180);
    const link = typeof rec.link === "string" && rec.link.startsWith("/") ? rec.link : "/notifications";
    const type = String(rec.type ?? "info");
    const extra = rec.data && typeof rec.data === "object" ? rec.data as Record<string, unknown> : {};
    const data = asData({ ...extra, link, type });
    const isCall = type === "call";
    const expires = String(Math.floor(Date.now() / 1000) + 45);

    for (const t of toks) {
      let message: Record<string, unknown>;
      if (isCall && t.platform !== "ios") {
        // Android: pesan DATA saja → aplikasi menampilkan layar dering sendiri (lihat incoming_call_ui.dart)
        message = { token: t.token, data, android: { priority: "HIGH", ttl: "45s" } };
      } else if (isCall) {
        // iPhone: notifikasi berbunyi yang menembus mode fokus; kedaluwarsa setelah 45 detik
        message = {
          token: t.token,
          notification: { title, body },
          data,
          apns: {
            headers: { "apns-priority": "10", "apns-push-type": "alert", "apns-expiration": expires },
            payload: { aps: { sound: "default", "interruption-level": "time-sensitive" } },
          },
        };
      } else {
        message = {
          token: t.token,
          notification: { title, body },
          data,
          android: { priority: "HIGH" },
          apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default" } } },
        };
      }
      const r = await fetch(url, {
        method: "POST",
        headers: { Authorization: `Bearer ${bearer}`, "content-type": "application/json" },
        body: JSON.stringify({ message }),
      });
      if (r.status === 404 || r.status === 400) {
        const e = await r.text();
        // hanya token yang benar-benar sudah tidak berlaku yang dihapus
        if (e.includes("UNREGISTERED") || (r.status === 400 && e.includes("registration token"))) {
          await db.from("device_tokens").delete().eq("token", t.token);
        }
      }
    }
    return new Response("ok");
  } catch (_) {
    return new Response("error", { status: 500 });
  }
});
