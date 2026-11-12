import 'package:flutter/material.dart';

import 'liquid_glass.dart';
import 'motion.dart';

/// Kontrol segmen gaya iOS 26/27: jalur kapsul abu tembus, ibu jari kapsul kaca yang meluncur dengan pegas
/// ke segmen terpilih. Semua segmen sama lebar (selebar label terpanjang); label panjang mengecil, tidak terpotong.
/// Parameter sengaja sama dengan SegmentedButton bawaan, jadi pemanggil cukup mengganti nama kelas. Pilihan tunggal.
class IosSegmentedButton<T extends Object> extends StatelessWidget {
  const IosSegmentedButton({super.key, required this.segments, required this.selected, this.onSelectionChanged});
  final List<ButtonSegment<T>> segments;

  /// Kosong = belum ada yang dipilih (ibu jari disembunyikan).
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final still = MediaQuery.disableAnimationsOf(context);
    final n = segments.length;
    final at = selected.isEmpty ? -1 : segments.indexWhere((s) => s.value == selected.first);

    Widget segment(int i) {
      final s = segments[i];
      final on = i == at;
      final color = s.enabled ? scheme.onSurface : scheme.onSurfaceVariant;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: (!s.enabled || on || onSelectionChanged == null)
                ? null
                : () {
                    tapHaptic();
                    onSelectionChanged!({s.value});
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (s.icon != null) ...[
                    IconTheme.merge(data: IconThemeData(size: 16, color: color), child: s.icon!),
                    if (s.label != null) const SizedBox(width: 6),
                  ],
                  if (s.label != null)
                    DefaultTextStyle.merge(
                      style: TextStyle(color: color, fontSize: 14, fontWeight: on ? FontWeight.w600 : FontWeight.w500, letterSpacing: -0.2),
                      child: s.label!,
                    ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: ShapeDecoration(
          color: scheme.onSurface.withValues(alpha: dark ? 0.16 : 0.07),
          shape: const StadiumBorder(),
        ),
        child: Stack(children: [
          // Ibu jari di lapisan Positioned supaya tidak ikut menentukan lebar kontrol.
          if (at >= 0 && n > 0)
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(n == 1 ? 0 : -1 + 2 * at / (n - 1), 0),
                duration: Duration(milliseconds: still ? 0 : 380),
                curve: const Cubic(0.34, 1.36, 0.64, 1),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: dark ? const Color(0xFF5A5F6B) : Colors.white,
                      shape: const StadiumBorder(),
                      shadows: [
                        BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.30 : 0.10), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: CustomPaint(foregroundPainter: GlassSheen(dark: dark, radius: 999, strength: 0.7)),
                  ),
                ),
              ),
            ),
          Row(children: [for (var i = 0; i < n; i++) segment(i)]),
        ]),
      ),
    );
  }
}
