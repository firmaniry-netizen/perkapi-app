// Mengekstrak teks dari PDF dokumen dan menyimpannya di documents.content_text agar bisa dicari.
// Hanya PDF berbasis teks; PDF hasil pindai (gambar) tidak punya teks dan butuh OCR (tidak termasuk).
// Deploy: supabase functions deploy index-document   (JWT diverifikasi; pemanggil harus bisa membaca dokumennya)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { extractText, getDocumentProxy } from "https://esm.sh/unpdf@0.12.1";

const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const userDb = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { document_id } = await req.json();
    if (typeof document_id !== "string") return json({ error: "bad_request" }, 400);

    // RLS memastikan pemanggil memang boleh membaca dokumen ini
    const { data: doc } = await userDb.from("documents").select("id,bucket,file_path").eq("id", document_id).maybeSingle();
    if (!doc) return json({ error: "not_found" }, 404);
    if (!String(doc.file_path).toLowerCase().endsWith(".pdf")) return json({ indexed: false, reason: "not_pdf" });

    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: file, error } = await admin.storage.from(doc.bucket ?? "documents").download(doc.file_path);
    if (error || !file) return json({ error: "download_failed" }, 502);
    const buf = new Uint8Array(await file.arrayBuffer());
    if (buf.length > 15 * 1024 * 1024) return json({ indexed: false, reason: "too_large" });

    const pdf = await getDocumentProxy(buf);
    const { text } = await extractText(pdf, { mergePages: true });
    const clean = String(text ?? "").replace(/\s+/g, " ").trim().slice(0, 200000);
    await admin.from("documents").update({ content_text: clean, content_indexed_at: new Date().toISOString() }).eq("id", doc.id);
    return json({ indexed: clean.length > 0, chars: clean.length, reason: clean.length ? "ok" : "no_text_layer" });
  } catch (_) {
    return json({ error: "internal" }, 500);
  }
});
