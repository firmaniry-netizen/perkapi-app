// PERKAPI tampilan terang: menu, kepala situs, muncul saat digulir, kerja sama, dan penyesuaian kecil.
// Opsional: bila berkas ini gagal dimuat, semua konten tetap terbaca dan formulir tetap berfungsi.
(function () {
  var d = document, de = d.documentElement;
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

  // kepala situs: garis bawah setelah digulir
  var hd = d.querySelector(".hd");
  var onScroll = function () { if (hd) hd.classList.toggle("scrolled", scrollY > 8); };
  addEventListener("scroll", onScroll, { passive: true }); onScroll();

  // menu seluler
  var bg = d.querySelector(".burger"), nav = d.getElementById("nav");
  if (hd && bg && nav) {
    var setOpen = function (o) { hd.classList.toggle("open", o); bg.setAttribute("aria-expanded", o ? "true" : "false"); bg.setAttribute("aria-label", o ? "Tutup menu" : "Buka menu"); };
    bg.addEventListener("click", function () { setOpen(!hd.classList.contains("open")); });
    nav.addEventListener("click", function (e) { if (e.target.closest("a")) setOpen(false); });
    addEventListener("keydown", function (e) { if (e.key === "Escape" && hd.classList.contains("open")) { setOpen(false); bg.focus(); } });
    addEventListener("resize", function () { if (innerWidth > 860) setOpen(false); });
  }

  // tandai elemen yang muncul saat digulir (tanpa mengubah HTML tiap halaman)
  var tandai = function (sel, extra) { [].forEach.call(d.querySelectorAll(sel), function (el) { if (!el.closest(".hero3") && !el.classList.contains("rv")) { el.classList.add("rv"); if (extra) el.classList.add(extra); } }); };
  if (!reduce) {
    tandai(".head > *, .split-h > *, .join > div > *, .faq > div:first-child > *, .ph .crumb, .ph h1, .ph .lead, .reg-side > *, .exam-note, .cta, .quote");
    tandai(".vals > div, .prows li, .go2-it", "rv-l");
    tandai(".role, .steps-v li, .qa details, .feat li, .stores, .app-note, .shot, .pc-grid .pc, .mitra-g li, .ab-g > *, .pl-cards-head > *, .pl-cta-g > *, .pl-check li, .ag-side .help, .go2-it, .reg-side > *", "");
    tandai(".gallery .photo, .split-photo, .wide-photo, .ph .photo", "rv-c");
    tandai(".app", "rv-s");
    tandai(".stat");
  }
  // judul hero dipecah per kata
  [].forEach.call(d.querySelectorAll("h1.words"), function (h) {
    var k = 0;
    h.innerHTML = h.textContent.trim().split(/\s+/).map(function (w) { return '<span class="w-o"><span class="w-i" style="--k:' + (k++) + '">' + w + "</span></span>"; }).join(" ");
  });
  // foto hero bergerak pelan saat digulir
  var hb = d.querySelector(".hero3-bg img");
  if (hb && !reduce) {
    var tick = false;
    addEventListener("scroll", function () {
      if (tick) return; tick = true;
      requestAnimationFrame(function () { var y = Math.min(scrollY, innerHeight); hb.style.translate = "0 " + (y * 0.18).toFixed(1) + "px"; tick = false; });
    }, { passive: true });
  }

  // muncul saat digulir (sekali saja); elemen berurutan dalam satu kelompok diberi jeda bertahap
  var els = [].slice.call(d.querySelectorAll(".rv"));
  els.forEach(function (el) { var p = el.parentElement, sib = [].filter.call(p.children, function (c) { return c.classList.contains("rv"); }); el.style.setProperty("--i", Math.min(sib.indexOf(el), 5)); });
  if (reduce || !("IntersectionObserver" in window)) els.forEach(function (el) { el.classList.add("in"); });
  else {
    var io = new IntersectionObserver(function (en) { en.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } }); }, { rootMargin: "0px 0px -8% 0px", threshold: .08 });
    els.forEach(function (el) { io.observe(el); });
  }
  requestAnimationFrame(function () { requestAnimationFrame(function () { de.classList.add("ready"); }); });

  // kerja sama kelembagaan: daftar mitra perguruan tinggi. Ubah daftar di sini.
  var ks = d.getElementById("ks");
  if (ks) {
    var MITRA = [
      { nama: "Universitas Hasanuddin", singkat: "UNHAS", kota: "Makassar", pdf: "/dokumen/mou/unhas.pdf", logo: "/img/mitra/unhas.webp" },
      { nama: "Universitas Muhammadiyah Sukabumi", singkat: "UMMI", kota: "Sukabumi", pdf: "/dokumen/mou/ummi.pdf", logo: "/img/mitra/ummi.webp" },
      { nama: "Universitas Muslim Indonesia", singkat: "UMI", kota: "Makassar", pdf: "/dokumen/mou/umi.pdf", logo: "/img/mitra/umi.webp" },
      { nama: "Universitas Malikussaleh", singkat: "UNIMAL", kota: "Lhokseumawe", pdf: "/dokumen/mou/unimal.pdf", logo: "/img/mitra/unimal.webp" }
    ];
    var e = function (s) { var x = d.createElement("div"); x.textContent = s; return x.innerHTML; };
    ks.innerHTML = MITRA.map(function (m) {
      return '<li><div class="ks-row">' +
        '<span class="ks-logo"><b>' + e(m.singkat) + '</b><img src="' + e(m.logo) + '" alt="" loading="lazy" decoding="async" onerror="this.remove()" onload="this.parentNode.classList.add(\'img\')"></span>' +
        '<span class="ks-t"><strong>' + e(m.nama) + '</strong><span class="ks-k">' + e(m.kota) + '</span></span></div></li>';
    }).join("");
  }

  // visi & misi dari panel admin (diisi /js/site.js): tampilkan bagiannya hanya bila ada isinya
  var vm = d.getElementById("vm");
  if (vm && "MutationObserver" in window) new MutationObserver(function () { var s = vm.closest("[hidden]"); if (s && vm.innerHTML.trim()) s.hidden = false; }).observe(vm, { childList: true });

  // panel dokumen: tautan contoh surat memakai alamat relatif; arahkan ke folder dokumen di akar situs
  var dok = d.getElementById("dok");
  if (dok && "MutationObserver" in window) new MutationObserver(function () {
    [].forEach.call(dok.querySelectorAll('a[href^="dokumen/"]'), function (a) { a.setAttribute("href", "/" + a.getAttribute("href")); });
  }).observe(dok, { childList: true, subtree: true });
})();

