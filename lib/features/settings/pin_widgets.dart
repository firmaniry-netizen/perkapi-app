import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/pin_service.dart';
import '../../core/widgets/smooth_overlays.dart';

/// Keypad PIN untuk layar kunci aplikasi (tampil di atas latar gelap).
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onUnlocked, required this.onTooMany});
  final VoidCallback onUnlocked, onTooMany;
  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  int _attempts = 0;
  String? _error;
  bool _checking = false;

  Future<void> _tap(String d) async {
    if (_checking || _pin.length >= PinService.length) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == PinService.length) {
      _checking = true;
      final ok = await PinService.verify(_pin);
      _checking = false;
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
        return;
      }
      _attempts++;
      if (_attempts >= PinService.maxAttempts) {
        widget.onTooMany();
        return;
      }
      setState(() {
        _pin = '';
        _error = 'PIN salah. Sisa percobaan: ${PinService.maxAttempts - _attempts}';
      });
    }
  }

  void _back() {
    if (_pin.isEmpty || _checking) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _key(String label, {VoidCallback? onTap, IconData? icon}) => Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 64,
          height: 56,
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: onTap,
            child: icon != null ? Icon(icon) : Text(label, style: const TextStyle(fontSize: 22)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < PinService.length; i++)
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _pin.length ? Colors.white : Colors.transparent,
              border: Border.all(color: Colors.white70),
            ),
          ),
      ]),
      SizedBox(
        height: 28,
        child: Center(child: Text(_error ?? '', style: const TextStyle(color: Color(0xFFFFAB91), fontSize: 12))),
      ),
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final d in row) _key(d, onTap: () => _tap(d)),
        ]),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _key(''),
        _key('0', onTap: () => _tap('0')),
        _key('', icon: Icons.backspace_outlined, onTap: _back),
      ]),
    ]);
  }
}

/// Dialog buat PIN baru (2x input). Mengembalikan PIN bila valid, null bila batal.
Future<String?> showPinSetupDialog(BuildContext context) {
  final a = TextEditingController();
  final b = TextEditingController();
  String? err;
  return showSmoothDialog<String>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setS) => AlertDialog(
        title: const Text('Buat PIN aplikasi'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: a,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: PinService.length,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'PIN 6 digit', counterText: ''),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: b,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: PinService.length,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'Ulangi PIN', counterText: '', errorText: err),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () {
              if (a.text.length != PinService.length) {
                setS(() => err = 'PIN harus ${PinService.length} digit');
              } else if (PinService.isWeak(a.text)) {
                setS(() => err = 'PIN terlalu mudah ditebak');
              } else if (a.text != b.text) {
                setS(() => err = 'PIN tidak sama');
              } else {
                Navigator.pop(d, a.text);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}

/// Dialog konfirmasi PIN saat ini (untuk menonaktifkan). true bila benar.
Future<bool> showPinConfirmDialog(BuildContext context) async {
  final c = TextEditingController();
  String? err;
  final ok = await showSmoothDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setS) => AlertDialog(
        title: const Text('Masukkan PIN saat ini'),
        content: TextField(
          controller: c,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: PinService.length,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: 'PIN', counterText: '', errorText: err),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () async {
              if (await PinService.verify(c.text)) {
                if (d.mounted) Navigator.pop(d, true);
              } else {
                setS(() => err = 'PIN salah');
              }
            },
            child: const Text('Lanjut'),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}
