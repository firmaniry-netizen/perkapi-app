import 'package:flutter/material.dart';

import 'motion.dart';

/// Daftar yang menganimasikan masuk, keluar, dan "reflow" — padanan `entering` / `exiting` / `layout`
/// (LinearTransition) di Reanimated, dibuat dengan AnimatedList bawaan Flutter.
/// - Item yang sudah ada saat pertama tampil TIDAK dianimasikan (padanan LayoutAnimationConfig skipEntering).
/// - Item baru: masuk naik 8% + memudar + tingginya membuka (280 ms, ease-out). Item di bawahnya bergeser halus.
/// - Item hilang: menutup + memudar lebih singkat (180 ms, ease-in); item di bawahnya naik mengisi tempatnya.
/// - Urutan berubah total: daftar disusun ulang tanpa animasi (aman, tidak "melompat-lompat").
/// - "Kurangi gerak": semua perubahan instan.
class AnimatedItemsList<T> extends StatefulWidget {
  const AnimatedItemsList({
    super.key,
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.gap = 10,
    this.physics,
    this.controller,
  });

  final List<T> items;
  final Object Function(T item) keyOf;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final EdgeInsetsGeometry padding;
  final double gap;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  @override
  State<AnimatedItemsList<T>> createState() => _AnimatedItemsListState<T>();
}

class _AnimatedItemsListState<T> extends State<AnimatedItemsList<T>> {
  static const _enterDur = Duration(milliseconds: 280);
  static const _exitDur = Duration(milliseconds: 180);
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<T> _shown = List.of(widget.items);

  @override
  void didUpdateWidget(covariant AnimatedItemsList<T> old) {
    super.didUpdateWidget(old);
    final list = _listKey.currentState;
    final still = reduceMotion(context);
    final next = widget.items;
    final nextKeys = next.map(widget.keyOf).toSet();

    // 1) hapus yang hilang (dari belakang agar indeks tetap benar)
    for (var i = _shown.length - 1; i >= 0; i--) {
      if (!nextKeys.contains(widget.keyOf(_shown[i]))) {
        final gone = _shown.removeAt(i);
        list?.removeItem(i, (c, a) => _exit(c, gone, a), duration: still ? Duration.zero : _exitDur);
      }
    }
    // 2) urutan sisa harus sama dengan urutan baru; bila tidak, susun ulang tanpa animasi
    final shownKeys = _shown.map(widget.keyOf).toList();
    final keptInNext = next.map(widget.keyOf).where(shownKeys.contains).toList();
    var sameOrder = shownKeys.length == keptInNext.length;
    for (var i = 0; sameOrder && i < shownKeys.length; i++) {
      if (shownKeys[i] != keptInNext[i]) sameOrder = false;
    }
    if (!sameOrder || list == null) {
      // build() selalu dipanggil setelah didUpdateWidget, jadi cukup ganti datanya (tanpa setState)
      _shown = List.of(next);
      _listKey = GlobalKey<AnimatedListState>();
      return;
    }
    // 3) sisipkan yang baru di posisinya + perbarui data item lama
    for (var i = 0; i < next.length; i++) {
      final k = widget.keyOf(next[i]);
      if (i < _shown.length && widget.keyOf(_shown[i]) == k) {
        _shown[i] = next[i];
      } else {
        _shown.insert(i, next[i]);
        list.insertItem(i, duration: still ? Duration.zero : _enterDur);
      }
    }
  }

  Widget _wrap(BuildContext c, T item) =>
      Padding(padding: EdgeInsets.only(bottom: widget.gap), child: widget.itemBuilder(c, item));

  Widget _enter(BuildContext c, T item, Animation<double> a) {
    final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    return SizeTransition(
      sizeFactor: curved,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
          child: _wrap(c, item),
        ),
      ),
    );
  }

  Widget _exit(BuildContext c, T item, Animation<double> a) {
    // removeItem memutar animasi dari 1 ke 0; ease-in membuat awal pelan, akhir cepat
    final curved = CurvedAnimation(parent: a, curve: Curves.easeIn);
    return SizeTransition(
      sizeFactor: curved,
      axisAlignment: -1,
      child: FadeTransition(opacity: curved, child: IgnorePointer(child: _wrap(c, item))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      controller: widget.controller,
      physics: widget.physics,
      padding: widget.padding,
      initialItemCount: _shown.length,
      itemBuilder: (c, i, a) => _enter(c, _shown[i], a),
    );
  }
}
