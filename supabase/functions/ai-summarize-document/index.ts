// Edge Function: ringkasan dokumen dengan AI.
// Deploy: supabase functions deploy ai-summarize-document
// Secret: ANTHROPIC_API_KEY (sama dengan ai-perkapi), opsional AI_MODEL.
// Dokumen diunduh memakai JWT pengguna, jadi hanya dokumen yang BOLEH dibaca (RLS) yang bisa diringkas.
// Format didukung: PDF, JPG, PNG. Maksimal 10 MB.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

const SYSTEM = `Anda adalah AI PERKAPI, asisten administrasi untuk organisasi kurator, kepailitan dan PKPU di Indonesia.
Ringkas dokumen yang diberikan HANYA berdasarkan isinya. Jangan menambah fakta, jangan memberi keputusan hukum final.
Jika dokumen tidak terbaca atau kosong, katakan apa adanya. Gunakan bahasa Indonesia yang jelas.`;

const PROMPT = `Buat ringkasan dokumen ini (maksimal 350 kata) dengan format:
1. Jenis & tujuan dokumen
2. Pihak-pihak yang disebut
3. Tanggal, nomor, dan angka penting
4. Kewajiban, tenggat, atau tindakan lanjutan
5. Hal yang perlu diperiksa ulang oleh pembaca
Akhiri dengan satu kalimat bahwa ringkasan ini bantuan AI dan perlu diverifikasi terhadap dokumen asli.`;

const MAX_BYTES = 10 * 1024 * 1024;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const auth = req.headers.get("Authorization");
    if (!auth) return json({ error: "unauthorized" }, 401);
    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
    });
    const { data: u } = await db.auth.getUser();
    if (!u?.user) return json({ error: "unauthorized" }, 401);

    const { document_id } = await req.json();
    if (!document_id) return json({ error: "document_id required" }, 400);

    const { data: doc } = await db.from("documents")
      .select("id,title,bucket,file_path,mime_type,size_bytes")
      .eq("id", document_id).maybeSingle();
    if (!doc) return json({ error: "not_found" }, 404);

    const ext = String(doc.file_path).split(".").pop()?.toLowerCase() ?? "";
    const kinds: Record<string, { type: "document" | "image"; media: string }> = {
      pdf: { type: "document", media: "application/pdf" },
      jpg: { type: "image", media: "image/jpeg" },
      jpeg: { type: "image", media: "image/jpeg" },
      png: { type: "image", media: "image/png" },
    };
    const kind = kinds[ext];
    if (!kind) return json({ error: "unsupported", message: "Format belum didukung. Gunakan PDF, JPG, atau PNG." }, 415);
    if ((doc.size_bytes ?? 0) > MAX_BYTES) return json({ error: "too_large", message: "Ukuran file melebihi 10 MB." }, 413);

    const { data: blob, error } = await db.storage.from(doc.bucket ?? "documents").download(doc.file_path);
    if (error || !blob) return json({ error: "download_failed" }, 502);
    const bytes = new Uint8Array(await blob.arrayBuffer());
    if (bytes.length > MAX_BYTES) return json({ error: "too_large", message: "Ukuran file melebihi 10 MB." }, 413);

    const data = encodeBase64(bytes);
    const block = kind.type === "document"
      ? { type: "document", source: { type: "base64", media_type: kind.media, data } }
      : { type: "image", source: { type: "base64", media_type: kind.media, data } };

    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": Deno.env.get("ANTHROPIC_API_KEY") ?? "",
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("AI_MODEL") ?? "claude-sonnet-5-5",
        max_tokens: 1500,
        system: SYSTEM,
        messages: [{ role: "user", content: [block, { type: "text", text: PROMPT }] }],
      }),
    });
    if (!res.ok) return json({ error: "ai_unavailable" }, 502);
    const out = await res.json();
    const summary = (out.content ?? []).filter((b: any) => b.type === "text").map((b: any) => b.text).join("\n").trim();

    await db.rpc("log_event", { p_action: "ai_summary", p_module: "documents", p_record: String(doc.id) });
    return json({ summary, title: doc.title });
  } catch (_) {
    return json({ error: "server" }, 500);
  }
});
