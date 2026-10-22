import 'package:flutter/material.dart';

import '../../core/constants/app_tokens.dart';
import '../../core/utils/format_id.dart';

import '../../core/widgets/illustrations.dart';

Widget _stateIcon(BuildContext context, IconData icon, Color tone) => Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: tone.withValues(alpha: 0.10),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: 36, color: tone),
    );

/// Keadaan kosong: ilustrasi yang melayang pelan, judul, penjelasan, dan (bila ada) SATU tombol aksi
/// yang mengarahkan pengguna ke langkah berikutnya. Gerak melayang mati saat "kurangi gerak".
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.message = 'Belum ada data',
    this.icon = Icons.inbox_outlined,
    this.title,
    this.actionLabel,
    this.onAction,
  });
  final String message;
  final IconData icon;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Float(child: EmptyArt(icon: icon)),
          const SizedBox(height: 18),
          if (title != null) ...[
            Text(title!, textAlign: TextAlign.center, style: AppType.headline(20, color: scheme.onSurface)),
            const SizedBox(height: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14, height: 1.5)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Melayang naik-turun 6 px dalam 3,2 detik (ilustrasi keadaan kosong).
class _Float extends StatefulWidget {
  const _Float({required this.child});
  final Widget child;
  @override
  State<_Float> createState() => _FloatState();
}

class _FloatState extends State<_Float> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, c) => Transform.translate(offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)), child: c),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _stateIcon(context, Icons.cloud_off_rounded, scheme.error),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.5)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
            ),
          ],
        ]),
      ),
    );
  }
}

class AccessDenied extends StatelessWidget {
  const AccessDenied({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: EmptyState(
          icon: Icons.lock_outline,
          message: 'Akses ditolak.\nRole Anda tidak memiliki izin untuk halaman ini.',
        ),
      );
}

/// Chip status: warna semantik + teks (warna tidak berdiri sendiri).
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key});
  final String label;

  Color _tone() => toneFor(label);

  /// Warna semantik status; dipakai juga untuk garis aksen kartu daftar.
  static Color toneFor(String label) {
    final l = label.toLowerCase();
    // Urutan penting: merah lebih dulu agar "Nonaktif"/"Tidak hadir" tidak ikut dianggap hijau
    // karena mengandung kata "aktif"/"hadir".
    if (RegExp(r'ditolak|batal|nonaktif|tidak hadir|gagal|terlambat|mendesak|urgent|dihapus').hasMatch(l)) {
      return const Color(0xFFB3261E);
    }
    if (RegExp(r'menunggu|proses|draft|tertunda|pending|baru|belum').hasMatch(l)) return const Color(0xFFB26A00);
    if (RegExp(r'aktif|selesai|disetujui|terbayar|hadir|dibaca|lunas').hasMatch(l)) return const Color(0xFF1B7F4B);
    return const Color(0xFF3B5BA5);
  }

  @override
  Widget build(BuildContext context) {
    final c = _tone();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c))),
      ]),
    );
  }
}

/// Nilai database -> teks tampilan. Tanggal/jam ISO menjadi "21 Okt 2026" atau "21 Okt 2026 • 09.30" (waktu lokal).
String fmtValue(dynamic v) {
  if (v == null) return '';
  final s = v.toString();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}.*)?$').hasMatch(s)) {
    final out = FmtId.value(s);
    if (out.isNotEmpty) return out;
  }
  return s;
}
