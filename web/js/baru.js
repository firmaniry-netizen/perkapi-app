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

  // kerja sama kelembagaan: ketuk kartu untuk membuka PDF MoU. Ubah daftar di sini.
  var ks = d.getElementById("ks");
  if (ks) {
    var MITRA = [
      { nama: "Universitas Hasanuddin", singkat: "UNHAS", kota: "Makassar", pdf: "/dokumen/mou/unhas.pdf", logo: "/img/mitra/unhas.webp" },
      { nama: "Universitas Muhammadiyah Sukabumi", singkat: "UMMI", kota: "Sukabumi", pdf: "/dokumen/mou/ummi.pdf", logo: "/img/mitra/ummi.webp" },
      { nama: "Universitas Muslim Indonesia", singkat: "UMI", kota: "Makassar", pdf: "/dokumen/mou/umi.pdf", logo: "/img/mitra/umi.webp" },
      { nama: "Universitas Malikussaleh", singkat: "UNIMAL", kota: "Lhokseumawe", pdf: "/dokumen/mou/unimal.pdf", logo: "/img/mitra/unimal.webp" }
    ];
    var e = function (s) { var x = d.createElement("div"); x.textContent = s; return x.innerHTML; };
    var tp = d.getElementById("ks-ic"), go = e(ks.getAttribute("data-go") || "") + " " + (tp ? tp.innerHTML : "");
    ks.innerHTML = MITRA.map(function (m, i) {
      return '<li><a href="' + e(m.pdf) + '" target="_blank" rel="noopener">' +
        '<span class="ks-logo"><b>' + e(m.singkat) + '</b><img src="' + e(m.logo) + '" alt="" loading="lazy" decoding="async" onerror="this.remove()" onload="this.parentNode.classList.add(\'img\')"></span>' +
        '<span class="ks-t"><strong>' + e(m.nama) + '</strong><em>' + e(m.kota) + '</em></span><span class="go">' + go + '</span></a></li>';
    }).join("");
    [].forEach.call(ks.querySelectorAll("a"), function (a) {
      fetch(a.getAttribute("href"), { method: "HEAD" }).then(function (r) { if (!r.ok) throw 0; }).catch(function () {
        a.classList.add("soon"); a.removeAttribute("target"); a.setAttribute("aria-disabled", "true");
        var g = a.querySelector(".go"); if (g) g.textContent = "Dokumen MoU Menyusul";
        a.addEventListener("click", function (ev) { ev.preventDefault(); });
      });
    });
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
  var upd = function () { var max = g.scrollWidth - g.clientWidth - 2; bs[0].disabled = g.scrollLeft <= 2; bs[1].disabled = g.scrollLeft >= max; };
  [].forEach.call(bs, function (b) { b.addEventListener("click", function () { var it = g.firstElementChild; var w = it ? it.getBoundingClientRect().width + 20 : g.clientWidth; g.scrollBy({ left: w * +b.dataset.d, behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" }); }); });
  g.addEventListener("scroll", function () { requestAnimationFrame(upd); }, { passive: true });
  new MutationObserver(upd).observe(g, { childList: true }); addEventListener("resize", upd); upd();
})();

// kartu Jelajahi: tombol geser + nilai menyala bergantian
(function () {
  var t = document.getElementById("pc");
  if (t) {
    var bs = document.querySelectorAll('.car-b[data-t="pc"]');
    var upd = function () { var max = t.scrollWidth - t.clientWidth - 2; bs[0].disabled = t.scrollLeft <= 2; bs[1].disabled = t.scrollLeft >= max; };
    [].forEach.call(bs, function (b) { b.addEventListener("click", function () { var c = t.querySelector(".pc"); t.scrollBy({ left: (c ? c.getBoundingClientRect().width + 18 : 300) * +b.dataset.d, behavior: "smooth" }); }); });
    t.addEventListener("scroll", function () { requestAnimationFrame(upd); }, { passive: true }); addEventListener("resize", upd); upd();
  }
  var its = [].slice.call(document.querySelectorAll(".sq-it"));
  if (its.length && "IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (en) { en.forEach(function (e) { e.target.classList.toggle("on", e.isIntersecting); }); }, { rootMargin: "-38% 0px -38% 0px" });
    its.forEach(function (i) { io.observe(i); });
  } else its.forEach(function (i) { i.classList.add("on"); });
})();

// hero: foto berganti pelan (pengganti video latar)
(function () {
  var imgs = [].slice.call(document.querySelectorAll(".pl-hero-bg img"));
  if (imgs.length < 2 || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  var i = 0;
  setInterval(function () {
    if (document.hidden) return;
    var cur = imgs[i]; i = (i + 1) % imgs.length; var nx = imgs[i];
    if (nx.loading === "lazy") nx.loading = "eager";
    nx.classList.remove("on"); void nx.offsetWidth; nx.classList.add("on");
    setTimeout(function () { cur.classList.remove("on"); }, 50);
  }, 7000);
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

// tombol sedikit tertarik ke arah kursor (hanya mouse, tidak saat gerak dikurangi)
(function () {
  if (!matchMedia("(hover: hover) and (pointer: fine)").matches || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  document.addEventListener("pointermove", function (e) {
    var b = e.target.closest && e.target.closest(".btn:not(.is-off), .car-b, .pc-go");
    document.querySelectorAll(".mag").forEach(function (m) { if (m !== b) { m.classList.remove("mag"); m.style.transform = ""; } });
    if (!b) return; var r = b.getBoundingClientRect(), x = e.clientX - (r.left + r.width / 2), y = e.clientY - (r.top + r.height / 2);
    b.classList.add("mag"); b.style.transform = "translate(" + (x * .18).toFixed(1) + "px," + (y * .28).toFixed(1) + "px)";
  });
})();

// revisi 13: gerak ala pliability, digerakkan GSAP + ScrollTrigger + SplitText
(function () {
  var d = document, html = d.documentElement;
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

  // pil ajakan di bawah layar (tanpa GSAP, agar tetap jalan bila pustaka gagal dimuat)
  var kind = (window.PAGE && PAGE.kind) || "";
  if (["pendaftaran", "ujian", "404"].indexOf(kind) < 0) {
    var dk = d.createElement("div"); dk.className = "dock"; dk.setAttribute("role", "region"); dk.setAttribute("aria-label", "Pendaftaran");
    dk.innerHTML = '<span><b>Pendidikan Intensif Angkatan I</b><small>Pendaftaran tahun 2026 telah dibuka</small></span><a class="btn" href="pendaftaran.html">Cara Daftar</a>';
    d.body.appendChild(dk); html.classList.add("has-dock");
    var stop = d.querySelector(".pl-cta, .cta-sec, .ft"), raf = 0;
    var cek = function () { raf = 0; var on = scrollY > innerHeight * .7 && !(stop && stop.getBoundingClientRect().top < innerHeight - 40); dk.classList.toggle("on", on); html.classList.toggle("dock-on", on); };
    addEventListener("scroll", function () { if (!raf) raf = requestAnimationFrame(cek); }, { passive: true }); cek();
  }

  if (reduce || !window.gsap || !window.ScrollTrigger) { [].forEach.call(d.querySelectorAll(".steps-v"), function (o) { o.style.setProperty("--p", 1); }); return; }
  gsap.registerPlugin(ScrollTrigger, window.SplitText || {});
  html.classList.add("gs");
  var E = "expo.out", $$ = function (s, r) { return [].slice.call((r || d).querySelectorAll(s)); };
  var D0 = html.classList.contains("pl-first") ? 1.8 : html.classList.contains("pt-in") ? .45 : 0;
  var mm = gsap.matchMedia();

  // judul bagian: kabur ke tajam, naik pelan (menggantikan muncul bawaan)
  $$(".head > .h2, .split-h > .h2, .faq .h2, .pl-cards-head .h2, .ab-g > .h2, .pl-cta h2").forEach(function (h) {
    h.classList.remove("rv", "in");
    gsap.fromTo(h, { autoAlpha: 0, y: 40, filter: "blur(14px)" }, { autoAlpha: 1, y: 0, filter: "blur(0px)", duration: 1.3, ease: E, clearProps: "filter",
      scrollTrigger: { trigger: h, start: "top 88%", once: true } });
  });

  // paragraf Tentang: kata menyala satu per satu mengikuti gulir
  if (window.SplitText) d.fonts.ready.then(function () {
    $$(".ab-p").forEach(function (p) {
      var sp = SplitText.create(p, { type: "words", wordsClass: "wd" });
      gsap.fromTo(sp.words, { opacity: .14 }, { opacity: 1, stagger: .1, ease: "none",
        scrollTrigger: { trigger: p, start: "top 82%", end: "bottom 45%", scrub: .6 } });
    });
    ScrollTrigger.refresh();
  });

  // hero: teks terangkat dan memudar, bingkai foto melayang lebih lambat
  var hero = d.querySelector(".pl-hero");
  if (hero) {
    gsap.to(".pl-hero-in", { yPercent: -14, autoAlpha: .15, ease: "none", scrollTrigger: { trigger: hero, start: "top top", end: "bottom top", scrub: true } });
    mm.add("(min-width: 761px)", function () {
      gsap.fromTo(".pl-hero-bg", { clipPath: "inset(14% 10% 14% 10% round 44px 6px 6px 6px)" }, { clipPath: "inset(0% 0% 0% 0% round 44px 6px 6px 6px)", duration: 1.6, ease: E, delay: .2 + D0, clearProps: "clipPath" });
      gsap.to(".pl-hero-bg", { yPercent: 10, ease: "none", scrollTrigger: { trigger: hero, start: "top top", end: "bottom top", scrub: true } });
    });
    gsap.from(".pl-proof > *", { y: 30, autoAlpha: 0, stagger: .12, duration: 1.1, ease: E, delay: .7 + D0 });
  }

  // kartu Jelajahi: masuk berurutan dari bawah, foto bergeser di dalam bingkai
  var pcs = $$(".pc");
  if (pcs.length) {
    gsap.from(pcs, { y: 90, autoAlpha: 0, rotate: 2, stagger: .09, duration: 1.3, ease: E, scrollTrigger: { trigger: "#pc", start: "top 85%", once: true } });
    pcs.forEach(function (c) {
      var im = c.querySelector("img"); if (!im) return;
      gsap.fromTo(im, { yPercent: -6, scale: 1.12 }, { yPercent: 6, scale: 1.12, ease: "none", scrollTrigger: { trigger: c, start: "top bottom", end: "bottom top", scrub: true } });
    });
  }

  // Nilai Organisasi: dipin di desktop, nilai menyala satu per satu (seperti stretch / move / recover)
  var seq = d.querySelector(".pl-seq"), its = $$(".sq-it");
  if (seq && its.length) {
    var aktif = function (i) { its.forEach(function (x, k) { x.classList.toggle("act", k === i); }); };
    mm.add("(min-width: 900px)", function () {
      aktif(0);
      ScrollTrigger.create({ trigger: seq, start: "top top", end: "+=" + (its.length * 70) + "%", pin: true, scrub: true,
        onUpdate: function (st) { aktif(Math.min(its.length - 1, Math.floor(st.progress * its.length))); } });
      its.forEach(function (it) { var bb = it.querySelector("b"); if (bb) gsap.from(bb, { x: -60, autoAlpha: 0, duration: 1.2, ease: E, scrollTrigger: { trigger: seq, start: "top 70%", once: true } }); });
      return function () { its.forEach(function (x) { x.classList.remove("act"); }); };
    });
    mm.add("(max-width: 899px)", function () {
      its.forEach(function (it, k) { ScrollTrigger.create({ trigger: it, start: "top 65%", end: "bottom 35%", onToggle: function (st) { if (st.isActive) aktif(k); } }); });
    });
  }

  // Cara Mendaftar: di desktop bagian dipin, garis emas terisi dan langkah menyala bergantian
  $$(".steps-v").forEach(function (ol) {
    var lis = $$("li", ol), sec = ol.closest(".sec");
    var nyala = function (p) { ol.style.setProperty("--p", p.toFixed(3)); lis.forEach(function (li, k) { li.classList.toggle("lit", p >= k / Math.max(1, lis.length - 1) - .02); }); };
    if (sec && sec.id === "cara") {
      mm.add("(min-width: 900px)", function () {
        nyala(0);
        ScrollTrigger.create({ trigger: sec, start: "top top", end: "+=110%", pin: true, scrub: .4, onUpdate: function (st) { nyala(st.progress); } });
      });
      mm.add("(max-width: 899px)", function () {
        ScrollTrigger.create({ trigger: ol, start: "top 70%", end: "bottom 55%", scrub: .4, onUpdate: function (st) { nyala(st.progress); } });
      });
    } else {
      nyala(1);
    }
  });

  // aplikasi: dua layar bergerak berlawanan arah
  $$(".shots .shot").forEach(function (s, i) {
    s.classList.remove("rv", "in");
    gsap.fromTo(s, { y: i ? 120 : 40 }, { y: i ? -40 : -20, ease: "none", scrollTrigger: { trigger: ".shots", start: "top bottom", end: "bottom top", scrub: true } });
  });

  // ajakan akhir: kotak membesar dari tengah saat didekati
  var cta = d.querySelector(".pl-cta");
  if (cta) gsap.fromTo(cta, { clipPath: "inset(8% 6% 8% 6% round 44px)" }, { clipPath: "inset(0% 0% 0% 0% round 0px)", ease: "none", scrollTrigger: { trigger: cta, start: "top bottom", end: "top 30%", scrub: true } });

  // daftar lain: muncul berurutan per kelompok
  ScrollTrigger.batch(".dl, .mq", {
    start: "top 90%", once: true,
    onEnter: function (els) { gsap.from(els, { y: 40, autoAlpha: 0, stagger: .08, duration: 1.1, ease: E, overwrite: true }); }
  });

  // kaca pembesar: foto pengurus bisa diperbesar dengan kursor
  mm.add("(hover: hover) and (pointer: fine)", function () {
    $$(".wide-photo").forEach(function (box) {
      var im = box.querySelector("img"); if (!im || box.classList.contains("zoomable")) return;
      box.classList.add("zoomable");
      var ln = d.createElement("span"); ln.className = "lens"; box.appendChild(ln);
      var hint = d.createElement("span"); hint.className = "zoom-hint"; hint.textContent = "Arahkan kursor untuk memperbesar"; box.appendChild(hint);
      var Z = 2.4, src = "/img/pengurus-2026.jpg"; gsap.set(ln, { scale: .6 });
      var xTo = gsap.quickTo(ln, "x", { duration: .35, ease: "power3" }), yTo = gsap.quickTo(ln, "y", { duration: .35, ease: "power3" });
      box.addEventListener("pointerenter", function () { ln.style.backgroundImage = "url(" + (im.currentSrc && im.currentSrc.indexOf("-900") < 0 ? im.currentSrc : src) + ")"; box.classList.add("on"); gsap.to(ln, { scale: 1, duration: .5, ease: "back.out(2)" }); });
      box.addEventListener("pointerleave", function () { box.classList.remove("on"); gsap.to(ln, { scale: .6, duration: .3 }); });
      box.addEventListener("pointermove", function (e) {
        var r = im.getBoundingClientRect(), x = e.clientX - r.left, y = e.clientY - r.top;
        xTo(x - 95); yTo(y - 95 + (im.offsetTop || 0));
        ln.style.backgroundSize = (r.width * Z) + "px " + (r.height * Z) + "px";
        ln.style.backgroundPosition = (-(x * Z - 95)) + "px " + (-(y * Z - 95)) + "px";
      });
    });
  });

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


  // pembatas belah ketupat di antara bagian
  $$("main > section + section").forEach(function (sec) {
    if (sec.previousElementSibling && sec.previousElementSibling.classList.contains("pl-hero")) return;
    var dv = d.createElement("div"); dv.className = "dv"; dv.setAttribute("aria-hidden", "true"); sec.parentNode.insertBefore(dv, sec);
    ScrollTrigger.create({ trigger: dv, start: "top 92%", once: true, onEnter: function () { dv.classList.add("in"); } });
  });

  // judul halaman dalam (Tentang, Pendaftaran, Agenda): kata naik dari balik garis
  $$(".ph h1").forEach(function (h) {
    h.classList.remove("rv", "in");
    if (!window.SplitText) return;
    d.fonts.ready.then(function () {
      var sp = SplitText.create(h, { type: "words", wordsClass: "wd" });
      sp.words.forEach(function (w) { var o = d.createElement("span"); o.className = "wd-o"; w.parentNode.insertBefore(o, w); o.appendChild(w); });
      gsap.from(sp.words, { yPercent: 110, duration: 1.2, ease: E, stagger: .07, delay: .15 + D0 });
    });
  });
  $$(".ph .photo").forEach(function (ph) {
    ph.classList.remove("rv", "in", "rv-c");
    gsap.fromTo(ph, { clipPath: "inset(10% 8% 10% 8% round 44px 6px 6px 6px)" }, { clipPath: "inset(0% 0% 0% 0% round 44px 6px 6px 6px)", duration: 1.5, ease: E, delay: .3 + D0, clearProps: "clipPath" });
    var im = ph.querySelector("img"); if (im) gsap.fromTo(im, { scale: 1.15 }, { scale: 1, duration: 2, ease: E, delay: .3 + D0 });
  });

  // angka papan skor
  $$(".pl-proof b").forEach(function (b, k) {
    if (!/\d/.test(b.textContent)) return;
    b.setAttribute("aria-label", b.textContent);
    b.innerHTML = b.textContent.split("").map(function (c) {
      if (!/\d/.test(c)) return '<span aria-hidden="true">' + c + "</span>";
      var col = ""; for (var i = 0; i <= 9; i++) col += "<i>" + i + "</i>"; col += col;
      return '<span class="od" aria-hidden="true" data-n="' + c + '"><span class="od-r">' + col + "</span></span>";
    }).join("");
    $$(".od", b).forEach(function (o, i) {
      var n = +o.dataset.n; gsap.fromTo(o.firstChild, { yPercent: 0 }, { yPercent: -(10 + n) * 5, duration: 1.6 + i * .15, ease: "power4.out", delay: .9 + D0 + k * .15 });
    });
  });

  // kartu Jelajahi: seret dengan mouse, meluncur dengan inersia
  $$(".pc-track").forEach(function (tr) {
    if (!matchMedia("(hover: hover) and (pointer: fine)").matches) return;
    var down = false, moved = 0, x0 = 0, s0 = 0, v = 0, lx = 0, lt = 0, raf2 = 0;
    tr.addEventListener("pointerdown", function (e) { if (e.button) return; down = true; moved = 0; x0 = lx = e.clientX; lt = performance.now(); s0 = tr.scrollLeft; v = 0; cancelAnimationFrame(raf2); });
    addEventListener("pointermove", function (e) {
      if (!down) return; var dx = e.clientX - x0; moved = Math.max(moved, Math.abs(dx));
      if (moved > 5) tr.classList.add("drag");
      var now = performance.now(); v = (e.clientX - lx) / Math.max(1, now - lt); lx = e.clientX; lt = now;
      tr.scrollLeft = s0 - dx;
    });
    addEventListener("pointerup", function () {
      if (!down) return; down = false;
      var vel = -v * 16;
      var glide = function () { vel *= .94; tr.scrollLeft += vel; if (Math.abs(vel) > .4) raf2 = requestAnimationFrame(glide); else tr.classList.remove("drag"); };
      if (moved > 5) glide(); else tr.classList.remove("drag");
    });
    tr.addEventListener("click", function (e) { if (moved > 5) { e.preventDefault(); e.stopPropagation(); } }, true);
  });

  // pita logo mitra: digerakkan GSAP, melambat saat disentuh
  $$(".marquee").forEach(function (mq) {
    var tr = mq.querySelector(".mq-track"); if (!tr) return;
    var tw = gsap.to(tr, { xPercent: -50, duration: 34, ease: "none", repeat: -1 });
    mq.addEventListener("pointerenter", function () { gsap.to(tw, { timeScale: .15, duration: .8 }); });
    mq.addEventListener("pointerleave", function () { gsap.to(tw, { timeScale: 1, duration: .8 }); });
  });

  // footer: kata PERKAPI naik pelan saat terlihat
  $$(".ft-word span").forEach(function (w) { gsap.from(w, { yPercent: 35, autoAlpha: 0, duration: 1.6, ease: E, scrollTrigger: { trigger: w, start: "top 98%", once: true } }); });

  addEventListener("load", function () { ScrollTrigger.refresh(); });
})();
