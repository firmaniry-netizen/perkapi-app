import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/widgets/ui_kit.dart';

/// Kerangka halaman panduan: AppBar + cahaya aksen + hero di atas + isi berupa kartu.
class GuideScaffold extends StatelessWidget {
  const GuideScaffold({super.key, required this.title, required this.accent, required this.hero, required this.children});
  final String title;
  final Color accent;
  final Widget hero;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PageGlow(
        accent: accent,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            Reveal(index: 0, dy: -12, child: hero),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Daftar poin bernomor atau berbintik di dalam kartu.
class GuideList extends StatelessWidget {
  const GuideList(this.items, {super.key, this.numbered = false});
  final List<String> items;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 26,
              child: numbered
                  ? Text('${i + 1}.', style: TextStyle(fontWeight: FontWeight.w800, color: sc.primary))
                  : Padding(
                      padding: const EdgeInsets.only(top: 7, left: 4),
                      child: Container(width: 6, height: 6, decoration: BoxDecoration(color: sc.primary, shape: BoxShape.circle)),
                    ),
            ),
            Expanded(child: Text(items[i], style: const TextStyle(height: 1.4))),
          ]),
        ),
    ]);
  }
}

/// Daftar periksa yang bisa dicentang (hanya untuk membantu persiapan; tidak disimpan).
class GuideChecklist extends StatefulWidget {
  const GuideChecklist(this.items, {super.key});
  final List<String> items;
  @override
  State<GuideChecklist> createState() => _GuideChecklistState();
}

class _GuideChecklistState extends State<GuideChecklist> {
  late final List<bool> _done = List<bool>.filled(widget.items.length, false);

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    final count = _done.where((e) => e).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('$count dari ${widget.items.length} siap', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sc.onSurfaceVariant)),
      ),
      for (var i = 0; i < widget.items.length; i++)
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _done[i] = !_done[i]),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_done[i] ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 22, color: _done[i] ? AppColors.emerald : sc.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.items[i],
                  style: TextStyle(height: 1.4, color: _done[i] ? sc.onSurfaceVariant : null, decoration: _done[i] ? TextDecoration.lineThrough : null),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Kotak penekanan (batas waktu, catatan penting).
class GuideCallout extends StatelessWidget {
  const GuideCallout({super.key, required this.text, this.icon = Icons.info_outline_rounded, this.color = AppColors.sky});
  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppColors.onSoft(color, dark: dark);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.soft(color, dark: dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: fg),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.4, fontSize: 14))),
      ]),
    );
  }
}

/// Kartu berjudul: judul + isi bebas.
class GuideCard extends StatelessWidget {
  const GuideCard({super.key, required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(title),
      const SizedBox(height: 8),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (subtitle != null) ...[
            Text(subtitle!, style: TextStyle(fontSize: 13, height: 1.4, color: sc.onSurfaceVariant)),
            const SizedBox(height: 12),
          ],
          child,
        ]),
      ),
    ]);
  }
}

/// Tombol salin teks ke papan klip.
class CopyButton extends StatelessWidget {
  const CopyButton({super.key, required this.text, this.label = 'Salin format'});
  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Format disalin. Tempel di dokumen Anda.')));
        }
      },
      icon: const Icon(Icons.copy_rounded),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );
  }
}

/// Catatan sumber di bagian bawah halaman panduan.
class GuideSource extends StatelessWidget {
  const GuideSource({super.key});

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Text(
        'Ringkasan dari Peraturan Menteri Hukum dan HAM No. 37 Tahun 2018 tentang Syarat dan Tata Cara Pendaftaran serta Penyampaian Laporan Kurator dan Pengurus. '
        'Ini bukan nasihat hukum. Aturan dan formulir di laman resmi AHU dapat berubah, jadi pastikan lagi di ahu.go.id sebelum mengajukan.',
        style: TextStyle(fontSize: 12, height: 1.45, color: sc.onSurfaceVariant),
      ),
    );
  }
}
