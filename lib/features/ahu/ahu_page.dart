import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/widgets/state_widgets.dart';

const ahuOnlineUrl = 'https://ahu.go.id';

/// "2021-03-19" -> "19-03-2021"
String ahuDate(dynamic iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  if (d == null) return '-';
  String t(int n) => n.toString().padLeft(2, '0');
  return '${t(d.day)}-${t(d.month)}-${d.year}';
}

String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> openAhuOnline(BuildContext context) async {
  final ok = await launchUrl(Uri.parse(ahuOnlineUrl), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka $ahuOnlineUrl.')));
  }
}

/// Lencana status AHU: Terverifikasi / Menunggu verifikasi / Belum diisi.
class AhuBadge extends StatelessWidget {
  const AhuBadge({super.key, required this.number, required this.verified, this.compact = false});
  final String? number;
  final bool verified;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final filled = number != null && number!.trim().isNotEmpty;
    final (label, color, icon) = !filled
        ? ('Belum diisi', AppColors.muted, Icons.help_outline_rounded)
        : verified
            ? ('Terverifikasi AHU', AppColors.emerald, Icons.verified_rounded)
            : ('Menunggu verifikasi', AppColors.amber, Icons.hourglass_top_rounded);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: compact ? 14 : 17, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: compact ? 11.5 : 13)),
      ]),
    );
  }
}

/// Pendaftaran AHU (Kurator dan Pengurus): anggota mengisi data sendiri; pengelola anggota memverifikasi.
class AhuPage extends StatefulWidget {
  const AhuPage({super.key});
  @override
  State<AhuPage> createState() => _AhuPageState();
}

class _AhuPageState extends State<AhuPage> {
  final _db = SupabaseService.client;
  final _number = TextEditingController();
  String? _regDate, _validUntil; // yyyy-MM-dd
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _queue = [];
  bool _queueLoading = false;

  bool get _canVerify => Access.instance.can('manage_member');

  @override
  void initState() {
    super.initState();
    final m = Access.instance.member ?? {};
    _number.text = '${m['ahu_registration_number'] ?? ''}';
    _regDate = _s(m['ahu_registration_date']);
    _validUntil = _s(m['ahu_valid_until']);
    if (_canVerify) _loadQueue();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  String? _s(dynamic v) => (v == null || '$v'.isEmpty) ? null : '$v'.substring(0, 10);

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pick(bool isReg) async {
    final cur = DateTime.tryParse((isReg ? _regDate : _validUntil) ?? '') ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() => isReg ? _regDate = _iso(d) : _validUntil = _iso(d));
  }

