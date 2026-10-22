import 'package:flutter/material.dart';

/// Penampil Markdown sederhana (tanpa paket tambahan).
/// Didukung: # / ## / ### judul, **tebal**, *miring* / _miring_, `kode`,
/// daftar (- / * / 1.), checklist (- [ ] / - [x]), kutipan (>), garis (---).
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.data, {super.key});
  final String data;

  static final _inline = RegExp(r'(\*\*[^*\n]+\*\*|\*[^*\n]+\*|_[^_\n]+_|`[^`\n]+`)');

  static List<InlineSpan> _spans(String text, TextStyle base) {
    final out = <InlineSpan>[];
    var i = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > i) out.add(TextSpan(text: text.substring(i, m.start), style: base));
      final t = m.group(0)!;
      if (t.startsWith('**')) {
        out.add(TextSpan(text: t.substring(2, t.length - 2), style: base.copyWith(fontWeight: FontWeight.w800)));
      } else if (t.startsWith('`')) {
        out.add(TextSpan(
            text: t.substring(1, t.length - 1),
            style: base.copyWith(fontFamily: 'monospace', backgroundColor: const Color(0x22888888))));
      } else {
        out.add(TextSpan(text: t.substring(1, t.length - 1), style: base.copyWith(fontStyle: FontStyle.italic)));
      }
      i = m.end;
    }
    if (i < text.length) out.add(TextSpan(text: text.substring(i), style: base));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium ?? const TextStyle();
    final children = <Widget>[];

    Widget line(Widget child, {double top = 4}) =>
        Padding(padding: EdgeInsets.only(top: top), child: child);

    for (final raw in data.split('\n')) {
      final l = raw.trimRight();
      if (l.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }
      final h = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(l);
      if (h != null) {
        final lvl = h.group(1)!.length;
        final size = lvl == 1 ? 22.0 : (lvl == 2 ? 19.0 : 16.0);
        children.add(line(
            Text.rich(TextSpan(children: _spans(h.group(2)!, base.copyWith(fontSize: size, fontWeight: FontWeight.w800)))),
            top: 10));
        continue;
      }
      if (RegExp(r'^\s*(-{3,}|\*{3,})\s*$').hasMatch(l)) {
        children.add(const Divider());
        continue;
      }
      final q = RegExp(r'^>\s?(.*)$').firstMatch(l);
      if (q != null) {
        children.add(line(Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFF9E9E9E), width: 3))),
          child: Text.rich(TextSpan(children: _spans(q.group(1)!, base.copyWith(fontStyle: FontStyle.italic)))),
        )));
        continue;
      }
      final cb = RegExp(r'^\s*[-*]\s+\[( |x|X)\]\s+(.*)$').firstMatch(l);
      if (cb != null) {
        final done = cb.group(1)!.toLowerCase() == 'x';
        children.add(line(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(done ? Icons.check_box : Icons.check_box_outline_blank, size: 18),
          const SizedBox(width: 6),
          Expanded(
              child: Text.rich(TextSpan(
                  children: _spans(cb.group(2)!,
                      base.copyWith(decoration: done ? TextDecoration.lineThrough : null))))),
        ])));
        continue;
      }
      final ul = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(l);
      if (ul != null) {
        children.add(line(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(left: 4, right: 8), child: Text('•')),
          Expanded(child: Text.rich(TextSpan(children: _spans(ul.group(1)!, base)))),
        ])));
        continue;
      }
      final ol = RegExp(r'^\s*(\d+)[.)]\s+(.*)$').firstMatch(l);
      if (ol != null) {
        children.add(line(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(left: 4, right: 8), child: Text('${ol.group(1)}.')),
          Expanded(child: Text.rich(TextSpan(children: _spans(ol.group(2)!, base)))),
        ])));
        continue;
      }
      children.add(line(Text.rich(TextSpan(children: _spans(l, base)))));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

/// Editor Markdown dengan toolbar format + pratinjau.
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.enabled = true,
  });
  final String label, initialValue;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late final TextEditingController _c = TextEditingController(text: widget.initialValue);
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _preview = !widget.enabled;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _apply(String text, TextSelection sel) {
    _c.value = TextEditingValue(text: text, selection: sel);
    widget.onChanged(text);
  }

  TextSelection get _sel {
    final s = _c.selection;
    if (s.start < 0 || s.end < 0) {
      return TextSelection.collapsed(offset: _c.text.length);
    }
    return s;
  }

  void _wrap(String left, String right) {
    final s = _sel;
    final text = _c.text;
    final selected = text.substring(s.start, s.end);
    final next = text.replaceRange(s.start, s.end, '$left$selected$right');
    if (selected.isEmpty) {
      _apply(next, TextSelection.collapsed(offset: s.start + left.length));
    } else {
      _apply(next, TextSelection(baseOffset: s.start, extentOffset: s.end + left.length + right.length));
    }
  }

  void _prefix(String Function(int index) prefixFor) {
    final s = _sel;
    final text = _c.text;
    final lineStart = s.start == 0 ? 0 : text.lastIndexOf('\n', s.start - 1) + 1;
    final lines = text.substring(lineStart, s.end).split('\n');
    final changed = [for (var i = 0; i < lines.length; i++) '${prefixFor(i)}${lines[i]}'].join('\n');
    final next = text.replaceRange(lineStart, s.end, changed);
    _apply(next, TextSelection.collapsed(offset: lineStart + changed.length));
  }

  Widget _btn(IconData icon, String tip, VoidCallback onTap) => IconButton(
        tooltip: tip,
        icon: Icon(icon, size: 20),
        visualDensity: VisualDensity.compact,
        onPressed: widget.enabled && !_preview ? onTap : null,
      );

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(widget.label, style: Theme.of(context).textTheme.labelLarge)),
        if (widget.enabled)
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: false, label: Text('Tulis')),
              ButtonSegment(value: true, label: Text('Pratinjau')),
            ],
            selected: {_preview},
            onSelectionChanged: (s) => setState(() => _preview = s.first),
          ),
      ]),
      if (widget.enabled)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _btn(Icons.title, 'Judul', () => _prefix((_) => '## ')),
            _btn(Icons.format_bold, 'Tebal', () => _wrap('**', '**')),
            _btn(Icons.format_italic, 'Miring', () => _wrap('_', '_')),
            _btn(Icons.format_list_bulleted, 'Daftar', () => _prefix((_) => '- ')),
            _btn(Icons.format_list_numbered, 'Daftar nomor', () => _prefix((i) => '${i + 1}. ')),
            _btn(Icons.check_box_outlined, 'Checklist', () => _prefix((_) => '- [ ] ')),
            _btn(Icons.format_quote, 'Kutipan', () => _prefix((_) => '> ')),
            _btn(Icons.code, 'Kode', () => _wrap('`', '`')),
          ]),
        ),
      const SizedBox(height: 4),
      if (_preview)
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _c.text.trim().isEmpty ? const Text('-') : MarkdownView(_c.text),
        )
      else
        TextField(
          controller: _c,
          minLines: 6,
          maxLines: 16,
          onChanged: widget.onChanged,
          decoration: const InputDecoration(hintText: 'Tulis di sini. Gunakan tombol format di atas.'),
        ),
    ]);
  }
}
