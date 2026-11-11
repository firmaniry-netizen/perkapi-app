import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/shell/nav_items.dart';

/// Tinggi tab bar gaya iOS di AppShell (tanpa area aman bawah).
/// Halaman di dalam ShellRoute memakai Scaffold sendiri, sehingga FAB-nya tidak tahu ada bar itu
/// dan tertimpa di bawahnya. Bungkus FAB dengan [NavClearance] agar mengambang di atas bar.
const double kFloatNavHeight = 50;

class NavClearance extends StatelessWidget {
  const NavClearance({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Bar hanya ada di halaman utama (lihat isTopLevelRoute); di halaman fitur tidak perlu jarak tambahan.
    var top = true;
    try {
      top = isTopLevelRoute(GoRouterState.of(context).uri.path);
    } catch (_) {}
    if (!top) return child;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(padding: EdgeInsets.only(bottom: kFloatNavHeight + bottom), child: child);
  }
}
