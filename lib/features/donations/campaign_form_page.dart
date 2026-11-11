import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/ios_pickers.dart';
import '../../core/constants/phosphor_icons.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/format_id.dart';
import '../../core/utils/upload_helper.dart';
import '../../core/widgets/ui_kit.dart';
import 'donation_data.dart';
import 'donation_widgets.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/motion.dart';
import '../../core/constants/app_tokens.dart';

/// Pengelola: buat / ubah kampanye donasi.
class CampaignFormPage extends StatefulWidget {
  const CampaignFormPage({super.key, this.id});
  final String? id;
  @override
  State<CampaignFormPage> createState() => _CampaignFormPageState();
}

class _CampaignFormPageState extends State<CampaignFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _target = TextEditingController();
  final _bank = TextEditingController();
  final _acc = TextEditingController();
  final _holder = TextEditingController();
  String _cat = 'Event';
  DateTime? _ends;
  bool _active = true, _busy = false, _loading = false;
  String? _coverPath, _qrisPath;
  PlatformFile? _cover, _qris;

  bool get _edit => widget.id != null;

  @override
  void initState() {
    super.initState();
    if (_edit) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = await DonationRepo.campaign(widget.id!).catchError((_) => null);
    if (!mounted) return;
    if (c != null) {
      _title.text = c.title;
      _desc.text = c.description;
      _target.text = c.target == null ? '' : '${c.target}';
      _bank.text = c.bankName ?? '';
      _acc.text = c.accountNumber ?? '';
      _holder.text = c.accountHolder ?? '';
      _cat = donationCategories.contains(c.category) ? c.category : 'Lainnya';
      _ends = c.endsAt;
      _active = c.active;
      _coverPath = c.coverPath;
      _qrisPath = c.qrisPath;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _target, _bank, _acc, _holder]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final cover = _cover != null ? await DonationRepo.uploadPublic(_cover!, 'sampul') : _coverPath;
      final qris = _qris != null ? await DonationRepo.uploadPublic(_qris!, 'qris') : _qrisPath;
      String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
      final target = int.tryParse(_target.text.replaceAll(RegExp(r'[^0-9]'), ''));
      await DonationRepo.save({
        'title': _title.text.trim(),
        'category': _cat,
        'description': t(_desc),
        'target_amount': (target ?? 0) > 0 ? target : null,
        'ends_at': _ends == null ? null : '${_ends!.year}-${_ends!.month.toString().padLeft(2, '0')}-${_ends!.day.toString().padLeft(2, '0')}',
        'bank_name': t(_bank),
        'account_number': t(_acc),
        'account_holder': t(_holder),
        'cover_path': cover,
        'qris_path': qris,
        'is_active': _active,
      }, id: widget.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_edit ? 'Kampanye disimpan.' : 'Kampanye dibuat. Semua anggota mendapat notifikasi ajakan donasi.')));
      context.pop();
    } catch (e) {
      if (kDebugMode) debugPrint('donasi simpan: $e');
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan. Pastikan Anda memiliki izin mengelola donasi.')));
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showIosDatePicker(
      context: context,
      initialDate: _ends ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
      helpText: 'Batas akhir donasi',
    );
    if (d != null) setState(() => _ends = d);
  }

  Widget _imagePicker({required String label, required String hint, required String? path, required PlatformFile? file, required ValueChanged<PlatformFile?> onPick, required VoidCallback onClear, bool contain = false}) {
    final sc = Theme.of(context).colorScheme;
    final has = file != null || path != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(hint, style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
      const SizedBox(height: 8),
      Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: contain ? 72 : 120,
            height: 72,
            child: file != null
                ? (kIsWeb || file.path == null
                    ? const ColoredBox(color: AppColors.emerald, child: Icon(PhFill.image, color: Colors.white))
                    : Image.file(File(file.path!), cacheWidth: 300, fit: contain ? BoxFit.contain : BoxFit.cover))
                : SignedImage(
                    bucket: 'donasi-publik',
                    path: path,
                    fit: contain ? BoxFit.contain : BoxFit.cover,
                    fallback: ColoredBox(color: sc.surfaceContainerHighest, child: Icon(contain ? Ph.qrCode : Ph.image, color: sc.onSurfaceVariant)),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 6, children: [
            OutlinedButton.icon(
              onPressed: () async {
                final f = await pickPhotos(multiple: false);
                if (f.isNotEmpty) onPick(f.first);
              },
              icon: const Icon(Ph.images, size: 18),
              label: Text(has ? 'Ganti' : 'Pilih gambar'),
            ),
            if (has) TextButton(onPressed: onClear, child: const Text('Hapus')),
          ]),
        ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: GlassAppBar(title: Text(_edit ? 'Ubah kampanye' : 'Kampanye donasi baru')),
      body: _loading
          ? const SkeletonList()
          : Form(
              key: _form,
              child: ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottom), children: [
                const SectionHeader('Kampanye'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _title,
                  maxLength: 140,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Judul', hintText: 'mis. Donasi Rakernas PERKAPI 2026'),
                  validator: (v) => (v ?? '').trim().length < 3 ? 'Isi judul kampanye (minimal 3 huruf).' : null,
                ),
                const SizedBox(height: 4),
                Text('Kategori', style: TextStyle(fontSize: AppType.caption, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in donationCategories)
                    ChoiceChip(
                      avatar: Icon(categoryStyle(c).$2, size: 16),
                      label: Text(c),
                      selected: _cat == c,
                      onSelected: (_) => setState(() => _cat = c),
                    ),
                ]),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _desc,
                  maxLines: 6,
                  minLines: 3,
                  maxLength: 5000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Deskripsi', hintText: 'Tujuan donasi, penggunaan dana, dan info penting lainnya.', alignLabelWithHint: true),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _target,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Target dana (opsional)', prefixText: 'Rp ', hintText: 'kosongkan bila tanpa target'),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  onTap: _pickDate,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Ph.calendarPlus),
                    title: const Text('Batas akhir donasi'),
                    subtitle: Text(_ends == null ? 'Tanpa batas waktu' : FmtId.dayDate(_ends!)),
                    trailing: _ends == null
                        ? const Icon(Ph.caretRight)
                        : IconButton(tooltip: 'Hapus batas', icon: const Icon(Ph.x), onPressed: () => setState(() => _ends = null)),
                  ),
                ),
                const SizedBox(height: 16),
                _imagePicker(
                  label: 'Foto sampul',
                  hint: 'Tampil di daftar dan halaman kampanye.',
                  path: _coverPath,
                  file: _cover,
                  onPick: (f) => setState(() => _cover = f),
                  onClear: () => setState(() {
                    _cover = null;
                    _coverPath = null;
                  }),
                ),
                const SizedBox(height: 22),
                const SectionHeader('Tujuan transfer'),
                const SizedBox(height: 10),
                TextFormField(controller: _bank, decoration: const InputDecoration(labelText: 'Nama bank', hintText: 'mis. Bank Mandiri')),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _acc,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Nomor rekening'),
                  validator: (v) => (v ?? '').trim().isEmpty && _qris == null && _qrisPath == null
                      ? 'Isi nomor rekening atau unggah QRIS agar anggota bisa berdonasi.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(controller: _holder, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Atas nama')),
                const SizedBox(height: 16),
                _imagePicker(
                  label: 'Gambar QRIS (opsional)',
                  hint: 'Anggota bisa memindai untuk membayar lewat bank atau e-wallet.',
                  path: _qrisPath,
                  file: _qris,
                  contain: true,
                  onPick: (f) => setState(() => _qris = f),
                  onClear: () => setState(() {
                    _qris = null;
                    _qrisPath = null;
                  }),
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                    title: const Text('Kampanye aktif'),
                    subtitle: Text(_edit ? 'Matikan untuk menutup kampanye.' : 'Saat aktif, semua anggota mendapat notifikasi ajakan donasi.'),
                ),
                const SizedBox(height: 16),
                PrimaryButton(label: _edit ? 'Simpan perubahan' : 'Terbitkan kampanye', onPressed: _save, loading: _busy),
              ]),
            ),
    );
  }
}

