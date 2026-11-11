import 'package:flutter/material.dart';

import '../constants/phosphor_icons.dart';
import 'smooth_overlays.dart';

/// Kolom pilihan gaya iOS: tampil seperti kolom isian, ditekan membuka lembar bawah berisi daftar pilihan
/// (yang terpilih bertanda centang). Parameter sengaja sama dengan DropdownButtonFormField bawaan, jadi
/// pemanggil cukup mengganti nama kelas. Nilai dikendalikan pemanggil: perbarui [value] di [onChanged].
class IosSelectField<T> extends StatelessWidget {
  const IosSelectField({
    super.key,
    this.value,
    this.initialValue,
    required this.items,
    this.onChanged,
    this.decoration = const InputDecoration(),
    this.validator,
    this.isExpanded = true,
  });
  final T? value;
  final T? initialValue;
  final List<DropdownMenuItem<T>> items;

  /// Null = kolom nonaktif.
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final FormFieldValidator<T>? validator;

  /// Tidak berpengaruh (kolom selalu selebar induknya); ada hanya agar pemanggil lama tidak berubah.
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final current = value ?? initialValue;
    return FormField<T>(
      // Kunci berganti saat nilai berganti, supaya nilai di dalam Form selalu sama dengan nilai pemanggil.
      key: ValueKey<T?>(current),
      initialValue: current,
      validator: validator,
      builder: (state) {
        final theme = Theme.of(context);
        final enabled = onChanged != null;
        Widget? label;
        for (final i in items) {
          if (i.value == current) {
            label = i.child;
            break;
          }
        }

        Future<void> pick() async {
          // Dibungkus record supaya pilihan bernilai null bisa dibedakan dari lembar yang ditutup.
          final picked = await showSmoothSheet<(T?,)>(
            context: context,
            builder: (ctx) => SafeArea(
              top: false,
              child: ListView(shrinkWrap: true, children: [
                for (final i in items)
                  ListTile(
                    title: i.child,
                    trailing: i.value == current ? Icon(Ph.check, color: theme.colorScheme.primary) : null,
                    onTap: () => Navigator.pop(ctx, (i.value,)),
                  ),
              ]),
            ),
          );
          if (picked == null) return;
          state.didChange(picked.$1);
          onChanged?.call(picked.$1);
        }

        return Opacity(
          opacity: enabled ? 1 : 0.5,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? pick : null,
            child: InputDecorator(
              decoration: decoration.copyWith(errorText: state.errorText, suffixIcon: const Icon(Ph.caretUpDown, size: 18)),
              isEmpty: label == null,
              child: label == null ? null : DefaultTextStyle.merge(maxLines: 1, overflow: TextOverflow.ellipsis, child: label),
            ),
          ),
        );
      },
    );
  }
}
