import 'package:flutter/material.dart';

import 'motion.dart';

/// Overlay PERKAPI yang halus: kurva "expo-out" (cepat di awal, mendarat lembut), tutup lebih singkat
/// dari buka, scrim dongker. Mati (durasi 0) saat Reduce Motion aktif.
const Curve _land = Cubic(0.16, 1, 0.3, 1);
const Color _scrim = Color(0x99061230);

/// Pengganti showModalBottomSheet: naik 460 ms, turun 280 ms.
Future<T?> showSmoothSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
  bool useSafeArea = false,
}) {
  final still = reduceMotion(context);
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    barrierColor: _scrim,
    sheetAnimationStyle: AnimationStyle(
      duration: still ? Duration.zero : const Duration(milliseconds: 460),
      reverseDuration: still ? Duration.zero : const Duration(milliseconds: 280),
      curve: _land,
      reverseCurve: Curves.easeInCubic,
    ),
  );
}

/// Pengganti showDialog: fade + naik 4% + skala 0,92 ke 1 dengan kurva mendarat lembut (320 ms).
Future<T?> showSmoothDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final still = reduceMotion(context);
  final navContext = Navigator.of(context, rootNavigator: true).context;
  final themes = InheritedTheme.capture(from: context, to: navContext);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: _scrim,
    transitionDuration: still ? Duration.zero : const Duration(milliseconds: 320),
    pageBuilder: (ctx, _, __) => themes.wrap(SafeArea(child: Builder(builder: builder))),
    transitionBuilder: (ctx, anim, _, child) {
      final move = CurvedAnimation(parent: anim, curve: _land, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(move),
          child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(move), child: child),
        ),
      );
    },
  );
}
