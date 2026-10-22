import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';

/// Chat AI. Semua panggilan lewat Edge Function `ai-perkapi`; API key AI hanya ada di server.
class AiPage extends StatefulWidget {
  const AiPage({super.key});
  @override
  State<AiPage> createState() => _AiPageState();
}

class _Msg {
  _Msg(this.fromUser, this.text);
  final bool fromUser;
  final String text;
}

class _AiPageState extends State<AiPage> {
  final _ctrl = TextEditingController();
  final _msgs = <_Msg>[];
  String? _conversationId;
  bool _busy = false;

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _busy) return;
    setState(() {
      _msgs.add(_Msg(true, t));
      _busy = true;
      _ctrl.clear();
    });
    try {
      final res = await SupabaseService.client.functions
          .invoke('ai-perkapi', body: {'message': t, 'conversation_id': _conversationId});
      final data = res.data;
      if (data is Map && data['reply'] is String) {
        _conversationId = data['conversation_id'] as String?;
        setState(() => _msgs.add(_Msg(false, data['reply'] as String)));
      } else {
        setState(() => _msgs.add(_Msg(false, 'AI tidak dapat menjawab saat ini.')));
      }
    } on FunctionException catch (e) {
      final msg = e.status == 404
          ? 'Fungsi AI belum di-deploy. Jalankan: supabase functions deploy ai-perkapi'
          : e.status == 502
              ? 'Server AI menolak permintaan. Periksa ANTHROPIC_API_KEY di Supabase secrets.'
              : 'Layanan AI bermasalah (kode ${e.status}). Coba lagi nanti.';
      setState(() => _msgs.add(_Msg(false, msg)));
    } catch (_) {
      setState(() => _msgs.add(_Msg(false, 'Tidak dapat terhubung. Periksa koneksi internet.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _suggest = [
    'Ringkas pengumuman terbaru',
    'Apa isi Kode Etik Kurator?',
    'Buat draft surat undangan rapat',
  ];

  void _ask(String t) {
    _ctrl.text = t;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('AI PERKAPI')),
      body: PageGlow(accent: AppColors.violet, child: Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF3A2E12) : const Color(0xFFFFF4E5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 18, color: dark ? const Color(0xFFFFB74D) : const Color(0xFFB26A00)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(AppConstants.aiDisclaimer,
                  style: TextStyle(fontSize: 12, height: 1.4, color: dark ? Colors.white : AppColors.darkText)),
            ),
          ]),
        ),
        Expanded(
          child: _msgs.isEmpty
              ? ListView(padding: const EdgeInsets.all(24), children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.10), shape: BoxShape.circle),
                      child: Icon(Icons.auto_awesome, size: 34, color: scheme.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Apa yang ingin Anda tanyakan?',
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Buku Saku, pengumuman, atau draft administrasi.',
                      textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4)),
                  const SizedBox(height: 20),
                  Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                    for (final t in _suggest) ActionChip(label: Text(t), onPressed: () => _ask(t)),
                  ]),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  itemCount: _msgs.length,
                  itemBuilder: (_, i) {
                    final m = _msgs[i];
                    return Align(
                      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: const BoxConstraints(maxWidth: 520),
                        decoration: BoxDecoration(
                          color: m.fromUser ? (dark ? AppColors.navyAction : AppColors.navy) : scheme.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(22),
                            topRight: const Radius.circular(22),
                            bottomLeft: Radius.circular(m.fromUser ? 22 : 6),
                            bottomRight: Radius.circular(m.fromUser ? 6 : 22),
                          ),
                          border: m.fromUser ? null : Border.all(color: scheme.outline),
                        ),
                        child: SelectableText(m.text,
                            style: TextStyle(height: 1.45, color: m.fromUser ? Colors.white : null)),
                      ),
                    );
                  },
                ),
        ),
        if (_busy) const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: LinearProgressIndicator()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Tulis pertanyaan...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Kirim',
                style: IconButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, minimumSize: const Size(52, 52)),
                onPressed: _busy ? null : _send,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ]),
          ),
        ),
      ])),
    );
  }
}
