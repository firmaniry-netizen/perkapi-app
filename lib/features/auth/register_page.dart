import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/perkapi_logo.dart';
import '../../core/widgets/ui_kit.dart';
import 'auth_repository.dart';

/// Pendaftaran mandiri. Akun baru berstatus "menunggu" sampai admin utama menyetujui.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _repo = AuthRepository();

  List<Map<String, dynamic>> _branches = [];
  String? _branchId;
  bool _loading = false;
  bool _obscure = true;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo.publicBranches().then((b) {
      if (mounted) setState(() => _branches = b);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repo.register(
        fullName: _name.text,
        email: _email.text,
        password: _pw.text,
        phone: _phone.text,
        branchId: _branchId,
      );
      if (mounted) setState(() => _done = true);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: dark ? AppColors.navyDeep : AppColors.navy,
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 24, 12),
                  child: Row(children: [
                    IconButton(
                      tooltip: 'Kembali',
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _loading ? null : _backToLogin,
                    ),
                    const SizedBox(width: 4),
                    const PerkapiLogo(size: 40, onDark: true, animate: true),
                    const SizedBox(width: 12),
                    const Wordmark(size: 22, color: Colors.white),
                  ]),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: dark ? AppColors.navySurface : AppColors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                      child: _done ? _success(context) : _form(context, scheme),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _success(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      Icon(Icons.mark_email_read_outlined, size: 56, color: scheme.primary),
      const SizedBox(height: 16),
      Text('Pendaftaran terkirim',
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 10),
      Text(
        'Akun Anda sedang menunggu persetujuan admin utama. '
        'Anda baru dapat masuk setelah pendaftaran disetujui.\n\n'
        'Jika diminta, periksa juga email Anda untuk verifikasi alamat email.',
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
      ),
      const SizedBox(height: 28),
      PrimaryButton(label: 'Kembali ke halaman masuk', onPressed: () => context.go(AppRoutes.login)),
    ]);
  }

  Widget _form(BuildContext context, ColorScheme scheme) {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Daftar akun', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Pendaftaran perlu disetujui admin utama sebelum Anda dapat masuk.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        TextFormField(
          controller: _name,
          enabled: !_loading,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(labelText: 'Nama lengkap', prefixIcon: Icon(Icons.person_outline)),
          validator: (v) => (v == null || v.trim().length < 3) ? 'Isi nama lengkap (minimal 3 huruf)' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _email,
          enabled: !_loading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'Isi email';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Format email tidak valid';
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _phone,
          enabled: !_loading,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(labelText: 'No. HP (opsional)', prefixIcon: Icon(Icons.phone_outlined)),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return null;
            return RegExp(r'^\+?[0-9\s\-]{8,16}$').hasMatch(t) ? null : 'Nomor HP tidak valid';
          },
        ),
        if (_branches.isNotEmpty) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _branchId,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Cabang (opsional)', prefixIcon: Icon(Icons.location_city_outlined)),
            items: [
              for (final b in _branches)
                DropdownMenuItem<String>(
                  value: b['id'].toString(),
                  child: Text((b['name'] ?? '').toString(), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _loading ? null : (v) => setState(() => _branchId = v),
          ),
        ],
        const SizedBox(height: 14),
        TextFormField(
          controller: _pw,
          enabled: !_loading,
          obscureText: _obscure,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'Password (minimal 8 karakter)',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) {
            final t = v ?? '';
            if (t.length < 8) return 'Minimal 8 karakter';
            if (!RegExp(r'[A-Za-z]').hasMatch(t) || !RegExp(r'[0-9]').hasMatch(t)) {
              return 'Gunakan kombinasi huruf dan angka';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _pw2,
          enabled: !_loading,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onFieldSubmitted: (_) => _submit(),
          decoration: const InputDecoration(labelText: 'Ulangi password', prefixIcon: Icon(Icons.lock_outline)),
          validator: (v) => v == _pw.text ? null : 'Password tidak sama',
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.error_outline, color: scheme.error, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!, style: TextStyle(color: scheme.error))),
          ]),
        ],
        const SizedBox(height: 22),
        PrimaryButton(label: 'Daftar', loading: _loading, onPressed: _loading ? null : _submit),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loading ? null : _backToLogin,
          child: const Text('Sudah punya akun? Masuk'),
        ),
      ]),
    );
  }
}
