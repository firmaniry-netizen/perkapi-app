// Edge Function: kirim push FCM saat ada baris baru di tabel `notifications`.
// Dipicu oleh Database Webhook (INSERT pada notifications). Deploy: supabase functions deploy send-push --no-verify-jwt
// Secret: FCM_SERVICE_ACCOUNT (isi JSON service account Firebase), PUSH_WEBHOOK_SECRET (string acak panjang).
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

Deno.serve(async (req) => {
  try {
    if (req.headers.get("x-webhook-secret") !== (Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "\u0000")) {
      return new Response("forbidden", { status: 403 });
    }
    const payload = await req.json();
    const rec = payload?.record;
    if (payload?.type !== "INSERT" || !rec?.member_id) return new Response("skip");

    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: toks } = await db.from("device_tokens").select("token").eq("member_id", rec.member_id);
    if (!toks?.length) return new Response("no tokens");

    const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}");
    const bearer = await accessToken(sa);
    const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
    const title = String(rec.title ?? "PERKAPI").slice(0, 80);
    const body = String(rec.body ?? "").slice(0, 180);
    const link = typeof rec.link === "string" && rec.link.startsWith("/") ? rec.link : "/notifications";

    for (const t of toks) {
      const r = await fetch(url, {
        method: "POST",
        headers: { Authorization: `Bearer ${bearer}`, "content-type": "application/json" },
        body: JSON.stringify({
          message: {
            token: t.token,
            notification: { title, body },
            data: { link, type: String(rec.type ?? "info") },
            android: { priority: "HIGH" },
          },
        }),
      });
      if (r.status === 404 || r.status === 400) {
        const e = await r.text();
        if (e.includes("UNREGISTERED") || e.includes("INVALID_ARGUMENT")) {
          await db.from("device_tokens").delete().eq("token", t.token);
        }
      }
    }
    return new Response("ok");
  } catch (_) {
    return new Response("error", { status: 500 });
  }
});