// angka data terkini: sembunyikan baris yang nilainya 0 (mis. belum ada agenda)
setTimeout(function () { ["s1", "s2"].forEach(function (id) { var el = document.getElementById(id); if (el && el.textContent.trim() === "0") { var li = el.closest(".b-stat"); if (li) li.hidden = true; } }); }, 2500);

// angka menghitung naik saat terlihat
(function () {
  var els = [].slice.call(document.querySelectorAll(".stat"));
  if (!els.length) return;
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var run = function (st) {
    st.classList.add("in");
    var b = st.querySelector(".cnt"); if (!b || reduce) return;
    var to = +b.dataset.to, from = to > 1000 ? to - 40 : 0, t0 = performance.now(), dur = 1600;
    var step = function (t) { var k = Math.min(1, (t - t0) / dur), e = 1 - Math.pow(1 - k, 4); b.textContent = Math.round(from + (to - from) * e); if (k < 1) requestAnimationFrame(step); };
    requestAnimationFrame(step);
  };
  if (reduce || !("IntersectionObserver" in window)) { els.forEach(function (s) { s.classList.add("in"); }); return; }
  var io = new IntersectionObserver(function (en) { en.forEach(function (e) { if (e.isIntersecting) { io.unobserve(e.target); run(e.target); } }); }, { threshold: .4 });
  els.forEach(function (s, i) { s.style.setProperty("--i", i); io.observe(s); });
})();

// teks bawaan daftar berita ke bahasa Indonesia
(function () {
  var nw = document.getElementById("news"); if (!nw || !("MutationObserver" in window)) return;
  var ubah = function () {
    [].forEach.call(document.querySelectorAll(".newsgrid .rm"), function (a) { if (/Read more/.test(a.textContent)) { a.firstChild.nodeValue = "Baca Selengkapnya "; a.setAttribute("aria-label", (a.getAttribute("aria-label") || "").replace("Read more", "Baca Selengkapnya")); } });
    [].forEach.call(document.querySelectorAll(".news-more button"), function (b) { if (/Read more/.test(b.textContent)) b.firstChild.nodeValue = "Muat Berita Lainnya "; });
  };
  new MutationObserver(ubah).observe(nw.parentNode, { childList: true, subtree: true }); ubah();
})();

// pita mitra: gandakan isi agar berputar tanpa jeda
(function () {
  var t = document.querySelector(".mq-track"); if (!t) return;
  [].slice.call(t.children).forEach(function (li) { var c = li.cloneNode(true); c.setAttribute("aria-hidden", "true"); t.appendChild(c); });
})();

