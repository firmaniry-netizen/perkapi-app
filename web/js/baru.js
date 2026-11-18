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
  if (false) {
    tandai(".head > *, .split-h > *, .join > div > *, .faq > div:first-child > *, .ph .crumb, .ph h1, .ph .lead, .reg-side > *, .exam-note, .cta, .quote");
    tandai(".vals > div, .prows li, .go2-it", "rv-l");
    tandai(".role, .steps-v li, .qa details, .feat li, .stores, .app-note, .shot", "");
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

  // 404: lambang miring mengikuti kursor, klik untuk mengecap
  var em = d.querySelector(".emblem");
  if (em) {
    var inner = d.createElement("div"); inner.className = "emblem-in";
    while (em.firstChild) inner.appendChild(em.firstChild); em.appendChild(inner);
    var rx = gsap.quickTo(inner, "rotationX", { duration: .6, ease: "power3" }), ry = gsap.quickTo(inner, "rotationY", { duration: .6, ease: "power3" });
    addEventListener("pointermove", function (e) { var r = em.getBoundingClientRect(); ry(((e.clientX - (r.left + r.width / 2)) / innerWidth) * 40); rx((-(e.clientY - (r.top + r.height / 2)) / innerHeight) * 40); });
    em.addEventListener("click", function () {
      gsap.fromTo(inner, { scale: .9 }, { scale: 1, duration: .6, ease: "elastic.out(1,.4)" });
      var st = d.createElement("div"); st.className = "stamp"; st.innerHTML = "<span>Halaman<br>Tidak<br>Ditemukan</span>"; inner.appendChild(st);
      gsap.fromTo(st, { xPercent: -50, yPercent: -50, scale: 2.4, rotation: gsap.utils.random(-28, 28), opacity: 0 }, { scale: 1, opacity: .85, duration: .35, ease: "power4.in",
        onComplete: function () { gsap.to(st, { opacity: 0, duration: 1.2, delay: 1.4, onComplete: function () { st.remove(); } }); } });
    });
    var tip = d.createElement("p"); tip.className = "emblem-tip"; tip.textContent = "Klik lambang untuk mengecap"; em.appendChild(tip);
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
