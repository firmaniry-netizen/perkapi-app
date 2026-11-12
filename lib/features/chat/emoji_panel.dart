import 'package:flutter/material.dart';

import '../../core/constants/phosphor_icons.dart';

/// Panel emoji pengganti keyboard di kolom pesan, seperti WhatsApp: baris kategori di atas, kisi emoji di bawah,
/// tombol hapus di kanan atas. Emoji digambar oleh huruf emoji bawaan HP, tanpa paket tambahan.
class EmojiPanel extends StatefulWidget {
  const EmojiPanel({super.key, required this.onEmoji, this.onBackspace});
  final ValueChanged<String> onEmoji;

  /// Null = tanpa tombol hapus (dipakai saat memilih reaksi).
  final VoidCallback? onBackspace;

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<EmojiPanel> {
  int _cat = 0;

  static const _cats = <(String, String, List<String>)>[
    ('Wajah', '😀', [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩',
      '😘', '😗', '😚', '😙', '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨',
      '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '😌', '😔', '😪', '😴', '😷', '🤒', '🤕', '🤢', '🥵',
      '🥶', '😵', '🤯', '🤠', '🥳', '😎', '🤓', '🧐', '😕', '😟', '🙁', '😮', '😯', '😲', '😳', '🥺',
      '😦', '😧', '😨', '😰', '😥', '😢', '😭', '😱', '😖', '😣', '😞', '😓', '😩', '😫', '🥱', '😤',
      '😡', '😠', '🤬', '😈', '💀', '💩', '🤡', '👻', '👽', '🤖',
    ]),
    ('Tangan', '👍', [
      '👍', '👎', '👌', '🤌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇', '☝️', '✋', '🤚',
      '🖐️', '🖖', '👋', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️', '💪', '🫡', '🫶', '👀', '🧠', '🫂',
    ]),
    ('Hati', '❤️', [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
      '💘', '💝', '💯', '💢', '💥', '💫', '💦', '💨', '🔥', '✨', '⭐', '🌟', '🎉', '🎊', '🎁', '🏆',
    ]),
    ('Kerja', '💼', [
      '💼', '📁', '📂', '📄', '📑', '📊', '📈', '📉', '📌', '📍', '📎', '🖊️', '✏️', '📝', '📅', '📆',
      '⏰', '⌛', '📞', '📱', '💻', '🖨️', '📧', '📨', '🔔', '🔒', '🔑', '⚖️', '🏛️', '🏢', '🤝', '✅',
      '☑️', '❌', '⚠️', '❗', '❓', '💡', '📢', '🗓️',
    ]),
    ('Lainnya', '☕', [
      '☕', '🍵', '🍚', '🍜', '🍲', '🍔', '🍕', '🍰', '🎂', '🍎', '🍌', '🍉', '🚗', '🛵', '✈️', '🚆',
      '🏠', '🕌', '⛪', '🌙', '☀️', '🌧️', '⚡', '🌈', '🌹', '🌻', '🐱', '🐶', '⚽', '🏸', '🎵', '🇮🇩',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emojis = _cats[_cat].$3;
    return SizedBox(
      height: 280,
      child: Column(children: [
        Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                for (var i = 0; i < _cats.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Tooltip(
                      message: _cats[i].$1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _cat = i),
                        child: Container(
                          width: 44,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == _cat ? scheme.onSurface.withValues(alpha: 0.08) : null,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(_cats[i].$2, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          if (widget.onBackspace != null)
            IconButton(
              tooltip: 'Hapus',
              onPressed: widget.onBackspace,
              icon: const Icon(Ph.backspace),
            ),
        ]),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 46, mainAxisExtent: 46),
            itemCount: emojis.length,
            itemBuilder: (_, i) => InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => widget.onEmoji(emojis[i]),
              child: Center(child: Text(emojis[i], style: const TextStyle(fontSize: 28))),
            ),
          ),
        ),
      ]),
    );
  }
}
