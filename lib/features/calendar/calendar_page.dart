import 'package:flutter/material.dart';
import '../../core/constants/phosphor_icons.dart';
import '../../core/widgets/page_glow.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/supabase_service.dart';
import '../../shared/widgets/state_widgets.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/constants/app_tokens.dart';

class _Entry {
  _Entry(this.kind, this.title, this.subtitle, this.route, this.when);
  final String kind; // event | task | case
  final String title, subtitle, route;
  final DateTime when;
}

/// Kalender: agenda dan event organisasi dalam satu tampilan bulanan.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  late DateTime _month;
  late DateTime _selected;
  final Map<DateTime, List<_Entry>> _byDay = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
    _selected = DateTime(n.year, n.month, n.day);
    _load();
  }


  void _add(_Entry e) {
    final k = DateTime(e.when.year, e.when.month, e.when.day);
    (_byDay[k] ??= []).add(e);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _byDay.clear();
    });
    final db = SupabaseService.client;
    final start = _month;
    final end = DateTime(_month.year, _month.month + 1);
    try {
      final ev = await db
          .from('events')
          .select('id,title,location,starts_at')
          .gte('starts_at', start.toUtc().toIso8601String())
          .lt('starts_at', end.toUtc().toIso8601String())
          .order('starts_at', ascending: true);
      for (final r in ev) {
        final t = DateTime.tryParse('${r['starts_at']}')?.toLocal();
        if (t == null) continue;
        String two(int n) => n.toString().padLeft(2, '0');
        _add(_Entry('event', '${r['title']}', '${two(t.hour)}:${two(t.minute)} • ${r['location'] ?? 'Lokasi belum diisi'}',
            '/module/events/${r['id']}', t));
      }
    } catch (_) {
      _error = 'Gagal memuat kalender. Periksa koneksi Anda.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _shift(int delta) {
    _month = DateTime(_month.year, _month.month + delta);
    _selected = DateTime(_month.year, _month.month, 1);
    _load();
  }

  Color _color(String kind) => const Color(0xFF1565C0);

  IconData _icon(String kind) => Ph.calendarBlank;

  @override
  Widget build(BuildContext context) {
    final first = _month;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1; // Senin = 0
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final selected = _byDay[_selected] ?? const <_Entry>[];

    return Scaffold(
      extendBodyBehindAppBar: true, // ListView tanpa padding: otomatis mulai di bawah bar kaca
      appBar: GlassAppBar(title: const Text('Kalender')),
      body: PageGlow(accent: AppColors.orange, child: _error != null && !_loading
          ? ErrorState(message: _error!, onRetry: _load)
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: ScreenHero(
                  title: 'Kalender',
                  subtitle: 'Agenda dan kegiatan organisasi',
                  icon: Ph.calendarBlank,
                  accent: AppColors.orange,
                ),
              ),
              // Bulan dalam satu kartu (navigasi bulan, nama hari, kisi tanggal) seperti kalender iOS.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(children: [
                  IconButton(onPressed: () => _shift(-1), icon: const Icon(Ph.caretLeft), tooltip: 'Bulan sebelumnya'),
                  Expanded(
                    child: Text('${_months[_month.month - 1]} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(onPressed: () => _shift(1), icon: const Icon(Ph.caretRight), tooltip: 'Bulan berikutnya'),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  for (final d in _days)
                    Expanded(
                      child: Center(
                          child: Text(d, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700))),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lead + daysInMonth,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7, childAspectRatio: 1.1),
                  itemBuilder: (_, i) {
                    if (i < lead) return const SizedBox.shrink();
                    final day = DateTime(_month.year, _month.month, i - lead + 1);
                    final entries = _byDay[day] ?? const <_Entry>[];
                    final isSel = day == _selected;
                    final isToday = day == todayKey;
                    final kinds = entries.map((e) => e.kind).toSet().toList();
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      onTap: () => setState(() => _selected = day),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSel ? Theme.of(context).colorScheme.primary : null,
                          border: isToday
                              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                              : null,
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('${day.day}',
                              style: TextStyle(
                                  fontWeight: isToday || isSel ? FontWeight.w700 : FontWeight.w500,
                                  color: isSel ? Theme.of(context).colorScheme.onPrimary : null)),
                          const SizedBox(height: 3),
                          SizedBox(
                            height: 6,
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              for (final k in kinds.take(3))
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(color: _color(k), shape: BoxShape.circle),
                                ),
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
                  ]),
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(children: [
                  for (final k in const ['event']) ...[
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _color(k), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('Event', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(width: 12),
                  ],
                ]),
              ),
              const Divider(height: 1),
              if (selected.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                      child: Text(_loading
                          ? ''
                          : 'Tidak ada agenda pada ${_selected.day} ${_months[_selected.month - 1]}.')),
                )
              else
                for (final e in selected)
                  Reveal(
                    dy: 12,
                    child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                    child: AppCard(
                      radius: 20,
                      padding: const EdgeInsets.all(14),
                      onTap: () => context.push(e.route),
                      child: Row(children: [
                        IconBadge(_icon(e.kind), color: _color(e.kind), size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(e.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: AppType.small, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ]),
                        ),
                        Icon(Ph.caretRight, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ]),
                    ),
                  ),
                  ),
              const SizedBox(height: 120),
                ]),
              ),
            )),
    );
  }
}
