import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/ui_kit.dart';
import '../reports/export_service.dart';
import 'case_letters.dart';
import 'case_models.dart';

enum _To { all, one, general }

/// Formulir surat: data perkara/debitur/kreditur terisi otomatis, sisanya diisi di sini, hasilnya PDF.
class CaseLetterForm extends StatefulWidget {
  const CaseLetterForm({super.key, required this.ctx, required this.kind});
  final CaseContext ctx;
  final LetterKind kind;
  @override
  State<CaseLetterForm> createState() => _CaseLetterFormState();
}

class _CaseLetterFormState extends State<CaseLetterForm> {
  late final _number = TextEditingController();
  late final _city = TextEditingController();
  late final _officer = TextEditingController(text: widget.ctx.officerName);
  late final _address = TextEditingController();
  late final _place = TextEditingController();
  late final _agenda = TextEditingController();
  late final _attendees = TextEditingController();
  late final _outcome = TextEditingController();
  late final _judge = TextEditingController();

  DateTime _letterDate = today();
  DateTime? _meetDate;
  TimeOfDay? _meetTime;
  DateTime? _deadline;
  late _To _to = widget.ctx.creditors.isEmpty ? _To.general : _To.all;
  String? _creditorId;
  bool _busy = false;
  String? _error;

  LetterKind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _city.text = p.getString('letter_city') ?? '';
        _address.text = p.getString('letter_office_address') ?? '';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [_number, _city, _officer, _address, _place, _agenda, _attendees, _outcome, _judge]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) =>
      showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));

  DateTime? get _meetingAt {
    if (_meetDate == null) return null;
    final t = _meetTime ?? const TimeOfDay(hour: 10, minute: 0);
    return DateTime(_meetDate!.year, _meetDate!.month, _meetDate!.day, t.hour, t.minute);
  }

  List<Recipient> _recipients() {
    Recipient r(Map<String, dynamic> c) => (name: '${c['name'] ?? '-'}', address: '${c['address'] ?? ''}'.trim());
    final all = widget.ctx.creditors;
    switch (_to) {
      case _To.all:
        return [for (final c in all) r(c)];
      case _To.one:
        final c = all.where((e) => e['id'] == _creditorId);
        return c.isEmpty ? const [] : [r(c.first)];
      case _To.general:
        return const [];
    }
  }

  Future<void> _make() async {
    if (_city.text.trim().isEmpty || _officer.text.trim().isEmpty) {
      setState(() => _error = 'Kota dan nama ${widget.ctx.type.toUpperCase().contains('PKPU') ? 'pengurus' : 'kurator'} wajib diisi.');
      return;
    }
    if (kind.hasRecipients && _to == _To.one && _creditorId == null) {
      setState(() => _error = 'Pilih krediturnya.');
      return;
    }
    if (kind != LetterKind.pemberitahuan && _meetDate == null) {
      setState(() => _error = 'Tanggal rapat wajib diisi.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('letter_city', _city.text.trim());
      await p.setString('letter_office_address', _address.text.trim());
    } catch (_) {}
    try {
      final c = widget.ctx;
      final data = LetterData(
        kind: kind,
        caseNumber: c.number,
        caseTitle: c.title,
        caseType: c.type,
        court: c.court,
        debtorName: c.debtorName,
        officerName: _officer.text.trim(),
        officerAddress: _address.text.trim(),
        officerAhu: c.officerAhu,
        city: _city.text.trim(),
        letterDate: _letterDate,
        letterNumber: _number.text.trim(),
        recipients: kind.hasRecipients ? _recipients() : const [],
        meetingAt: _meetingAt,
        place: _place.text.trim(),
        agenda: _agenda.text.trim(),
        deadline: _deadline,
        attendees: _attendees.text.trim(),
        outcome: _outcome.text.trim(),
        judgeName: _judge.text.trim(),
      );
      final bytes = await buildLetterPdf(data);
      final safeNo = c.number.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      await ExportService.shareBytes('${kind.fileName}_$safeNo', 'pdf', bytes, 'application/pdf');
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal membuat PDF. Coba lagi.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _dateField(String label, DateTime? v, ValueChanged<DateTime> onPick, {DateTime? initial}) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final d = await _pickDate(v ?? initial ?? today());
          if (d != null) onPick(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_today_outlined)),
          child: Text(v == null ? 'Pilih tanggal' : hariTgl(v)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.ctx;
    final sc = Theme.of(context).colorScheme;
    final role = c.type.toUpperCase().contains('PKPU') ? 'Pengurus' : 'Kurator';
    Widget gap() => const SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: Text(kind.title, style: const TextStyle(fontSize: 16))),
      body: ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, 40 + MediaQuery.paddingOf(context).bottom), children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Terisi otomatis', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Perkara ${c.number}\n${c.title}\nDebitur: ${c.debtorName}\n$role: ${_officer.text}'
              '${c.officerAhu.isEmpty ? '' : '\nNo. SBP AHU: ${c.officerAhu}'}\nKreditur terdata: ${c.creditors.length}',
              style: TextStyle(fontSize: 13, height: 1.45, color: sc.onSurfaceVariant),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: _number, decoration: const InputDecoration(labelText: 'Nomor surat', prefixIcon: Icon(Icons.tag))),
            gap(),
            TextField(controller: _city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Kota penandatanganan', hintText: 'mis. Jakarta', prefixIcon: Icon(Icons.location_city_outlined))),
            gap(),
            _dateField('Tanggal surat', _letterDate, (d) => setState(() => _letterDate = d)),
            gap(),
            TextField(controller: _officer, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Nama $role', prefixIcon: const Icon(Icons.person_outline))),
            gap(),
            TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Alamat kantor (kop surat)', prefixIcon: Icon(Icons.home_work_outlined))),
          ]),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (kind != LetterKind.pemberitahuan) ...[
              _dateField('Tanggal rapat', _meetDate, (d) => setState(() => _meetDate = d)),
              gap(),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _meetTime ?? const TimeOfDay(hour: 10, minute: 0));
                  if (t != null) setState(() => _meetTime = t);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Jam rapat', prefixIcon: Icon(Icons.schedule)),
                  child: Text(_meetTime == null ? '10.00 (bawaan)' : '${_meetTime!.hour.toString().padLeft(2, '0')}.${_meetTime!.minute.toString().padLeft(2, '0')} WIB'),
                ),
              ),
              gap(),
            ],
            if (kind == LetterKind.pemberitahuan) ...[
              _dateField('Batas pengajuan tagihan', _deadline, (d) => setState(() => _deadline = d)),
              gap(),
            ],
            TextField(
              controller: _place,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: kind == LetterKind.pemberitahuan ? 'Tempat/alamat pengajuan tagihan' : 'Tempat rapat',
                prefixIcon: const Icon(Icons.place_outlined),
              ),
            ),
            if (kind != LetterKind.pemberitahuan) ...[
              gap(),
              TextField(controller: _agenda, maxLines: 3, decoration: const InputDecoration(labelText: 'Acara rapat', prefixIcon: Icon(Icons.list_alt_outlined))),
            ],
            if (kind == LetterKind.beritaAcara) ...[
              gap(),
              TextField(controller: _judge, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nama Hakim Pengawas (opsional)', prefixIcon: Icon(Icons.balance_outlined))),
              gap(),
              TextField(controller: _attendees, maxLines: 2, decoration: const InputDecoration(labelText: 'Yang hadir (opsional)', hintText: 'mis. 12 kreditur dan debitur', prefixIcon: Icon(Icons.groups_outlined))),
              gap(),
              TextField(controller: _outcome, maxLines: 6, decoration: const InputDecoration(labelText: 'Jalannya rapat dan hasil/keputusan', alignLabelWithHint: true)),
            ],
          ]),
        ),
        if (kind.hasRecipients) ...[
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Ditujukan kepada', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                if (c.creditors.isNotEmpty)
                  ChoiceChip(label: Text('Semua kreditur (${c.creditors.length} surat)'), selected: _to == _To.all, onSelected: (_) => setState(() => _to = _To.all)),
                if (c.creditors.isNotEmpty) ChoiceChip(label: const Text('Satu kreditur'), selected: _to == _To.one, onSelected: (_) => setState(() => _to = _To.one)),
                ChoiceChip(label: const Text('Para Kreditur (umum)'), selected: _to == _To.general, onSelected: (_) => setState(() => _to = _To.general)),
              ]),
              if (_to == _To.one) ...[
                gap(),
                DropdownButtonFormField<String>(
                  value: _creditorId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Pilih kreditur'),
                  items: [for (final k in c.creditors) DropdownMenuItem(value: k['id'] as String, child: Text('${k['name']}', overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => setState(() => _creditorId = v),
                ),
              ],
            ]),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 18),
        PrimaryButton(label: _busy ? 'Membuat PDF...' : 'Buat PDF', icon: Icons.picture_as_pdf_rounded, loading: _busy, onPressed: _busy ? null : _make),
        const SizedBox(height: 10),
        Text('Isi surat adalah draf umum. Periksa dan sesuaikan sebelum dikirim.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: sc.onSurfaceVariant)),
      ]),
    );
  }
}