  Future<void> _save() async {
    final id = Access.instance.memberId;
    if (id == null) {
      setState(() => _error = 'Akun Anda belum terhubung ke data anggota.');
      return;
    }
    final number = _number.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final row = await _db
          .from('members')
          .update({
            'ahu_registration_number': number.isEmpty ? null : number,
            'ahu_registration_date': number.isEmpty ? null : _regDate,
            'ahu_valid_until': number.isEmpty ? null : _validUntil,
          })
          .eq('id', id)
          .select('ahu_registration_number,ahu_registration_date,ahu_valid_until,ahu_verified,ahu_verified_at')
          .single();
      Access.instance.setMemberFields(Map<String, dynamic>.from(row));
      _snack(number.isEmpty ? 'Data AHU dihapus.' : 'Tersimpan. Menunggu verifikasi pengelola.');
    } catch (_) {
      _error = 'Gagal menyimpan. Pastikan skrip sql/22_ahu_registration.sql sudah dijalankan.';
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _loadQueue() async {
    setState(() => _queueLoading = true);
    try {
      _queue = List<Map<String, dynamic>>.from(await _db
          .from('members')
          .select('id,full_name,member_number,ahu_registration_number,ahu_registration_date,ahu_valid_until')
          .not('ahu_registration_number', 'is', null)
          .eq('ahu_verified', false)
          .order('full_name')
          .limit(100));
    } catch (_) {
      _queue = [];
    }
    if (mounted) setState(() => _queueLoading = false);
  }

  Future<void> _verify(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verifikasi pendaftaran AHU?'),
        content: Text(
            '${r['full_name']}\nNomor: ${r['ahu_registration_number']}\n\nPastikan nomor ini sudah dicocokkan dengan dokumen Surat Bukti Pendaftaran atau situs AHU.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verifikasi')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.from('members').update({'ahu_verified': true}).eq('id', r['id']);
      _snack('${r['full_name']} terverifikasi.');
      await _loadQueue();
    } catch (_) {
      _snack('Gagal memverifikasi. Anda memerlukan hak kelola anggota.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pendaftaran AHU')),
      body: PageGlow(accent: AppColors.teal, child: ListenableBuilder(
        listenable: Access.instance,
        builder: (context, _) {
          final m = Access.instance.member ?? {};
          final number = '${m['ahu_registration_number'] ?? ''}';
          final verified = m['ahu_verified'] == true;
          return ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, 120 + MediaQuery.paddingOf(context).bottom), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.navyDeep, AppColors.navy, Color(0xFF1B4A9C)]),
                boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.26), blurRadius: 24, offset: const Offset(0, 12))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Image.asset(AppAssets.logoAhu, height: 28, errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, color: AppColors.navy)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Kurator dan Pengurus\nterdaftar di AHU',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.25)),
                  ),
                ]),
                const SizedBox(height: 16),
                AhuBadge(number: number, verified: verified),
                if (number.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(number, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Terbit ${ahuDate(m['ahu_registration_date'])}  •  Berlaku s.d. ${ahuDate(m['ahu_valid_until'])}',
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
                ],
              ]),
            ),
            const SectionHeader('Data saya'),
            const SizedBox(height: 8),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _number,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Surat Bukti Pendaftaran',
                    hintText: 'AHU-123.AH.04.03-2021',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                _dateField('Tanggal terbit', _regDate, () => _pick(true)),
                const SizedBox(height: 12),
                _dateField('Berlaku sampai (opsional)', _validUntil, () => _pick(false)),
                const SizedBox(height: 8),
                Text(
                  'Lencana "Terverifikasi AHU" hanya diberikan pengelola setelah mencocokkan dengan dokumen atau situs AHU. '
                  'Mengubah data ini akan mencabut verifikasi sampai diverifikasi ulang.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: sc.onSurfaceVariant),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppColors.red)),
                ],
                const SizedBox(height: 16),
                PrimaryButton(label: _saving ? 'Menyimpan...' : 'Simpan', icon: Icons.save_outlined, loading: _saving, onPressed: _saving ? null : _save),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => openAhuOnline(context),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Buka AHU Online'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ]),
            ),
            if (_canVerify) ...[
              SectionHeader('Menunggu verifikasi', actionLabel: 'Muat ulang', onAction: _loadQueue),
              const SizedBox(height: 8),
              if (_queueLoading)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (_queue.isEmpty)
                AppCard(child: Text('Tidak ada antrean. Semua data AHU yang masuk sudah diverifikasi.', style: TextStyle(color: sc.onSurfaceVariant)))
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    for (var i = 0; i < _queue.length; i++) ...[
                      ListTile(
                        title: Text('${_queue[i]['full_name'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${_queue[i]['ahu_registration_number']}\nBerlaku s.d. ${ahuDate(_queue[i]['ahu_valid_until'])}'),
                        isThreeLine: true,
                        trailing: FilledButton.tonal(onPressed: () => _verify(_queue[i]), child: const Text('Verifikasi')),
                      ),
                      if (i < _queue.length - 1) const Divider(height: 1),
                    ],
                  ]),
                ),
            ],
          ]);
        },
      )),
    );
  }

  Widget _dateField(String label, String? value, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_today_outlined)),
          child: Text(value == null ? 'Pilih tanggal' : ahuDate(value)),
        ),
      );
}
