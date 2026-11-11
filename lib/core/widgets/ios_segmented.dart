import 'package:flutter/cupertino.dart' show CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';

/// Kontrol segmen gaya iOS (ibu jari putih yang meluncur). Parameter sengaja sama dengan SegmentedButton
/// bawaan, jadi pemanggil cukup mengganti nama kelas. Hanya pilihan tunggal.
class IosSegmentedButton<T extends Object> extends StatelessWidget {
  const IosSegmentedButton({super.key, required this.segments, required this.selected, this.onSelectionChanged});
  final List<ButtonSegment<T>> segments;

  /// Kosong = belum ada yang dipilih.
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<T>(
      groupValue: selected.isEmpty ? null : selected.first,
      onValueChanged: (v) {
        if (v != null) onSelectionChanged?.call({v});
      },
      children: {
        for (final s in segments)
          s.value: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            // Label panjang di layar sempit mengecil, tidak terpotong.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (s.icon != null) ...[
                  IconTheme.merge(data: const IconThemeData(size: 16), child: s.icon!),
                  const SizedBox(width: 6),
                ],
                if (s.label != null) s.label!,
              ]),
            ),
          ),
      },
    );
  }
}
