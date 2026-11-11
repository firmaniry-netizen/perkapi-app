import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Dialog gaya iOS: judul dan isi rata tengah, lalu tombol selebar dialog yang dipisah garis tipis.
/// Dua tombol tampil berdampingan; satu atau lebih dari dua tombol ditumpuk.
/// Parameter sengaja sama dengan AlertDialog bawaan, jadi pemanggil cukup mengganti nama kelas.
///
/// Tombol di [actions] tetap ditulis sebagai TextButton / FilledButton; dialog ini hanya mengambil
/// `onPressed` dan `child`-nya lalu menggambarnya sendiri: FilledButton = aksi utama (tebal),
/// FilledButton berlatar merah = aksi bahaya (teks merah), TextButton = aksi biasa.
class IosDialog extends StatelessWidget {
  const IosDialog({super.key, this.icon, this.title, this.content, this.actions, this.actionsAlignment});
  final Widget? icon;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  /// Tidak berpengaruh (tombol selalu selebar dialog); ada hanya agar pemanggil lama tidak berubah.
  final MainAxisAlignment? actionsAlignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final line = theme.dividerTheme.color ?? scheme.outline;
    final acts = actions ?? const <Widget>[];
    // Isi berupa teks biasa: rata tengah dan sempit seperti alert iOS. Isi lain (formulir, daftar): rata kiri dan lebih lebar.
    final plain = content == null || content is Text || content is SelectableText;

    Widget action(Widget a) {
      if (a is! ButtonStyleButton) return a;
      final bg = a.style?.backgroundColor?.resolve(const <WidgetState>{});
      final danger = bg == AppColors.red || bg == scheme.error;
      final color = a.onPressed == null
          ? scheme.onSurfaceVariant
          : danger
              ? (dark ? AppColors.redLight : AppColors.red)
              : scheme.primary;
      return InkWell(
        onTap: a.onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 17, fontWeight: a is FilledButton ? FontWeight.w600 : FontWeight.w400, letterSpacing: -0.4),
                child: IconTheme.merge(data: IconThemeData(color: color, size: 18), child: a.child ?? const SizedBox.shrink()),
              ),
            ),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: plain ? 300 : 420),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (icon != null || title != null)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, content == null ? 18 : 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: icon),
                if (title != null)
                  DefaultTextStyle.merge(
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurface, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, height: 1.3),
                    child: title!,
                  ),
              ]),
            ),
          if (content != null)
            Flexible(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, (icon == null && title == null) ? 20 : 0, 20, 18),
                child: DefaultTextStyle.merge(
                  textAlign: plain ? TextAlign.center : TextAlign.start,
                  style: TextStyle(color: scheme.onSurface, fontSize: 14, height: 1.4),
                  child: content!,
                ),
              ),
            ),
          if (acts.isNotEmpty) Divider(height: 1, thickness: 1, color: line),
          if (acts.length == 2)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: action(acts[0])),
                VerticalDivider(width: 1, thickness: 1, color: line),
                Expanded(child: action(acts[1])),
              ]),
            )
          else
            for (var i = 0; i < acts.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: line),
              action(acts[i]),
            ],
        ]),
      ),
    );
  }
}
