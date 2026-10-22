// Edge Function: AI PERKAPI. Deploy: supabase functions deploy ai-perkapi
// Secret:   supabase secrets set ANTHROPIC_API_KEY=... (opsional AI_MODEL=...)
// API key AI TIDAK PERNAH ada di aplikasi Flutter.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM = `Anda adalah AI PERKAPI, asisten informasi dan administrasi untuk organisasi kurator, kepailitan dan PKPU di Indonesia.
Aturan: jawab hanya berdasarkan KONTEKS yang diberikan dan pengetahuan umum; jika tidak ada di konteks, katakan tidak tahu.
Jangan membuat keputusan hukum final, jangan mengklaim hasil sebagai keputusan resmi, jangan meminta atau menebak data yang tidak diberikan.
Selalu ingatkan secara singkat bahwa hasil perlu diperiksa kembali oleh pengguna dan bukan nasihat hukum final bila menyangkut aspek hukum.
Gunakan bahasa Indonesia yang jelas.`;

const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const auth = req.headers.get("Authorization");
    if (!auth) return json({ error: "unauthorized" }, 401);

    // Klien memakai JWT pengguna => semua query tunduk pada RLS (AI tidak melihat data di luar izin).
    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
    });
    const { data: u } = await db.auth.getUser();
    if (!u?.user) return json({ error: "unauthorized" }, 401);

    const { message, conversation_id } = await req.json();
    const text = String(message ?? "").slice(0, 4000).trim();
    if (!text) return json({ error: "empty" }, 400);

    const { data: me } = await db.rpc("my_access");
    const memberId = me?.member?.id;
    if (!memberId) return json({ error: "no member" }, 403);

    let convId = conversation_id as string | null;
    if (!convId) {
      const { data: c } = await db.from("ai_conversations")
        .insert({ member_id: memberId, title: text.slice(0, 60) }).select("id").single();
      convId = c?.id ?? null;
    }
    if (!convId) return json({ error: "conversation" }, 500);

    // Konteks sederhana: pencarian kata kunci pada data yang BOLEH dibaca pengguna (via RLS).
    const kw = text.replace(/[,()%*\\]/g, " ").split(/\s+/).filter((w) => w.length > 3).slice(0, 4);
    const pat = kw.length ? kw.map((k) => `title.ilike.%${k}%`).join(",") : "title.ilike.%zzzz%";
    const [org, ann, notes] = await Promise.all([
      db.from("pocket_book_contents").select("title,content").or(pat).limit(3),
      db.from("announcements").select("title,body").or(pat).limit(3),
      db.from("personal_notes").select("title,content").eq("member_id", memberId).or(pat).limit(3),
    ]);
    const ctx = JSON.stringify({ buku_saku_organisasi: org.data, pengumuman: ann.data, catatan_saya: notes.data }).slice(0, 12000);

    const { data: hist } = await db.from("ai_messages").select("role,content")
      .eq("conversation_id", convId).order("created_at", { ascending: true }).limit(20);

    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": Deno.env.get("ANTHROPIC_API_KEY") ?? "",
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("AI_MODEL") ?? "claude-sonnet-5-5",
        max_tokens: 1200,
        system: `${SYSTEM}\n\nKONTEKS (data milik/diizinkan untuk pengguna):\n${ctx}`,
        messages: [...(hist ?? []).map((m) => ({ role: m.role, content: m.content })), { role: "user", content: text }],
      }),
    });
    if (!res.ok) return json({ error: "ai_unavailable" }, 502);
    const out = await res.json();
    const reply = (out.content ?? []).filter((b: any) => b.type === "text").map((b: any) => b.text).join("\n").trim();

    await db.from("ai_messages").insert([
      { conversation_id: convId, role: "user", content: text },
      { conversation_id: convId, role: "assistant", content: reply },
    ]);
    return json({ reply, conversation_id: convId });
  } catch (_) {
    return json({ error: "server" }, 500);
  }
});