// berita beranda: tombol geser kiri/kanan
(function () {
  var car = document.querySelector(".car"); if (!car) return;
  var g = car.querySelector(".newsgrid"), bs = car.querySelectorAll(".car-b");
  var upd = function () { if (bs.length < 2) return; var max = g.scrollWidth - g.clientWidth - 2; bs[0].disabled = g.scrollLeft <= 2; bs[1].disabled = g.scrollLeft >= max; };
  [].forEach.call(bs, function (b) { b.addEventListener("click", function () { var it = g.firstElementChild; var w = it ? it.getBoundingClientRect().width + 20 : g.clientWidth; g.scrollBy({ left: w * +b.dataset.d, behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" }); }); });
  g.addEventListener("scroll", function () { requestAnimationFrame(upd); }, { passive: true });
  new MutationObserver(upd).observe(g, { childList: true }); addEventListener("resize", upd); upd();
})();

// kartu Jelajahi: tombol geser + nilai menyala bergantian
(function () {
  var t = document.getElementById("pc");
  if (t) {
    var bs = document.querySelectorAll('.car-b[data-t="pc"]');
    var upd = function () { if (bs.length < 2) return; var max = t.scrollWidth - t.clientWidth - 2; bs[0].disabled = t.scrollLeft <= 2; bs[1].disabled = t.scrollLeft >= max; };
    [].forEach.call(bs, function (b) { b.addEventListener("click", function () { var c = t.querySelector(".pc"); t.scrollBy({ left: (c ? c.getBoundingClientRect().width + 18 : 300) * +b.dataset.d, behavior: "smooth" }); }); });
    t.addEventListener("scroll", function () { requestAnimationFrame(upd); }, { passive: true }); addEventListener("resize", upd); upd();
  }
  var its = [].slice.call(document.querySelectorAll(".sq-it"));
  if (its.length && "IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (en) { en.forEach(function (e) { e.target.classList.toggle("on", e.isIntersecting); }); }, { rootMargin: "-38% 0px -38% 0px" });
    its.forEach(function (i) { io.observe(i); });
  } else its.forEach(function (i) { i.classList.add("on"); });
})();

// berita terbuka di jendela, tanpa pindah halaman (tautan tetap berfungsi bila JS gagal)
(function () {
  if (typeof rpc !== "function") return;
  var last = null, box = null;
  var tutup = function () {
    if (!box) return; var b = box; box = null;
    b.classList.remove("open"); document.body.classList.remove("nm-lock");
    setTimeout(function () { b.remove(); }, 320);
    if (location.search.indexOf("berita=") > -1) history.replaceState(null, "", location.pathname + location.hash);
    if (last) last.focus();
  };
  var buka = async function (id, opener) {
    last = opener || null;
    box = document.createElement("div"); box.className = "nmodal"; box.setAttribute("role", "dialog"); box.setAttribute("aria-modal", "true"); box.setAttribute("aria-label", "Berita");
    box.innerHTML = '<div class="nm-box"><button class="nm-x" type="button" aria-label="Tutup berita">&times;</button><div class="nm-c"><div class="sk-card"></div></div></div>';
    document.body.appendChild(box); document.body.classList.add("nm-lock");
    requestAnimationFrame(function () { box.classList.add("open"); });
    var b = box; b.querySelector(".nm-x").onclick = tutup; b.addEventListener("click", function (e) { if (e.target === b) tutup(); });
    b.querySelector(".nm-x").focus();
    try {
      var r = await rpc("public_news_item", { p_id: id }); r = Array.isArray(r) ? r[0] : r;
      if (!r) throw 0;
      var pics = (r.photos && r.photos.length ? r.photos : (r.photo_path ? [r.photo_path] : []));
      await signPhotos(pics); var u = pics.map(photoUrl).filter(Boolean);
      var words = String(r.body || "").split(/\s+/).length, url = location.origin + "/baca.html?id=" + encodeURIComponent(id);
      b.querySelector(".nm-box").insertAdjacentHTML("beforeend", "");
      b.querySelector(".nm-c").outerHTML = (u.length ? '<img class="nm-img" alt="" src="' + esc(u[0]) + '">' : "") +
        '<div class="nm-c"><span class="tag">' + esc(r.category || "Berita") + '</span><h2>' + esc(r.title) + '</h2><p class="baca-m">' + fmt(r.created_at) + ", " + Math.max(1, Math.round(words / 200)) + ' menit baca</p><div class="baca-body">' +
        String(r.body || "").split(/\n+/).filter(Boolean).map(function (p) { return "<p>" + esc(p) + "</p>"; }).join("") +
        '</div><div class="share"><a class="btn" href="' + esc(url) + '">Buka Halaman Berita</a><a class="btn line" target="_blank" rel="noopener" href="https://wa.me/?text=' + encodeURIComponent(r.title + " " + url) + '">Kirim lewat WhatsApp</a></div></div>';
    } catch (e) { var c = b.querySelector(".nm-c"); if (c) c.innerHTML = '<p>Berita belum dapat dimuat. <a href="baca.html?id=' + encodeURIComponent(id) + '">Buka Halaman Berita</a>.</p>'; }
  };
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest('.newsgrid a[href*="baca.html?id="]');
    if (!a || e.metaKey || e.ctrlKey || e.shiftKey || e.button) return;
    e.preventDefault(); var id = new URL(a.href, location.href).searchParams.get("id");
    history.pushState(null, "", "?berita=" + encodeURIComponent(id) + location.hash); buka(id, a);
  });
  addEventListener("keydown", function (e) { if (e.key === "Escape") tutup(); });
  addEventListener("popstate", function () { if (box) tutup(); });
  var q = new URLSearchParams(location.search).get("berita"); if (q) buka(q);
})();

// revisi 13: gerak ala pliability, digerakkan GSAP + ScrollTrigger + SplitText
(function () {
  var d = document, html = d.documentElement;
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (reduce || !window.gsap || !window.ScrollTrigger) { [].forEach.call(d.querySelectorAll(".steps-v"), function (o) { o.style.setProperty("--p", 1); }); return; }
  gsap.registerPlugin(ScrollTrigger, window.SplitText || {});
  html.classList.add("gs");
  var E = "expo.out", $$ = function (s, r) { return [].slice.call((r || d).querySelectorAll(s)); };
  var D0 = html.classList.contains("pl-first") ? 1.8 : html.classList.contains("pt-in") ? .45 : 0;
  var mm = gsap.matchMedia();

  // hero: teks terangkat dan memudar, bingkai foto melayang lebih lambat
  var hero = d.querySelector(".pl-hero");
  if (hero) {
    gsap.from(".pl-proof > *", { y: 12, autoAlpha: 0, stagger: .06, duration: .7, ease: "power2.out", delay: .5 });
  }

  // judul halaman dalam (Tentang, Pendaftaran, Agenda): kata naik dari balik garis
  $$(".ph h1").forEach(function (h) {
    h.classList.remove("rv", "in");
    if (!window.SplitText) return;
    d.fonts.ready.then(function () {
      var sp = SplitText.create(h, { type: "words", wordsClass: "wd" });
      sp.words.forEach(function (w) { var o = d.createElement("span"); o.className = "wd-o"; w.parentNode.insertBefore(o, w); o.appendChild(w); });
      gsap.from(sp.words, { yPercent: 100, duration: .8, ease: "power3.out", stagger: .05, delay: .05 });
    });
  });
  $$(".ph .photo").forEach(function (ph) {
    ph.classList.remove("rv", "in", "rv-c");
    gsap.from(ph, { autoAlpha: 0, y: 12, duration: .7, ease: "power2.out", delay: .2 });
  });

  addEventListener("load", function () { ScrollTrigger.refresh(); });
})();

// agenda kosong: tampilkan kalender bulan berjalan, bukan kotak polos
(function () {
  var ev = document.getElementById("ev"); if (!ev) return;
  var BL = ["Januari","Februari","Maret","April","Mei","Juni","Juli","Agustus","September","Oktober","November","Desember"];
  var gambar = function () {
    var kosong = ev.querySelector(".rw") && !ev.querySelector(".ev, .ev-it, article, a");
    if (!kosong || ev.querySelector(".cal")) return;
    var now = new Date(), y = now.getFullYear(), m = now.getMonth(), awal = (new Date(y, m, 1).getDay() + 6) % 7, jml = new Date(y, m + 1, 0).getDate();
    var sel = ""; for (var i = 0; i < awal; i++) sel += "<span></span>";
    for (var t = 1; t <= jml; t++) sel += '<span' + (t === now.getDate() ? ' class="today" aria-current="date"' : "") + ">" + t + "</span>";
    var pesan = ev.querySelector(".rw p") ? ev.querySelector(".rw p").textContent : "Belum ada agenda mendatang.";
    ev.innerHTML = '<div class="cal"><div class="cal-h"><b>' + BL[m] + " " + y + '</b><span>Kalender kegiatan PERKAPI</span></div>' +
      '<div class="cal-d" aria-hidden="true"><i>Sen</i><i>Sel</i><i>Rab</i><i>Kam</i><i>Jum</i><i>Sab</i><i>Min</i></div><div class="cal-g" aria-hidden="true">' + sel + "</div>" +
      '<p class="cal-e">' + pesan + " Jadwal baru diumumkan di halaman ini dan di Instagram @official.perkapi.</p></div>";
  };
  new MutationObserver(gambar).observe(ev, { childList: true }); gambar();
})();

// status memuat pada tombol telepon dan tautan keluar, agar tekanan terasa ditanggapi
(function () {
  document.addEventListener("click", function (e) {
    var b = e.target.closest && e.target.closest('a.btn[href^="tel:"], a.btn[target="_blank"]');
    if (!b) return;
    b.setAttribute("aria-busy", "true");
    setTimeout(function () { b.removeAttribute("aria-busy"); }, 1600);
  });
})();

// revisi 21: gerak kecil yang menjelaskan
(function () {
  var d = document, reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var EASE = "cubic-bezier(.2,.8,.2,1)";

  // 9. garis bawah menu bergeser ke tautan yang ditunjuk
  var nav = d.getElementById("nav");
  if (nav && matchMedia("(hover: hover) and (min-width: 861px)").matches) {
    var bar = d.createElement("span"); bar.className = "nav-bar"; bar.setAttribute("aria-hidden", "true"); nav.appendChild(bar);
    var links = [].slice.call(nav.querySelectorAll("a:not(.btn)"));
    var cur = nav.querySelector('a[aria-current="page"]:not(.btn)');
    var ke = function (a, instan) {
      if (!a) { bar.style.opacity = 0; return; }
      var r = a.getBoundingClientRect(), n = nav.getBoundingClientRect();
      if (instan) bar.style.transition = "none";
      bar.style.opacity = 1; bar.style.width = (r.width - 28) + "px"; bar.style.transform = "translateX(" + (r.left - n.left + 14) + "px)";
      if (instan) { void bar.offsetWidth; bar.style.transition = ""; }
    };
    nav.classList.add("has-bar");
    links.forEach(function (a) { a.addEventListener("pointerenter", function () { ke(a); }); a.addEventListener("focus", function () { ke(a); }); });
    nav.addEventListener("pointerleave", function () { ke(cur); });
    addEventListener("resize", function () { ke(cur, true); });
    (d.fonts ? d.fonts.ready : Promise.resolve()).then(function () { ke(cur, true); });
  }

  // 8. menu HP: tautan diberi urutan untuk muncul berurutan
  if (nav) [].forEach.call(nav.querySelectorAll("a"), function (a, i) { a.style.setProperty("--k", i); });

  // 7. tanya jawab: buka dan tutup dengan tinggi yang mengalir
  [].forEach.call(d.querySelectorAll(".qa details"), function (dt) {
    var sm = dt.querySelector("summary"), body = dt.querySelector(".a"); if (!sm || !body || reduce || !body.animate) return;
    var anim = null;
    sm.addEventListener("click", function (e) {
      e.preventDefault();
      var awal = body.getBoundingClientRect().height;
      if (anim) anim.cancel();
      if (!dt.open) {
        dt.open = true; var akhir = body.getBoundingClientRect().height;
        anim = body.animate([{ height: awal + "px", opacity: 0 }, { height: akhir + "px", opacity: 1 }], { duration: 320, easing: EASE });
      } else {
        dt.classList.add("closing");
        anim = body.animate([{ height: awal + "px", opacity: 1 }, { height: "0px", opacity: 0 }], { duration: 240, easing: EASE });
        anim.onfinish = function () { dt.open = false; dt.classList.remove("closing"); };
      }
      anim.addEventListener("finish", function () { anim = null; });
    });
  });

  // 6. foto membesar dari tempatnya saat diklik, kembali ke tempat yang sama saat ditutup
  var pics = [].slice.call(d.querySelectorAll(".ph .photo img, .wide-photo img, .split-ph img, .gal img"));
  pics.forEach(function (im) {
    var box = im.closest("figure, .photo, .wide-photo") || im.parentNode;
    box.classList.add("zoomable-img"); box.setAttribute("role", "button"); box.setAttribute("tabindex", "0"); box.setAttribute("aria-label", "Perbesar foto" + (im.alt ? ": " + im.alt : ""));
    var buka = function () {
      var r = im.getBoundingClientRect(), src = im.getAttribute("data-full") || im.currentSrc || im.src;
      if (/-900\.jpg/.test(src)) src = src.replace("-900.jpg", ".jpg");
      var ov = d.createElement("div"); ov.className = "lb"; ov.setAttribute("role", "dialog"); ov.setAttribute("aria-modal", "true"); ov.setAttribute("aria-label", im.alt || "Foto");
      ov.innerHTML = '<button class="lb-x" type="button" aria-label="Tutup foto">&times;</button>';
      var big = d.createElement("img"); big.src = src; big.alt = im.alt || ""; big.className = "lb-img"; ov.appendChild(big);
      if (im.alt) { var cap = d.createElement("p"); cap.className = "lb-cap"; cap.textContent = im.alt; ov.appendChild(cap); }
      d.body.appendChild(ov); d.body.classList.add("nm-lock");
      var rasio = (im.naturalWidth || r.width) / (im.naturalHeight || r.height);
      var maxW = innerWidth * .92, maxH = innerHeight * .8, w = Math.min(maxW, maxH * rasio), h = w / rasio;
      var tx = (innerWidth - w) / 2, ty = (innerHeight - h) / 2 - 16;
      big.style.cssText = "left:" + tx + "px;top:" + ty + "px;width:" + w + "px;height:" + h + "px";
      var dari = "translate(" + (r.left - tx) + "px," + (r.top - ty) + "px) scale(" + (r.width / w) + "," + (r.height / h) + ")";
      if (!reduce) {
        big.animate([{ transform: dari, borderRadius: "24px" }, { transform: "none", borderRadius: "12px" }], { duration: 420, easing: EASE });
        ov.animate([{ backgroundColor: "rgba(10,19,38,0)" }, { backgroundColor: "rgba(10,19,38,.88)" }], { duration: 320, fill: "forwards" });
      } else ov.style.backgroundColor = "rgba(10,19,38,.88)";
      var tutup = function () {
        if (ov.dataset.t) return; ov.dataset.t = 1; d.body.classList.remove("nm-lock");
        var r2 = im.getBoundingClientRect(), ke = "translate(" + (r2.left - tx) + "px," + (r2.top - ty) + "px) scale(" + (r2.width / w) + "," + (r2.height / h) + ")";
        if (reduce) { ov.remove(); box.focus(); return; }
        big.animate([{ transform: "none" }, { transform: ke, borderRadius: "24px" }], { duration: 340, easing: EASE, fill: "forwards" });
        var a = ov.animate([{ backgroundColor: "rgba(10,19,38,.88)" }, { backgroundColor: "rgba(10,19,38,0)" }], { duration: 340, fill: "forwards" });
        a.onfinish = function () { ov.remove(); box.focus({ preventScroll: true }); };
      };
      ov.addEventListener("click", tutup);
      var esc = function (e) { if (e.key === "Escape") { tutup(); removeEventListener("keydown", esc); } };
      addEventListener("keydown", esc);
      ov.querySelector(".lb-x").focus();
    };
    box.addEventListener("click", buka);
    box.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); buka(); } });
  });
})();

