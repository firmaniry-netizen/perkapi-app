import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/constants/phosphor_icons.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/services/access_service.dart';
import '../../core/utils/format_id.dart';
import '../../core/utils/upload_helper.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/widgets/state_widgets.dart';
import 'donation_data.dart';
import 'donation_widgets.dart';
import '../../core/widgets/smooth_overlays.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/motion.dart';

/// Detail kampanye: kemajuan, cara transfer (rekening/QRIS), donasi saya, daftar donatur,
/// dan bagi pengelola: verifikasi bukti transfer, ubah, tutup, hapus.
class DonationDetailPage extends StatefulWidget {
  const DonationDetailPage({super.key, required this.id});
  final String id;
  @override
  State<DonationDetailPage> createState() => _DonationDetailPageState();
}

class _DonationDetailPageState extends State<DonationDetailPage> {
  Campaign? _c;
  List<Map<String, dynamic>> _donors = [], _mine = [], _review = [];
  bool _loading = true;
  String? _error;

  bool get _manager => Access.instance.can('manage_donation') || Access.instance.isAdmin;
  String? get _me => Access.instance.memberId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await DonationRepo.campaign(widget.id);
      final results = await Future.wait([
        DonationRepo.donors(widget.id).catchError((_) => <Map<String, dynamic>>[]),
        _me == null ? Future.value(<Map<String, dynamic>>[]) : DonationRepo.mine(_me!, campaignId: widget.id).catchError((_) => <Map<String, dynamic>>[]),
        _manager ? DonationRepo.forReview(widget.id).catchError((_) => <Map<String, dynamic>>[]) : Future.value(<Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _c = c;
        _donors = results[0];
        _mine = results[1];
        _review = results[2];
        _loading = false;
        _error = c == null ? 'Kampanye tidak ditemukan atau sudah ditutup.' : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Kampanye belum bisa dimuat. Periksa koneksi internet Anda.';
        });
      }
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _donate() async {
    final c = _c, me = _me;
    if (c == null || me == null) return;
    final ok = await showSmoothSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _DonateSheet(campaign: c, memberId: me),
    );
    if (ok == true) {
      _snack('Terima kasih! Donasi Anda tercatat dan menunggu verifikasi pengurus.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (_loading) return Scaffold(appBar: GlassAppBar(), body: const SkeletonList());
    if (c == null) return Scaffold(appBar: GlassAppBar(), body: ErrorState(message: _error ?? 'Kampanye tidak ditemukan.', onRetry: _load));
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      bottomNavigationBar: c.open
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: PrimaryButton(label: 'Donasi sekarang', icon: Ph.handHeart, onPressed: _donate),
            )
          : null,
      body: RefreshIndicator.adaptive(
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 230,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.navy,
            actions: [if (_manager) _adminMenu(c)],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                Hero(
                  tag: 'donasi-cover-${c.id}',
                  child: SignedImage(bucket: 'donasi-publik', path: c.coverPath, fallback: CoverFallback(category: c.category)),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66000000), Color(0x00000000), Color(0x99000000)], stops: [0, 0.4, 1]),
                  ),
                ),
              ]),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottom),
            sliver: SliverList.list(children: [
              _header(context, c),
              const SizedBox(height: 14),
              _progressCard(context, c),
              if (c.description.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                const SectionHeader('Tentang kampanye'),
                const SizedBox(height: 8),
                Text(c.description, style: const TextStyle(fontSize: AppType.body, height: 1.55)),
              ],
              if (c.open) ...[
                const SizedBox(height: 18),
                const SectionHeader('Cara berdonasi'),
                const SizedBox(height: 8),
                _howTo(context, c),
              ],
              if (_mine.isNotEmpty) ...[
                const SizedBox(height: 18),
                const SectionHeader('Donasi saya'),
                for (final r in _mine) Padding(padding: const EdgeInsets.only(top: 8), child: _myRow(context, r)),
              ],
              if (_manager) ...[
                const SizedBox(height: 18),
                SectionHeader('Verifikasi donasi${c.pending > 0 ? ' (${c.pending})' : ''}'),
                if (_review.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Belum ada donasi masuk.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                for (final r in _review) Padding(padding: const EdgeInsets.only(top: 8), child: _reviewRow(context, r)),
              ],
              const SizedBox(height: 18),
              SectionHeader('Donatur (${c.donors})'),
              const SizedBox(height: 4),
              if (_donors.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(c.open ? 'Jadilah donatur pertama.' : 'Belum ada donatur.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              for (final d in _donors) _donorRow(context, d),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context, Campaign c) {
    final (color, icon) = categoryStyle(c.category);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 6, children: [
        Pill(c.category, color: color, icon: icon),
        if (!c.active) const Pill('Ditutup', color: AppColors.muted, icon: PhFill.lock),
        if (c.active && c.ended) const Pill('Selesai', color: AppColors.muted, icon: PhFill.flag),
      ]),
      const SizedBox(height: 10),
      Text(c.title, style: const TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w900, height: 1.2)),
    ]);
  }

  Widget _progressCard(BuildContext context, Campaign c) {
    final sc = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget stat(String v, String l) => Expanded(
          child: Column(children: [
            Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: AppType.lead)),
            const SizedBox(height: 2),
            Text(l, style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
          ]),
        );
    return AppCard(
      wash: AppColors.emerald,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Terkumpul', style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(rupiah(c.collected),
            style: TextStyle(fontSize: AppType.display, fontWeight: FontWeight.w900, color: AppColors.onSoft(AppColors.emerald, dark: dark))),
        if ((c.target ?? 0) > 0) ...[
          Text('dari target ${rupiah(c.target!)}', style: TextStyle(fontSize: AppType.small, color: sc.onSurfaceVariant)),
          const SizedBox(height: 12),
          DonationProgress(value: c.progress, height: 10),
        ],
        const SizedBox(height: 14),
        Row(children: [
          stat('${c.donors}', 'donatur'),
          if ((c.target ?? 0) > 0) stat('${(c.progress * 100).floor()}%', 'tercapai'),
          stat(c.timeLeft ?? 'Terbuka', c.endsAt == null ? 'tanpa batas' : 'sampai ${FmtId.date(c.endsAt!)}'),
        ]),
      ]),
    );
  }

  Widget _howTo(BuildContext context, Campaign c) {
    final sc = Theme.of(context).colorScheme;
    final hasBank = c.accountNumber != null;
    return Column(children: [
      if (hasBank)
        AppCard(
          child: Row(children: [
            const SolidTile(icon: Ph.buildings, color: AppColors.navyAction, size: 44, radius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.bankName ?? 'Rekening', style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
                SelectableText(c.accountNumber!, style: const TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                if (c.accountHolder != null) Text('a.n. ${c.accountHolder}', style: TextStyle(fontSize: AppType.small, color: sc.onSurfaceVariant)),
              ]),
            ),
            IconButton.filledTonal(
              tooltip: 'Salin nomor rekening',
              icon: const Icon(Ph.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: c.accountNumber!.replaceAll(RegExp(r'[^0-9]'), '')));
                _snack('Nomor rekening disalin.');
              },
            ),
          ]),
        ),
      if (c.qrisPath != null) ...[
        if (hasBank) const SizedBox(height: 10),
        AppCard(
          onTap: () => _showImage('donasi-publik', c.qrisPath!, 'QRIS'),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: SignedImage(bucket: 'donasi-publik', path: c.qrisPath, fit: BoxFit.contain, fallback: const Icon(Ph.qrCode, size: 40)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Bayar dengan QRIS', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Ketuk untuk memperbesar, lalu pindai dengan aplikasi bank atau e-wallet.',
                    style: TextStyle(fontSize: AppType.caption, height: 1.35, color: sc.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
      ],
      if (!hasBank && c.qrisPath == null)
        AppCard(child: Text('Info rekening belum diisi pengurus. Hubungi sekretariat untuk cara berdonasi.', style: TextStyle(color: sc.onSurfaceVariant))),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Ph.info, size: 18, color: sc.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Transfer dulu, lalu tekan "Donasi sekarang" dan unggah bukti transfer. Pengurus akan memverifikasi, dan Anda mendapat notifikasi setelah donasi diterima.',
              style: TextStyle(fontSize: AppType.caption, height: 1.4, color: sc.onSurfaceVariant)),
        ),
      ]),
    ]);
  }

  Widget _myRow(BuildContext context, Map<String, dynamic> r) {
    final (color, label, icon) = donationStatus('${r['status']}');
    final sc = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(rupiah((r['amount'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: AppType.lead))),
          Pill(label, color: color, icon: icon),
        ]),
        const SizedBox(height: 4),
        Text('${FmtId.value(r['created_at'])}${r['is_anonymous'] == true ? ' · anonim' : ''}', style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
        if (r['status'] == 'ditolak' && r['reject_reason'] != null) ...[
          const SizedBox(height: 6),
          Text('Alasan: ${r['reject_reason']}', style: const TextStyle(fontSize: AppType.small)),
        ],
        if (r['status'] == 'menunggu')
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _cancel(r),
              icon: const Icon(Ph.x, size: 18),
              label: const Text('Batalkan'),
            ),
          ),
      ]),
    );
  }

  Future<void> _cancel(Map<String, dynamic> r) async {
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Batalkan donasi?'),
        content: const Text('Catatan donasi dan bukti transfer akan dihapus. Uang yang sudah ditransfer tidak otomatis kembali; hubungi bendahara bila perlu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Tidak')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Batalkan donasi')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DonationRepo.cancel('${r['id']}', r['proof_path'] as String?);
      _load();
    } catch (_) {
      _snack('Gagal membatalkan. Coba lagi.');
    }
  }

  Widget _reviewRow(BuildContext context, Map<String, dynamic> r) {
    final (color, label, icon) = donationStatus('${r['status']}');
    final sc = Theme.of(context).colorScheme;
    final name = '${(r['members'] as Map?)?['full_name'] ?? 'Anggota'}';
    final pending = r['status'] == 'menunggu';
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${rupiah((r['amount'] as num?) ?? 0)} · ${FmtId.value(r['created_at'])}${r['is_anonymous'] == true ? ' · minta anonim' : ''}',
                  style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
            ]),
          ),
          Pill(label, color: color, icon: icon),
        ]),
        if ((r['message'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('"${r['message']}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: AppType.small)),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          OutlinedButton.icon(
            onPressed: r['proof_path'] == null ? null : () => _showImage('donasi-bukti', '${r['proof_path']}', 'Bukti transfer'),
            icon: const Icon(Ph.fileText, size: 18),
            label: Text(r['proof_path'] == null ? 'Tanpa bukti' : 'Lihat bukti'),
          ),
          if (pending) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
              onPressed: () => _verify(r, true),
              icon: const Icon(Ph.check, size: 18),
              label: const Text('Terima'),
            ),
            TextButton(onPressed: () => _verify(r, false), child: const Text('Tolak')),
          ],
        ]),
      ]),
    );
  }

  Future<void> _verify(Map<String, dynamic> r, bool ok) async {
    String? reason;
    if (!ok) {
      final ctl = TextEditingController();
      final go = await showSmoothDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Tolak donasi'),
          content: TextField(
            controller: ctl,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Alasan (dikirim ke anggota)', hintText: 'mis. dana belum masuk ke rekening'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Tolak')),
          ],
        ),
      );
      reason = ctl.text;
      ctl.dispose();
      if (go != true) return;
    }
    try {
      await DonationRepo.verify('${r['id']}', ok, reason: reason);
      _snack(ok ? 'Donasi diterima. Anggota mendapat notifikasi.' : 'Donasi ditolak.');
      _load();
    } catch (_) {
      _snack('Gagal menyimpan. Pastikan Anda memiliki izin mengelola donasi.');
    }
  }

  Widget _donorRow(BuildContext context, Map<String, dynamic> d) {
    final sc = Theme.of(context).colorScheme;
    final name = '${d['name'] ?? 'Anggota'}';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.soft(AppColors.emerald, dark: Theme.of(context).brightness == Brightness.dark),
          child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(rupiah((d['amount'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            Text(FmtId.relativeDay(FmtId.parse(d['created_at']) ?? DateTime.now()), style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
            if ((d['message'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('${d['message']}', style: const TextStyle(fontSize: AppType.small, height: 1.4)),
              ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _showImage(String bucket, String path, String title) async {
    if (path.toLowerCase().endsWith('.pdf')) {
      final u = await DonationRepo.signedUrl(bucket, path);
      if (u != null) await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    await showSmoothDialog<void>(
      context: context,
      builder: (d) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            trailing: IconButton(icon: const Icon(Ph.x), onPressed: () => Navigator.pop(d)),
          ),
          Flexible(
            child: InteractiveViewer(
              maxScale: 5,
              child: SignedImage(
                bucket: bucket,
                path: path,
                fit: BoxFit.contain,
                fallback: const SizedBox(height: 240, child: Center(child: CircularProgressIndicator.adaptive())),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _adminMenu(Campaign c) => PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'edit') {
            await context.push('/donations/${c.id}/edit');
            _load();
          } else if (v == 'toggle') {
            try {
              await DonationRepo.save({'is_active': !c.active}, id: c.id);
              _snack(c.active ? 'Kampanye ditutup.' : 'Kampanye dibuka kembali.');
              _load();
            } catch (_) {
              _snack('Gagal menyimpan.');
            }
          } else if (v == 'delete') {
            final ok = await showSmoothDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                title: const Text('Hapus kampanye?'),
                content: const Text('Kampanye dan seluruh catatan donasinya akan dihapus permanen. Untuk mengakhiri kampanye tanpa menghapus catatan, pilih "Tutup kampanye".'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
                  FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.red), onPressed: () => Navigator.pop(d, true), child: const Text('Hapus')),
                ],
              ),
            );
            if (ok != true) return;
            try {
              await DonationRepo.remove(c.id);
              if (mounted) context.pop();
            } catch (_) {
              _snack('Gagal menghapus.');
            }
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Ph.pencilSimple), title: Text('Ubah kampanye'))),
          PopupMenuItem(value: 'toggle', child: ListTile(leading: Icon(c.active ? PhFill.lock : Ph.lockOpen), title: Text(c.active ? 'Tutup kampanye' : 'Buka kembali'))),
          const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Ph.trash), title: Text('Hapus'))),
        ],
      );
}

/// Lembar donasi: nominal (cepat/kustom), anonim, pesan, bukti transfer.
class _DonateSheet extends StatefulWidget {
  const _DonateSheet({required this.campaign, required this.memberId});
  final Campaign campaign;
  final String memberId;
  @override
  State<_DonateSheet> createState() => _DonateSheetState();
}

class _DonateSheetState extends State<_DonateSheet> {
  static const presets = [50000, 100000, 250000, 500000, 1000000];
  final _amount = TextEditingController();
  final _msg = TextEditingController();
  bool _anon = false, _busy = false;
  PlatformFile? _proof;
  String? _err;

  int get _value => int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    _msg.dispose();
    super.dispose();
  }

  void _set(int v) => setState(() {
        _amount.text = rupiah(v).replaceFirst('Rp ', '');
        _err = null;
      });

  Future<void> _pick(bool camera) async {
    final f = await pickPhotos(camera: camera, multiple: false);
    if (f.isNotEmpty) setState(() => _proof = f.first);
  }

  Future<void> _submit() async {
    if (_value < 1000) {
      setState(() => _err = 'Minimal donasi Rp 1.000.');
      return;
    }
    if (_proof == null) {
      setState(() => _err = 'Unggah bukti transfer agar pengurus bisa memverifikasi.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await DonationRepo.donate(
        campaignId: widget.campaign.id,
        memberId: widget.memberId,
        amount: _value,
        anonymous: _anon,
        message: _msg.text,
        proof: _proof,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = 'Donasi gagal dikirim. Periksa koneksi lalu coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('Donasi untuk', style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
          Text(widget.campaign.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppType.lead, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in presets)
              ChoiceChip(label: Text(rupiahShort(p)), selected: _value == p, onSelected: (_) => _set(p)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ThousandsFormatter()],
            style: const TextStyle(fontSize: AppType.heading, fontWeight: FontWeight.w900),
            onChanged: (_) => setState(() => _err = null),
            decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp '),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _msg,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Pesan / doa (opsional)'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _anon,
            onChanged: (v) => setState(() => _anon = v),
            title: const Text('Sembunyikan nama saya'),
            subtitle: const Text('Tampil sebagai "Hamba Allah" di daftar donatur. Pengurus tetap melihat nama Anda.'),
          ),
          const SizedBox(height: 4),
          const Text('Bukti transfer', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_proof != null)
            AppCard(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                const Icon(PhFill.checkCircle, color: AppColors.emerald),
                const SizedBox(width: 10),
                Expanded(child: Text(_proof!.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                TextButton(onPressed: () => setState(() => _proof = null), child: const Text('Ganti')),
              ]),
            )
          else
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _pick(false), icon: const Icon(Ph.images), label: const Text('Galeri'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: () => _pick(true), icon: const Icon(PhFill.camera), label: const Text('Kamera'))),
            ]),
          if (_err != null) ...[
            const SizedBox(height: 10),
            Text(_err!, style: TextStyle(color: sc.error, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          PrimaryButton(label: _value >= 1000 ? 'Kirim donasi ${rupiah(_value)}' : 'Kirim donasi', onPressed: _submit, loading: _busy),
        ]),
      ),
    );
  }
}

/// 1000000 → "1.000.000" saat diketik.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final t = rupiah(int.parse(digits.length > 12 ? digits.substring(0, 12) : digits)).replaceFirst('Rp ', '');
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
