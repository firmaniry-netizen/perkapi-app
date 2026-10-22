import 'package:flutter/material.dart';

/// Tinggi bar navigasi mengambang (kapsul 64 + jarak bawah 12) di AppShell.
/// Halaman di dalam ShellRoute memakai Scaffold sendiri, sehingga FAB-nya tidak tahu ada bar itu
/// dan tertimpa di bawahnya. Bungkus FAB dengan [NavClearance] agar mengambang di atas bar.
const double kFloatNavHeight = 76;

class NavClearance extends StatelessWidget {
  const NavClearance({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(padding: EdgeInsets.only(bottom: kFloatNavHeight + bottom), child: child);
  }
}
