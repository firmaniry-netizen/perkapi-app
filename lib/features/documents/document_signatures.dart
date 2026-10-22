import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/widgets/state_widgets.dart';
import 'signature_pad.dart';
import '../../core/widgets/smooth_overlays.dart';

/// Tanda tangan elektronik pada dokumen: mencatat siapa, kapan, dan versi file mana yang ditandatangani.
/// Ini tanda tangan elektronik biasa (bukti persetujuan internal), BUKAN tanda tangan tersertifikasi.
class DocumentSignatures extends StatefulWidget {
  const DocumentSignatures({super.key, required this.docId});
  final String docId;
  @override
  State<DocumentSignatures> createState() => _DocumentSignaturesState();
}

class _DocumentSignaturesState extends State<DocumentSignatures> {
  final _db = SupabaseService.client;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _db.rpc('document_signers', params: {'p_doc': widget.docId});
      if (mounted) setState(() { _rows = List<Map<String, dynamic>>.from(r as List); _loading = false; _error = null; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Tanda tangan belum aktif. Jalankan sql/17_chat_signature_search.sql.'; });
    }
  }

  bool get _signedCurrent => _rows.any((r) => r['is_mine'] == true && r['is_current'] == true);

  Future<void> _sign() async {
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tandatangani dokumen?'),
        content: const Text('Dengan menandatangani, Anda menyatakan telah membaca dan menyetujui isi versi dokumen ini. Tanda tangan tercatat dengan nama, waktu, dan versi file.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lanjut')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final png = await SignaturePadDialog.show(context);
    if (png == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final uid = _db.auth.currentUser!.id;
      final path = '$uid/${widget.docId}_${DateTime.now().millisecondsSinceEpoch}.png';
      await _db.storage.from('signatures').uploadBinary(path, png, fileOptions: const FileOptions(contentType: 'image/png'));
      await _db.rpc('sign_document', params: {'p_document': widget.docId, 'p_signature_path': path});
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dokumen ditandatangani.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menandatangani. Coba lagi.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _view(String path) async {
    try {
      final url = await _db.storage.from('signatures').createSignedUrl(path, 120);
      if (!mounted) return;
      await showSmoothDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          content: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, fit: BoxFit.contain)),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup'))],
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tanda tangan elektronik', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      if (_loading)
        const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
      else if (_error != null)
        Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13))
      else ...[
        if (_rows.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Belum ada yang menandatangani.')),
        for (final r in _rows)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(r['is_current'] == true ? Icons.verified_outlined : Icons.history_toggle_off, color: r['is_current'] == true ? scheme.primary : scheme.onSurfaceVariant),
            title: Text('${r['signer_name']}'),
            subtitle: Text('${fmtValue(r['signed_at'])} · ${r['is_current'] == true ? 'versi saat ini' : 'versi sebelumnya'}'),
            onTap: () => _view('${r['signature_path']}'),
          ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _busy || _signedCurrent ? null : _sign,
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.draw_outlined),
          label: Text(_signedCurrent ? 'Sudah Anda tandatangani' : 'Tandatangani dokumen ini'),
        ),
        const SizedBox(height: 4),
        Text('Tanda tangan elektronik biasa (bukti persetujuan internal), bukan tanda tangan tersertifikasi.', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ],
    ]);
  }
}
