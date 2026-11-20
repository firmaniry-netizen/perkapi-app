// Pendaftaran, pengumuman koran, dan beranda (site_settings: pendaftaran, pengumuman, beranda)
async function daftarSet(){var s={};(await api("GET","site_settings?select=*&key=in.(pendaftaran,pengumuman,beranda)")).forEach(function(x){s[x.key]=x.value||{}});
  var p=s.pendaftaran||{},g=s.pengumuman||{},br=s.beranda||{},h=function(t){return'<p style="font-size:13px;color:#59627a;margin:0 0 6px">'+t+"</p>"};
  V.innerHTML='<h2>Pendaftaran &amp; pengumuman</h2><div class="g2">'
  +'<form id="pdf"><h3>Status pendaftaran</h3>'+h("Mode otomatis: sebelum waktu buka tampil teks \"segera dibuka\", di antara buka dan tutup tampil \"dibuka\", setelah waktu tutup tampil \"ditutup\". Waktu dalam WIB.")
  +'<label>Mode</label><select id="d_mode"><option value="otomatis">Otomatis mengikuti tanggal</option><option value="buka">Selalu dibuka</option><option value="tutup">Ditutup sekarang</option></select>'
  +'<label>Dibuka mulai (WIB)</label><input id="d_buka" type="datetime-local"><label>Ditutup pada (WIB)</label><input id="d_tutup" type="datetime-local">'
  +'<label>Nomor telepon pendaftaran (tampil di tombol telepon)</label><input id="d_telepon" placeholder="(021) 39711824">'
  +'<label>Teks pita atas sebelum dibuka</label><input id="d_pita_segera"><label>Teks pita atas saat dibuka</label><input id="d_pita_buka"><label>Teks pita atas saat ditutup</label><input id="d_pita_tutup">'
  +'<label>Label beranda saat dibuka</label><input id="d_label_buka"><label>Label beranda saat ditutup</label><input id="d_label_tutup">'
  +'<label>Keterangan di halaman Pendaftaran saat ditutup</label><textarea id="d_ket_tutup"></textarea>'
  +'<p><button class="b">Simpan pendaftaran</button></p></form>'
  +'<form id="pbr"><h3>Beranda</h3><label>Kalimat di bawah judul beranda</label><input id="b_tagline"><p><button class="b">Simpan beranda</button></p>'
  +'<h3 style="margin-top:22px">Cara menulis isi pengumuman</h3>'+h("<b>## Judul</b> = bar hitam judul bagian<br><b>**teks**</b> = baris tebal<br><b>- teks</b> = butir titik<br><b>1. teks</b> = butir bernomor<br><b>1) teks</b> = sub-butir di bawah butir bernomor<br>Baris lain = paragraf biasa. Nomor telepon (021) ... dan 08... otomatis jadi tautan.")+'<p><a class="b l" href="/pengumuman.html" target="_blank" rel="noopener">Lihat halaman pengumuman</a></p></form>'
  +'<form id="pgm" style="grid-column:1/-1"><h3>Pengumuman koran (halaman Pengumuman)</h3>'
  +'<label><input type="checkbox" id="g_tampil"> Pakai isi dari panel ini (matikan untuk memakai isi bawaan situs)</label>'
  +'<label>Judul atas</label><input id="g_judul" placeholder="Pengumuman Koran"><label>Sumber dan tanggal terbit</label><input id="g_sumber" placeholder="Harian Kompas, Jum\'at, 20 November 2026"><label>Subjudul</label><input id="g_subjudul">'
  +'<label>Kop di dalam kotak (satu baris per baris)</label><textarea id="g_kop" style="min-height:130px"></textarea>'
  +'<label>Isi pengumuman</label><textarea id="g_isi" style="min-height:460px;font-family:ui-monospace,Consolas,monospace;font-size:13.5px"></textarea>'
  +'<label>Kalimat informasi di akhir</label><textarea id="g_info"></textarea>'
  +'<label>Tempat dan tanggal</label><input id="g_tanggal" placeholder="Jakarta, 20 November 2026"><label>Nama organisasi</label><input id="g_organisasi">'
  +'<label>Tanda tangan (satu baris per orang: NAMA | Jabatan, urut kiri ke kanan)</label><textarea id="g_ttd" style="min-height:90px"></textarea>'
  +'<p><button class="b">Simpan pengumuman</button></p></form></div>';
  ["mode","buka","tutup","telepon","pita_segera","pita_buka","pita_tutup","label_buka","label_tutup","ket_tutup"].forEach(function(n){$("d_"+n).value=p[n]||(n=="mode"?"otomatis":"")});
  ["judul","sumber","subjudul","kop","isi","info","tanggal","organisasi","ttd"].forEach(function(n){$("g_"+n).value=g[n]||""});$("g_tampil").checked=g.tampil!==false;
  $("b_tagline").value=br.tagline||"";
  $("pdf").onsubmit=function(ev){ev.preventDefault();var v={};["mode","buka","tutup","telepon","pita_segera","pita_buka","pita_tutup","label_buka","label_tutup","ket_tutup"].forEach(function(n){v[n]=$("d_"+n).value.trim()});
    if(v.buka&&v.tutup&&v.tutup<=v.buka)return note("Waktu tutup harus setelah waktu buka.","er");simpan("pendaftaran",v)};
  $("pbr").onsubmit=function(ev){ev.preventDefault();simpan("beranda",{tagline:$("b_tagline").value.trim()})};
  $("pgm").onsubmit=function(ev){ev.preventDefault();var v={tampil:$("g_tampil").checked};["judul","sumber","subjudul","kop","isi","info","tanggal","organisasi","ttd"].forEach(function(n){v[n]=$("g_"+n).value.trim()});simpan("pengumuman",v)}}
