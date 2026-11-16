// Pra-ujian di lokasi: peserta memasukkan nama dan token sekali pakai dari admin.
// Server: start_exam_token(p_name, p_token) -> uuid peserta, get_exam_questions(p_id), submit_exam_token(p_id, p_answers).
// Skor tidak ditampilkan ke peserta; hanya admin yang melihatnya.
(function () {
  var C = window.PERKAPI || {}, U = (C.SUPABASE_URL || "").replace(/\/+$/, ""), K = C.SUPABASE_ANON_KEY;
  var $ = function (i) { return document.getElementById(i); };
  var KEY = "perkapi_ujian_id";
  var esc = function (s) { var d = document.createElement("div"); d.textContent = s == null ? "" : s; return d.innerHTML; };
  var busy = function (b, on) { b.setAttribute("aria-busy", on ? "true" : "false"); b.disabled = !!on; };
  var msg = function (t) { var m = $("xm"); m.textContent = t || ""; m.hidden = !t; if (t) m.scrollIntoView({ block: "nearest" }); };
  var store = { get: function () { try { return sessionStorage.getItem(KEY); } catch (e) { return null; } }, set: function (v) { try { v ? sessionStorage.setItem(KEY, v) : sessionStorage.removeItem(KEY); } catch (e) {} } };

  async function rpc(fn, body) {
    if (!U || !K) throw new Error("Koneksi server belum diatur. Hubungi pengawas.");
    var r = await fetch(U + "/rest/v1/rpc/" + fn, { method: "POST", headers: { apikey: K, "Content-Type": "application/json" }, body: JSON.stringify(body) });
    var t = await r.text(), j; try { j = JSON.parse(t); } catch (e) { j = t; }
    if (!r.ok) {
      if (r.status === 404) throw new Error("Layanan pra-ujian belum aktif di server. Hubungi pengawas.");
      throw new Error((j && j.message) || "Permintaan gagal. Periksa koneksi lalu coba lagi.");
    }
    return j;
  }

  // token ditampilkan dengan pemisah: K7QM-3XPA
  $("xt").addEventListener("input", function () {
    var v = this.value.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 8);
    this.value = v.length > 4 ? v.slice(0, 4) + "-" + v.slice(4) : v;
  });

  async function muatSoal(id) {
    var qs = await rpc("get_exam_questions", { p_id: id });
    if (!qs || !qs.length) throw new Error("Soal belum tersedia. Hubungi pengawas.");
    $("qs").innerHTML = qs.map(function (q, i) {
      return '<fieldset class="q"><legend>' + (i + 1) + ". " + esc(q.question) + "</legend>" +
        (q.options || []).map(function (o, j) { return '<label class="opt"><input type="radio" name="q' + q.id + '" value="' + j + '"> <span>' + esc(o) + "</span></label>"; }).join("") + "</fieldset>";
    }).join("");
    $("xq").dataset.n = qs.length;
    var hitung = function () { var n = $("qs").querySelectorAll("input:checked").length; $("xc").textContent = n + " dari " + qs.length + " soal terjawab"; };
    $("qs").onchange = hitung; hitung();
    $("x-start").hidden = true; $("xq").hidden = false; msg("");
    scrollTo(0, 0);
  }

  $("xf").addEventListener("submit", async function (e) {
    e.preventDefault(); msg("");
    var n = $("xn").value.trim(), t = $("xt").value.replace(/-/g, "");
    if (n.length < 3) { $("xn").setAttribute("aria-invalid", "true"); $("xn").focus(); return msg("Isi nama lengkap sesuai KTP."); }
    $("xn").removeAttribute("aria-invalid");
    if (t.length !== 8) { $("xt").setAttribute("aria-invalid", "true"); $("xt").focus(); return msg("Token terdiri dari 8 huruf dan angka."); }
    $("xt").removeAttribute("aria-invalid");
    var b = $("xb"); busy(b, true);
    try {
      var id = await rpc("start_exam_token", { p_name: n, p_token: t });
      if (!id) throw new Error("Token tidak berlaku. Token mungkin salah, sudah dipakai, atau bukan untuk hari ini.");
      store.set(id); $("xw").textContent = n;
      await muatSoal(id);
    } catch (err) { msg(err.message); }
    finally { busy(b, false); }
  });

  $("xq").addEventListener("submit", async function (e) {
    e.preventDefault(); msg("");
    var total = +this.dataset.n, ans = {};
    [].forEach.call($("qs").querySelectorAll("input:checked"), function (i) { ans[i.name.slice(1)] = i.value; });
    var kosong = total - Object.keys(ans).length;
    if (kosong > 0 && !confirmKosong(kosong)) return;
    var b = $("xs"); busy(b, true);
    try {
      await rpc("submit_exam_token", { p_id: store.get(), p_answers: ans });
      store.set(null); $("xq").hidden = true; $("xd").hidden = false; scrollTo(0, 0);
    } catch (err) { msg(err.message); }
    finally { busy(b, false); }
  });

  // peringatan soal kosong tanpa dialog bawaan browser: tekan Kirim sekali lagi untuk mengonfirmasi
  var siap = false;
  function confirmKosong(k) { if (siap) return true; siap = true; msg(k + " soal belum dijawab. Tekan Kirim jawaban sekali lagi untuk tetap mengirim."); return false; }

  // halaman dimuat ulang saat mengerjakan: lanjutkan dengan peserta yang sama
  var lama = store.get();
  if (lama) muatSoal(lama).catch(function () { store.set(null); });
})();
