class AppAssets {
  AppAssets._();

  // Logo PERKAPI (latar terang). Dipakai juga di latar gelap bila versi gelap tidak ada.
  static const logoPerkapi = 'images/logo_perkapi.png'; // logo resmi baru (sama dengan situs), 1024 px

  // Versi khusus latar gelap (opsional). Jika file ini tidak ada, aplikasi otomatis
  // memakai logoPerkapi di dalam kotak putih membulat.
  static const logoPerkapiDark = 'images/logo_perkapi_dark.png';

  // Logo mitra/instansi (yang file-nya tidak ada akan dilewati otomatis).
  static const logoGovernment = 'images/logo_government.png';
  static const logoAhu = 'images/Logo_Kumham_AHU.png';
  static const logoKementerian = 'images/logo_kementerian.png';

  // Foto latar (opsional; panduan di docs/GAMBAR.md). Bila file tidak ada, tampilan tetap dongker polos.
  static const heroLogin = 'images/hero_login.jpg'; // latar halaman masuk
  static const heroMember = 'images/hero_member.jpg'; // kartu anggota dashboard + kepala layar dalam

  // Gambar latar berita (opsional). Jika file tidak ada, sampul memakai gradasi dongker saja.
  static const newsPlaceholder = 'images/news_placeholder.jpg';
}
