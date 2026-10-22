import 'package:flutter/material.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/constants/app_colors.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/member_avatar.dart';
import '../../shared/widgets/state_widgets.dart';
import '../ahu/ahu_page.dart';
import 'qr_scanner_page.dart';

/// Verifikasi Kartu Anggota: tempel isi QR (perkapi:member:<token>) atau token-nya.
/// Hanya pengelola anggota (manage_member). Verifikasi dilakukan di database
/// lewat fungsi verify_member_qr.
class VerifyMemberPage extends StatefulWidget {
  const VerifyMemberPage({super.key});
  @override
  State<VerifyMemberPage> createState() => _VerifyMemberPageState();
}

class _VerifyMemberPageState extends State<VerifyMemberPage> {
  final _ctl = TextEditingController();
  bool _busy = false;
  bool _checked = false;
  Map<String, dynamic>? _result;
  String? _error;

  static final _uuid = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final v = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (v == null || !mounted) return;
    _ctl.text = v;
    await _verify();
  }

  Future<void> _verify() async {
    final m = _uuid.firstMatch(_ctl.text.trim());
    if (m == null) {
      setState(() {
        _checked = false;
        _error = 'Format token tidak valid.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _checked = false;
    });
    try {
      final res = await SupabaseService.client
          .rpc('verify_member_qr', params: {'p_token': m.group(0)});
      _result = res is Map ? Map<String, dynamic>.from(res) : null;
      _checked = true;
      await SupabaseService.client.rpc('log_event', params: {
        'p_action': 'verify_qr',
        'p_module': 'members',
        'p_record': _result == null ? 'not_found' : '${_result!['member_number']}',
      });
    } catch (_) {
      _error = 'Gagal memverifikasi. Periksa koneksi Anda.';
    }
    if (mounted) setState(() => _busy = false);
  }

  bool get _valid {
    final r = _result;
    if (r == null) return false;
    if ('${r['status']}' != 'Aktif') return false;
    final until = DateTime.tryParse('${r['valid_until'] ?? ''}');
    if (until == null) return true;
    final today = DateTime.now();
    return !until.isBefore(DateTime(today.year, today.month, today.day));
  }

  @override
  Widget build(BuildContext context) {
    if (!Access.instance.can('manage_member')) return const AccessDenied();
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Kartu Anggota')),
      body: PageGlow(accent: AppColors.teal, child: ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom), children: [
        Reveal(index: 0, dy: -12, child: ScreenHero(title: 'Verifikasi Kartu', subtitle: 'Pastikan keaslian kartu anggota lewat QR', icon: Icons.verified_user_rounded, accent: AppColors.teal)),
        const SizedBox(height: 16),
        const Text('Tempel isi QR kartu anggota (contoh: perkapi:member:xxxxxxxx-...) lalu tekan Verifikasi.'),
        const SizedBox(height: 12),
        TextField(
          controller: _ctl,
          decoration: const InputDecoration(labelText: 'Isi QR / token', prefixIcon: Icon(Icons.qr_code_2)),
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _scan,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Pindai dengan kamera'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _verify,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.verified_user_outlined),
          label: const Text('Verifikasi'),
        ),
        const SizedBox(height: 16),
        if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFC62828))),
        if (_checked && _result == null)
          const Card(
            color: Color(0xFFFFEBEE),
            child: ListTile(
              leading: Icon(Icons.cancel, color: Color(0xFFC62828)),
              title: Text('Kartu tidak dikenali', style: TextStyle(color: Colors.black87)),
              subtitle: Text('Token tidak ditemukan.', style: TextStyle(color: Colors.black54)),
            ),
          ),
        if (_result != null)
          Card(
            color: _valid ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(_valid ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: _valid ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00)),
                  const SizedBox(width: 8),
                  Text(_valid ? 'KARTU VALID' : 'KARTU TIDAK AKTIF / KEDALUWARSA',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _valid ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00))),
                ]),
                const SizedBox(height: 12),
                Center(
                  child: MemberAvatar(
                    name: '${_result!['full_name'] ?? ''}',
                    path: _result!['avatar_path'] as String?,
                    radius: 44,
                  ),
                ),
                const SizedBox(height: 12),
                _line('Nama', '${_result!['full_name'] ?? '-'}'),
                _line('No. anggota', '${_result!['member_number'] ?? '-'}'),
                _line('Status', '${_result!['status'] ?? '-'}'),
                _line('Berlaku s.d.', '${_result!['valid_until'] ?? '-'}'),
                _line('Reg. AHU', '${_result!['ahu_registration_number'] ?? '-'}'),
                _line('Berlaku AHU', ahuDate(_result!['ahu_valid_until'])),
                const SizedBox(height: 8),
                AhuBadge(
                  number: _result!['ahu_registration_number'] as String?,
                  verified: _result!['ahu_verified'] == true,
                ),
              ]),
            ),
          ),
      ])),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
        ]),
      );
}
