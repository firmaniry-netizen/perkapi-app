import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../core/widgets/smooth_overlays.dart';

/// Kanvas tanda tangan: coretan jari dikonversi ke gambar PNG (latar putih, tinta hitam).
class SignaturePadDialog extends StatefulWidget {
  const SignaturePadDialog({super.key});

  static Future<Uint8List?> show(BuildContext context) =>
      showSmoothDialog<Uint8List>(context: context, builder: (_) => const SignaturePadDialog());

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<List<Offset>> _strokes = [];
  Size _size = const Size(300, 170);
  bool _busy = false;

  Future<void> _done() async {
    if (_strokes.isEmpty) return;
    setState(() => _busy = true);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(Offset.zero & _size, Paint()..color = Colors.white);
    _SigPainter(_strokes).paint(canvas, _size);
    final img = await rec.endRecording().toImage(_size.width.round(), _size.height.round());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (mounted) Navigator.of(context).pop(data?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tanda tangan'),
      content: SizedBox(
        width: 320,
        height: 170,
        child: LayoutBuilder(builder: (_, c) {
          _size = Size(c.maxWidth, c.maxHeight);
          return GestureDetector(
            onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
            onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black26)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(painter: _SigPainter(_strokes), size: Size.infinite),
              ),
            ),
          );
        }),
      ),
      actions: [
        TextButton(onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear), child: const Text('Hapus')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        FilledButton(onPressed: _busy || _strokes.isEmpty ? null : _done, child: const Text('Gunakan')),
      ],
    );
  }
}

class _SigPainter extends CustomPainter {
  _SigPainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, 1.4, Paint()..color = Colors.black);
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (final o in s.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_SigPainter old) => true;
}