// revisi 22
(function () {
  var d = document, html = d.documentElement, hd = d.querySelector(".hd");
  // tinggi kepala situs untuk menu HP dan penanda bagian
  var ukur = function () { if (hd) html.style.setProperty("--hd-b", Math.round(hd.getBoundingClientRect().bottom) + "px"); };
  ukur(); addEventListener("resize", ukur); addEventListener("scroll", function () { if (!hd || !hd.classList.contains("open")) ukur(); }, { passive: true });
  var bg = d.querySelector(".burger");
  if (bg) bg.addEventListener("click", function () { ukur(); setTimeout(function () { d.body.classList.toggle("menu-open", hd.classList.contains("open")); }, 0); });
  var nav = d.getElementById("nav"); if (nav) nav.addEventListener("click", function (e) { if (e.target.closest("a")) d.body.classList.remove("menu-open"); });
  addEventListener("keydown", function (e) { if (e.key === "Escape") d.body.classList.remove("menu-open"); });

  // tombol kembali ke atas
  var tt = d.createElement("button"); tt.type = "button"; tt.className = "totop"; tt.setAttribute("aria-label", "Kembali ke atas");
  tt.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 19V5M5 12l7-7 7 7"/></svg>';
  d.body.appendChild(tt);
  tt.addEventListener("click", function () { scrollTo({ top: 0, behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" }); var t = d.getElementById("main"); if (t) t.focus({ preventScroll: true }); });
  var raf = 0; addEventListener("scroll", function () { if (raf) return; raf = requestAnimationFrame(function () { raf = 0; tt.classList.toggle("on", scrollY > innerHeight * 1.2); }); }, { passive: true });

  // foto memudar halus setelah dimuat
  [].forEach.call(d.querySelectorAll("main img"), function (im) {
    if (im.complete && im.naturalWidth) return;
    im.classList.add("fd");
    var ok = function () { im.classList.add("ok"); };
    im.addEventListener("load", ok); im.addEventListener("error", ok);
  });

  // penanda bagian yang sedang dibaca
  var sn = d.querySelector(".secnav");
  if (sn && "IntersectionObserver" in window) {
    var ln = [].slice.call(sn.querySelectorAll("a")), aktif = null;
    var pilih = function (id) {
      if (aktif === id) return; aktif = id;
      ln.forEach(function (a) { var on = a.getAttribute("href") === "#" + id; a.classList.toggle("on", on); if (on) { a.setAttribute("aria-current", "true"); var ul = sn.querySelector("ul"); ul.scrollTo({ left: a.offsetLeft - 24, behavior: "smooth" }); } else a.removeAttribute("aria-current"); });
    };
    var io = new IntersectionObserver(function (es) { es.forEach(function (e) { if (e.isIntersecting) pilih(e.target.id); }); }, { rootMargin: "-45% 0px -50% 0px" });
    ln.forEach(function (a) { var s = d.getElementById(a.getAttribute("href").slice(1)); if (s) io.observe(s); });
  }
})();

// kartu yang dibuat setelah halaman dimuat (kerja sama) ikut muncul saat digulir
(function () {
  if (matchMedia("(prefers-reduced-motion: reduce)").matches || !("IntersectionObserver" in window)) return;
  var els = [].slice.call(document.querySelectorAll(".ks li, .mitra-g li")).filter(function (e) { return !e.classList.contains("rv"); });
  var io = new IntersectionObserver(function (es) { es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } }); }, { rootMargin: "0px 0px -8% 0px" });
  els.forEach(function (e, i) { e.classList.add("rv"); e.style.transitionDelay = (i % 4) * 80 + "ms"; io.observe(e); });
})();

// Agenda bergambar: foto, judul, tanggal, lokasi. Data dari public_agenda (foto diatur di panel admin > Agenda).
(function () {
  var ev = document.getElementById("ev"); if (!ev) return;
  var C = window.PERKAPI || {}, U = (C.SUPABASE_URL || "").replace(/\/+$/, "");
  var BL = ["Januari","Februari","Maret","April","Mei","Juni","Juli","Agustus","September","Oktober","November","Desember"];
  var esc = function (s) { var d = document.createElement("div"); d.textContent = s == null ? "" : s; return d.innerHTML; };
  var ic = function (n) { return '<svg class="ic" aria-hidden="true" focusable="false"><use href="#i-' + n + '"/></svg>'; };
  var wib = function (d) { var x = new Date(new Date(d).getTime() + 7 * 36e5); return { y: x.getUTCFullYear(), m: x.getUTCMonth(), d: x.getUTCDate(), h: x.getUTCHours(), i: x.getUTCMinutes() }; };
  var foto = function (p) { if (!p) return ""; if (/^(https?:)?\/\//.test(p) || p.charAt(0) === "/") return p; return U + "/storage/v1/object/public/news-photos/" + encodeURI(p); };
  var tanggal = function (a, b) {
    var s = wib(a), e = b ? wib(b) : null;
    if (!e || (e.y === s.y && e.m === s.m && e.d === s.d)) return s.d + " " + BL[s.m] + " " + s.y;
    if (e.y === s.y && e.m === s.m) return s.d + "–" + e.d + " " + BL[s.m] + " " + s.y;
    if (e.y === s.y) return s.d + " " + BL[s.m] + " – " + e.d + " " + BL[e.m] + " " + s.y;
    return s.d + " " + BL[s.m] + " " + s.y + " – " + e.d + " " + BL[e.m] + " " + e.y;
  };
  var jam = function (a, b) {
    var s = wib(a), e = b ? wib(b) : null, f = function (x) { return String(x.h).padStart(2, "0") + "." + String(x.i).padStart(2, "0"); };
    if (!s.h && !s.i) return "";
    return e && (e.h || e.i) ? f(s) + "–" + f(e) + " WIB" : f(s) + " WIB";
  };
  var html = function (v) {
    return v.map(function (x) {
      var src = foto(x.photo_path), j = jam(x.starts_at, x.ends_at);
      return '<article class="rw ev4">' +
        (src ? '<img class="ev4-f" src="' + esc(src) + '" alt="" loading="lazy" width="300" height="300">' : '<span class="ev4-f ev4-kosong" aria-hidden="true"><img src="/img/logo.png" alt="" width="64" height="64"></span>') +
        '<div class="ev4-b"><h2>' + esc(x.title) + '</h2><p class="ev4-m">' +
        '<span>' + ic("calendar-blank") + '<time datetime="' + esc(new Date(x.starts_at).toISOString()) + '">' + tanggal(x.starts_at, x.ends_at) + '</time></span>' +
        (j ? '<span>' + ic("clock") + j + '</span>' : "") +
        (x.location ? '<span>' + ic("map-pin") + esc(x.location) + '</span>' : "") +
        '</p>' + (x.description ? '<p class="ev4-d">' + esc(x.description) + '</p>' : "") + '</div></article>';
    }).join("");
  };
  window.evHtml = html;
  if (typeof rpc !== "function") return;
  rpc("public_agenda", { p_limit: 20 }).then(function (v) { if (v && v.length) ev.innerHTML = html(v); }).catch(function () {});
})();

// Pengaturan dari panel admin (site_settings): status pendaftaran, teks, telepon, pengumuman, beranda, kontak, media sosial.
(function () {
  if (typeof settings !== "function") return;
  var d = document, de = d.documentElement, $ = function (i) { return d.getElementById(i); };
  var esc = function (s) { var x = d.createElement("div"); x.textContent = s == null ? "" : s; return x.innerHTML; };
  var teks = function (id, v) { var e = $(id); if (e && v) e.textContent = v; };
  var waktu = function (s) { return Date.parse(String(s).slice(0, 16) + ":00+07:00"); };
  var telHref = function (n) { var x = String(n).replace(/[^\d+]/g, ""); if (/^0/.test(x)) x = "+62" + x.slice(1); return "tel:" + x; };
  // nomor dalam teks jadi tautan: (021) ... ke telepon, 08... ke WhatsApp
  var tautNomor = function (h) {
    return h.replace(/\(0\d{2,3}\)\s?\d[\d\s-]{5,}\d|\b08\d[\d\s-]{6,}\d/g, function (m) {
      var x = m.replace(/\D/g, "");
      return /^08/.test(x) ? '<a href="https://wa.me/62' + x.slice(1) + '" target="_blank" rel="noopener">' + m + "</a>" : '<a href="' + telHref(m) + '">' + m + "</a>";
    });
  };
  var baris = function (s) { return tautNomor(esc(s)).replace(/\*\*(.+?)\*\*/g, "<b>$1</b>"); };
  // format isi pengumuman: "## Judul", "**tebal**", "- butir", "1. nomor", "1) sub-nomor"
  var isiPengumuman = function (src) {
    var out = "", blok = false, list = null, sub = false;
    var tutupList = function () { if (sub) { out += "</ol>"; sub = false; } if (list) { out += "</li></" + list + ">"; list = null; } };
    var bukaBlok = function () { if (!blok) { out += '<div class="ik-b">'; blok = true; } };
    String(src || "").split(/\r?\n/).forEach(function (l) {
      var t = l.trim(), m;
      if (!t) return;
      if ((m = t.match(/^##\s*(.+)$/))) { tutupList(); if (blok) { out += "</div>"; blok = false; } out += '<h2 class="ik-bar">' + esc(m[1]) + "</h2>"; return; }
      bukaBlok();
      if ((m = t.match(/^(\d+)\)\s*(.+)$/)) && list === "ol") { if (!sub) { out += '<ol class="ik-sub">'; sub = true; } out += "<li>" + baris(m[2]) + "</li>"; return; }
      if ((m = t.match(/^(\d+)\.\s+(.+)$/))) { if (sub) { out += "</ol>"; sub = false; } if (list !== "ol") { tutupList(); out += '<ol class="ik-num">'; list = "ol"; } else out += "</li>"; out += '<li value="' + m[1] + '">' + baris(m[2]); return; }
      if ((m = t.match(/^[-•]\s*(.+)$/))) { if (list !== "ul") { tutupList(); out += '<ul class="ik-dot">'; list = "ul"; } else out += "</li>"; out += "<li>" + baris(m[1]); return; }
      tutupList(); out += "<p>" + baris(t) + "</p>";
    });
    tutupList(); if (blok) out += "</div>";
    return out;
  };
  // halaman yang sedang dibuka dimatikan dari admin: tampilkan pemberitahuan, bukan isi lama
  var halamanTutup = function () {
    var k = (window.PAGE || {}).kind; if (k === "baca") k = "berita";
    var m = d.getElementById("main"); if (!m || !k) return;
    if (!de.classList.contains("off-" + k)) { if (m.dataset.off) location.reload(); return; }
    if (m.dataset.off) return; m.dataset.off = "1";
    m.innerHTML = '<section class="sec"><div class="w hal-off"><h1>Halaman belum tersedia</h1><p>Halaman ini sedang disiapkan oleh sekretariat PERKAPI.</p><a class="btn" href="./">Kembali ke Beranda</a></div></section>';
  };
  halamanTutup();
  settings().then(function (st) {
    st = st || {};
    var p = st.pendaftaran || {};
    if (p.buka || p.tutup || p.mode) {
      try { localStorage.setItem("pk_daftar", JSON.stringify({ mode: p.mode || "otomatis", buka: p.buka, tutup: p.tutup })); } catch (e) {}
      var n = Date.now(), s = p.mode === "buka" ? "buka" : p.mode === "tutup" ? "tutup" : (p.tutup && n >= waktu(p.tutup)) ? "tutup" : (p.buka && n < waktu(p.buka)) ? "segera" : "buka";
      de.classList.toggle("tutup", s === "tutup"); de.classList.toggle("segera", s === "segera");
    }
    teks("pita-buka", de.classList.contains("segera") ? (p.pita_segera || p.pita_buka) : p.pita_buka);
    teks("pita-tutup", p.pita_tutup); teks("lbl-buka", p.label_buka); teks("lbl-tutup", p.label_tutup); teks("ket-tutup", p.ket_tutup);
    if (p.telepon) d.querySelectorAll("a.tel-daftar").forEach(function (a) { a.href = telHref(p.telepon); var t = a.querySelector(".tel-n"); if (t) t.textContent = p.telepon; });
    var b = st.beranda || {}; teks("tagline", b.tagline);
    var hal = st.halaman;
    if (hal) {
      try { localStorage.setItem("pk_hal", JSON.stringify(hal)); } catch (e) {}
      Object.keys(hal).forEach(function (k) { de.classList.toggle("off-" + k, hal[k] === false); });
    }
    halamanTutup();
    var g = st.pengumuman || {};
    if ($("iklan") && g.tampil !== false && g.isi) {
      teks("ik-judul", g.judul); teks("ik-sumber", g.sumber); teks("ik-sub", g.subjudul);
      if (g.kop) $("ik-kop").innerHTML = String(g.kop).split(/\r?\n/).filter(Boolean).map(function (x) { return "<p>" + esc(x) + "</p>"; }).join("");
      $("ik-isi").innerHTML = isiPengumuman(g.isi) + (g.info ? '<p class="ik-info">' + tautNomor(esc(g.info)) + "</p>" : "");
      teks("ik-tgl", g.tanggal); teks("ik-org", g.organisasi);
      if (g.ttd) $("ik-ttd").innerHTML = String(g.ttd).split(/\r?\n/).filter(function (x) { return x.trim(); }).map(function (x) { var q = x.split("|"); return "<div><span>Ttd.</span><b>" + esc(q[0].trim()) + "</b><span>" + esc((q[1] || "").trim()) + "</span></div>"; }).join("");
    }
    var k = st.kontak || {};
    if (k.email && $("f-em")) { $("f-em").href = "mailto:" + k.email; $("f-em").querySelector("span").textContent = k.email; }
    if (k.alamat && $("f-addr")) {
      $("f-addr").querySelector("span").innerHTML = esc(k.alamat).replace(/\n/g, "<br>");
      $("f-addr").href = /^https?:\/\//.test(k.maps || "") ? k.maps : "https://www.google.com/maps/search/?api=1&query=" + encodeURIComponent(k.alamat.replace(/\n/g, " "));
      if ($("f-map")) $("f-map").src = "https://www.google.com/maps?q=" + encodeURIComponent(k.alamat.replace(/\n/g, " ")) + "&z=16&output=embed";
    }
    var so = st.sosial || {};
    d.querySelectorAll("[data-sos]").forEach(function (e) {
      var u = so[e.dataset.sos]; if (!/^https?:\/\//.test(u || "")) return;
      var a = e;
      if (e.tagName !== "A") { a = d.createElement("a"); a.className = e.className; a.dataset.sos = e.dataset.sos; a.innerHTML = e.innerHTML; a.target = "_blank"; a.rel = "noopener"; a.setAttribute("aria-label", (e.getAttribute("aria-label") || "").replace(", segera tersedia", "")); e.replaceWith(a); }
      a.href = u;
    });
  });
})();

// Halaman tambahan (dinyalakan dari admin > Halaman & pendaftaran): kode etik, peraturan, AD/ART, direktori, FAQ, kontak.
(function () {
  var d = document, $ = function (i) { return d.getElementById(i); };
  var esc = function (s) { var x = d.createElement("div"); x.textContent = s == null ? "" : s; return x.innerHTML; };
  var kosong = function (t, p) { return '<div class="kosong"><h2>' + t + "</h2><p>" + p + "</p></div>"; };
  var ada = typeof rpc === "function", st = typeof settings === "function" ? settings() : Promise.resolve({});
  var https = function (u) { return /^https:\/\//.test(String(u || "")); };

  // kode etik: bab dari public_ethics, PDF dan tanggal berlaku dari Pengaturan > Kode etik
  if ($("ke")) {
    st.then(function (s) { var k = (s || {}).kode_etik || {};
      if (https(k.pdf)) { $("kpdf").href = k.pdf; $("kpdf").hidden = false; }
      if (k.berlaku) { $("kber").textContent = "Berlaku sejak " + k.berlaku; $("kber").hidden = false; } });
    (ada ? rpc("public_ethics") : Promise.resolve([])).then(function (r) {
      if (!r || !r.length) { $("ke").innerHTML = kosong("Naskah kode etik sedang disiapkan", "Kode etik profesi akan diterbitkan di halaman ini setelah disahkan."); return; }
      $("ke").innerHTML = r.map(function (x, i) { return '<section id="bab-' + (i + 1) + '"><h2>' + esc(x.title) + "</h2>" + String(x.body || "").split(/\n+/).filter(function (l) { return l.trim(); }).map(function (l) { return "<p>" + esc(l.trim()) + "</p>"; }).join("") + "</section>"; }).join("");
      $("kt").innerHTML = r.map(function (x, i) { return '<li><a href="#bab-' + (i + 1) + '">' + esc(x.title) + "</a></li>"; }).join("");
      $("kt-wrap").hidden = r.length < 2;
    }).catch(function () { $("ke").innerHTML = kosong("Kode etik belum dapat dimuat", "Periksa koneksi Anda lalu muat ulang halaman."); });
  }

  // peraturan: public_regulations (Admin > Peraturan)
  if ($("lawlist")) {
    var semua = [], saring = "";
    var tampil = function () {
      var v = semua.filter(function (x) { return !saring || x.kind === saring; });
      $("lawlist").innerHTML = v.length ? v.map(function (x) {
        var a = (https(x.pdf_url) ? '<a class="link" href="' + esc(x.pdf_url) + '" target="_blank" rel="noopener">Unduh PDF</a>' : "") + (https(x.page_url) ? '<a class="link" href="' + esc(x.page_url) + '" target="_blank" rel="noopener">' + esc(x.page_label || "Lihat sumber") + "</a>" : "");
        return '<article class="law"><span class="tg">' + esc(x.kind === "Rancangan" ? "Dalam pembahasan" : x.kind) + "</span><div><b>" + esc(x.number) + "</b>" + (x.summary ? "<p>" + esc(x.summary) + "</p>" : "") + '</div><span class="act">' + a + "</span></article>";
      }).join("") : kosong("Belum ada peraturan", "Daftar peraturan sedang disiapkan.");
    };
    $("lawf").addEventListener("click", function (e) { var b = e.target.closest("button"); if (!b) return; saring = b.dataset.f; $("lawf").querySelectorAll("button").forEach(function (x) { x.setAttribute("aria-pressed", x === b ? "true" : "false"); }); tampil(); });
    (ada ? rpc("public_regulations") : Promise.resolve([])).then(function (r) { semua = r || []; tampil(); }).catch(function () { $("lawlist").innerHTML = kosong("Peraturan belum dapat dimuat", "Periksa koneksi Anda lalu muat ulang halaman."); });
  }

  // direktori anggota: public_directory (Admin > Direktori)
  if ($("dir")) {
    var off = 0, total = 0, seq = 0, PER = 18;
    var kartu = function (m) {
      var ini = String(m.name || "?").replace(/,.*$/, "").trim().split(/\s+/).map(function (w) { return w[0]; }).slice(0, 2).join("").toUpperCase();
      var aktif = !m.status || m.status === "Aktif";
      return '<article class="mcard"><span class="mav" aria-hidden="true">' + esc(ini) + "</span><div><b>" + esc(m.name) + "</b>" + (m.profession ? "<span>" + esc(m.profession) + "</span>" : "") + (m.city ? "<span>" + esc(m.city) + "</span>" : "") + (m.member_number ? "<span>No. anggota " + esc(m.member_number) + "</span>" : "") + '<span class="mst' + (aktif ? "" : " off") + '">' + esc(m.status || "Aktif") + "</span></div></article>";
    };
    var muat = function (baru) {
      var my = ++seq, q = $("dq").value.trim(); if (baru) off = 0;
      if (!ada) return;
      rpc("public_directory", { p_q: q, p_prof: "", p_limit: PER, p_offset: off }).then(function (r) {
        if (my !== seq) return; r = r || {}; total = r.total || 0;
        var h = (r.rows || []).map(kartu).join("");
        if (baru) $("dir").innerHTML = h || (q ? kosong("Tidak ada yang cocok", "Periksa ejaan nama, atau cari dengan nama kota.") : kosong("Direktori belum berisi data", "Daftar anggota sedang disiapkan oleh sekretariat."));
        else $("dir").insertAdjacentHTML("beforeend", h);
        off += (r.rows || []).length; $("dm").hidden = off >= total;
        $("dn").textContent = total ? total.toLocaleString("id-ID") + " anggota ditemukan" : "";
      }).catch(function () { $("dir").innerHTML = kosong("Direktori belum dapat dimuat", "Periksa koneksi Anda lalu coba lagi."); });
    };
    var tm; $("dq").addEventListener("input", function () { clearTimeout(tm); tm = setTimeout(function () { muat(true); }, 300); });
    $("df").addEventListener("submit", function (e) { e.preventDefault(); muat(true); });
    $("dm").addEventListener("click", function () { muat(false); });
    muat(true);
  }

  // AD/ART: Pengaturan > Profil organisasi (tautan PDF AD/ART)
  if ($("adart")) st.then(function (s) { var te = (s || {}).tentang || {};
    if (!https(te.adart_pdf)) return;
    $("adart").innerHTML = '<span class="doc-ic"><svg class="ic" aria-hidden="true"><use href="#i-file-pdf"/></svg></span><div><h2 class="h3">Anggaran Dasar dan Anggaran Rumah Tangga PERKAPI</h2>' + (te.adart_berlaku ? '<p class="muted">' + esc(te.adart_berlaku) + "</p>" : "") + '<div class="actions"><a class="btn" href="' + esc(te.adart_pdf) + '" target="_blank" rel="noopener">Buka Dokumen</a><a class="btn line" href="' + esc(te.adart_pdf) + '" download>Unduh PDF</a></div></div>'; });

  // kontak: Pengaturan > Kontak, formulir ke Admin > Pesan
  if ($("fk")) {
    st.then(function (s) { var k = (s || {}).kontak || {};
      if (k.alamat) { $("k-al").textContent = k.alamat; $("k-map").href = https(k.maps) ? k.maps : "https://www.google.com/maps/search/?api=1&query=" + encodeURIComponent(k.alamat); }
      if (k.telepon) { $("k-tel").textContent = k.telepon; $("k-tel").href = "tel:" + String(k.telepon).replace(/[^\d+]/g, ""); }
      if (k.email) { $("k-em").textContent = k.email; $("k-em").href = "mailto:" + k.email; }
      var wa = String(k.whatsapp || "").replace(/\D/g, ""); if (/^62\d{8,13}$/.test(wa)) { $("k-wa").href = "https://wa.me/" + wa; $("k-wa").textContent = "+" + wa; $("k-wa-w").hidden = false; } });
    var say = function (t, c) { $("mk").className = "msg " + c; $("mk").textContent = t; $("mk").hidden = false; };
    $("fk").addEventListener("submit", function (e) {
      e.preventDefault(); $("mk").hidden = true;
      var n = $("kn").value.trim(), em = $("ke").value.trim(), p = $("kp").value.trim();
      if (!n || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(em) || p.length < 5) return say("Isi nama, email yang benar, dan pesan minimal 5 huruf.", "er");
      if (!$("kc").checked) return say("Centang persetujuan Kebijakan Privasi.", "er");
      if ($("kh").value) { say("Pesan terkirim. Terima kasih.", "ok"); $("fk").reset(); return; }
      if (!ada) return say("Pesan belum dapat dikirim. Coba lagi nanti.", "er");
      $("kb").disabled = true;
      rpc("kirim_pesan", { p_name: n, p_email: em, p_message: p, p_consent: true }).then(function () { say("Pesan terkirim. Sekretariat akan membalas lewat email Anda.", "ok"); $("fk").reset(); })
        .catch(function (x) { say(x.message || "Pesan gagal dikirim.", "er"); }).then(function () { $("kb").disabled = false; });
    });
  }

  // FAQ: Admin > Halaman & pendaftaran > FAQ. Format: "## Kelompok", "? Pertanyaan", lalu baris jawaban.
  if ($("fqlist")) st.then(function (s) {
    var src = String(((s || {}).faq || {}).isi || ""), gr = [], g = null, q = null;
    src.split(/\r?\n/).forEach(function (l) { var t = l.trim(), m; if (!t) return;
      if ((m = t.match(/^##\s*(.+)/))) { g = { j: m[1], q: [] }; gr.push(g); q = null; return; }
      if (!g) { g = { j: "", q: [] }; gr.push(g); }
      if ((m = t.match(/^\?\s*(.+)/))) { q = { t: m[1], a: [] }; g.q.push(q); return; }
      if (q) q.a.push(t); });
    var ikon = '<svg class="ic" aria-hidden="true"><use href="#i-caret-down"/></svg>';
    $("fqlist").innerHTML = gr.length ? gr.map(function (x) { return '<div class="faq-g">' + (x.j ? "<h2>" + esc(x.j) + "</h2>" : "") + '<div class="qa">' + x.q.map(function (y) { return "<details><summary>" + esc(y.t) + ikon + '</summary><div class="a">' + y.a.map(function (p) { return "<p>" + esc(p) + "</p>"; }).join("") + "</div></details>"; }).join("") + "</div></div>"; }).join("") : kosong("Belum ada pertanyaan", "Daftar pertanyaan sedang disiapkan.");
    var norm = function (s) { return String(s).toLowerCase(); };
    $("fqq").addEventListener("input", function () {
      var w = norm(this.value).split(/\s+/).filter(Boolean), n = 0;
      $("fqlist").querySelectorAll("details").forEach(function (dt) { var ok = w.every(function (k) { return norm(dt.textContent).indexOf(k) > -1; }); dt.hidden = !ok; if (ok) n++; dt.open = !!(w.length && ok); });
      $("fqlist").querySelectorAll(".faq-g").forEach(function (fg) { fg.hidden = !fg.querySelector("details:not([hidden])"); });
      $("fqempty").hidden = n > 0;
    });
  });
})();
