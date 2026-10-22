import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_repository.dart';

/// Login dengan kode OTP yang dikirim ke email (tanpa password).
/// Setelah verifikasi berhasil, router otomatis membuka dashboard.
class OtpDialog extends StatefulWidget {
  const OtpDialog({super.key, this.initialEmail = ''});
  final String initialEmail;
  @override
  State<OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<OtpDialog> {
  final _repo = AuthRepository();
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  bool _sent = false, _busy = false;
  String? _error, _info;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final e = _email.text.trim();
    if (!e.contains('@')) {
      setState(() => _error = 'Masukkan email yang valid.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.sendEmailOtp(e);
      if (mounted) {
        setState(() {
          _sent = true;
          _info = 'Jika email terdaftar, kode telah dikirim. Periksa kotak masuk/spam.';
        });
      }
    } on AuthFailure catch (ex) {
      if (mounted) setState(() => _error = ex.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final c = _code.text.trim();
    if (c.length < 6) {
      setState(() => _error = 'Masukkan kode dari email (6 digit atau lebih).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.verifyEmailOtp(_email.text, c);
      if (mounted) Navigator.of(context).pop();
    } on AuthFailure catch (ex) {
      if (mounted) setState(() => _error = ex.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Masuk dengan kode email'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _email,
            enabled: !_sent && !_busy,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email akun', prefixIcon: Icon(Icons.email_outlined)),
          ),
          if (_sent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              enabled: !_busy,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _verify(),
              decoration: const InputDecoration(labelText: 'Kode dari email', counterText: ''),
            ),
          ],
          if (_info != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_info!, style: const TextStyle(fontSize: 12))),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFC62828)))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: _busy ? null : (_sent ? _verify : _send),
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_sent ? 'Verifikasi' : 'Kirim kode'),
        ),
      ],
    );
  }
}
