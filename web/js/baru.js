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
        var g = a.querySelector(".go"); if (g) g.textContent = "Dokumen MoU menyusul";
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
