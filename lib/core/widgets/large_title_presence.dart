import 'package:flutter/widgets.dart';

final _presence = Expando<ValueNotifier<bool>>();

/// Penanda per halaman (rute): true bila isi halaman menampilkan judul besar (ScreenHero).
/// GlassAppBar membacanya supaya judul tidak tampil dua kali: selama judul besar terlihat, judul di bar
/// disembunyikan, lalu muncul saat isi digulir. Memakai Expando, jadi ikut terhapus bersama rutenya.
ValueNotifier<bool> largeTitleOn(Object route) => _presence[route] ??= ValueNotifier<bool>(false);
