import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/partner_logos.dart';
import '../../core/widgets/photo_backdrop.dart';
import '../../core/widgets/perkapi_logo.dart';
import 'auth_repository.dart';
import '../legal/privacy_policy_page.dart';
import 'otp_dialog.dart';
import '../../core/widgets/smooth_overlays.dart';
import '../../core/widgets/illustrations.dart';
import '../../core/constants/app_tokens.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _repo = AuthRepository();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repo.signIn(identifier: _idCtrl.text, password: _pwCtrl.text);
      // Redirect ke /dashboard ditangani router lewat auth state.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    final id = _idCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (!id.contains('@')) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Isi kolom dengan email Anda untuk reset password.'),
      ));
      return;
    }
    try {
      await _repo.sendPasswordReset(id);
      messenger.showSnackBar(const SnackBar(
        content: Text('Jika email terdaftar, tautan reset telah dikirim.'),
      ));
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    // Keyboard terbuka: ringkas header agar kolom isian tidak terdesak di layar kecil.
    final kb = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: dark ? AppColors.navyDeep : AppColors.navy,
      body: AuroraBackground(
        child: Stack(children: [
        Positioned.fill(child: PhotoBackdrop(asset: AppAssets.heroLogin, shade: 0.78)),
        const Positioned.fill(child: DotGrid(opacity: 0.06)),
        const Positioned(right: -30, top: 70, child: ScalesArt(size: 200, opacity: 0.09)),
        SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              Reveal(
                index: 0,
                dy: -16,
                child: AnimatedSize(
                duration: Duration(milliseconds: reduceMotion(context) ? 0 : 200),
                curve: Curves.easeOut,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, kb ? 8 : 28, 24, kb ? 14 : 28),
                  child: Column(children: [
                    PerkapiLogo(size: kb ? 44 : 72, onDark: true, animate: true),
                    SizedBox(height: kb ? 8 : 14),
                    Wordmark(size: kb ? 22 : 30, color: Colors.white),
                    if (!kb) ...[
                      const SizedBox(height: 8),
                      Text(
                        AppConstants.appSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: AppType.small),
                      ),
                    ],
                  ]),
                ),
              ),
              ),
              Expanded(
                child: Reveal(
                  index: 2,
                  dy: 56,
                  child: ClipRRect(
                  // Lembar login berbahan kaca cair: foto latar tampak samar di baliknya.
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  child: BackdropFilter(
                  filter: LiquidGlass.backdrop(28),
                  child: CustomPaint(
                  foregroundPainter: GlassSheen(dark: dark, radius: 32, solid: MediaQuery.highContrastOf(context)),
                  child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: (dark ? AppColors.navySurface : AppColors.white).withValues(alpha: MediaQuery.highContrastOf(context) ? 1 : (dark ? 0.80 : 0.88)),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('Selamat datang kembali', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 6),
                        Text('Masuk dengan email atau nomor anggota Anda.',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppType.body, height: 1.4)),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _idCtrl,
                          enabled: !_loading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'Email atau nomor anggota',
                            prefixIcon: Icon(CupertinoIcons.person),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Isi email atau nomor anggota' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pwCtrl,
                          enabled: !_loading,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(CupertinoIcons.lock),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
                              icon: Icon(_obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Isi password' : null,
                        ),
                        AnimatedSize(
                          duration: Duration(milliseconds: reduceMotion(context) ? 0 : 180),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: _error == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: scheme.error.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(children: [
                                      Icon(CupertinoIcons.exclamationmark_circle, color: scheme.error, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: AppType.small, height: 1.35))),
                                    ]),
                                  ),
                                ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _forgot,
                            child: const Text('Lupa password?'),
                          ),
                        ),
                        const SizedBox(height: 4),
                        PrimaryButton(label: 'Masuk', loading: _loading, onPressed: _loading ? null : _submit),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _loading
                              ? null
                              : () => showSmoothDialog<void>(
                                    context: context,
                                    builder: (_) => OtpDialog(
                                        initialEmail: _idCtrl.text.contains('@') ? _idCtrl.text.trim() : ''),
                                  ),
                          icon: const Icon(CupertinoIcons.envelope_open),
                          label: const Text('Masuk dengan kode email'),
                        ),
                        TextButton(
                          onPressed: _loading ? null : () => context.push(AppRoutes.register),
                          child: const Text('Belum punya akun? Daftar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyPage())),
                          child: const Text('Kebijakan Privasi'),
                        ),
                        const SizedBox(height: 16),
                        const PartnerLogos(),
                      ]),
                    ),
                  ),
                )))),
                ),
              ),
            ]),
          ),
        ),
      ),
        ]),
      ),
    );
  }
}
