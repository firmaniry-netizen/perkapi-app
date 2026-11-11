import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/phosphor_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/supabase_service.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/constants/app_tokens.dart';

/// Lampiran chat di bucket privat `chat-files/<thread_id>/<member_id>/<berkas>` (SQL 41).
/// Hanya peserta percakapan yang bisa membaca; tautan bertanda tangan berlaku 1 jam dan disimpan sementara.
class ChatFiles {
  ChatFiles._();
  static const bucket = 'chat-files';
  static const maxBytes = 25 * 1024 * 1024;
  static final _urls = <String, (String, DateTime)>{};

  static Future<String?> url(String? path) async {
    if (path == null || path.isEmpty) return null;
    final c = _urls[path];
    if (c != null && DateTime.now().isBefore(c.$2)) return c.$1;
    try {
      final u = await SupabaseService.client.storage.from(bucket).createSignedUrl(path, 3600);
      _urls[path] = (u, DateTime.now().add(const Duration(minutes: 50)));
      return u;
    } catch (_) {
      return null;
    }
  }

  /// Unggah lalu kembalikan path di bucket. Melempar [ChatUploadException] dengan pesan yang bisa ditampilkan.
  static Future<String> upload({
    required String threadId,
    required String memberId,
    required Uint8List bytes,
    required String name,
    String? mime,
  }) async {
    if (bytes.length > maxBytes) throw const ChatUploadException('Berkas lebih dari 25 MB.');
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final path = '$threadId/$memberId/${DateTime.now().millisecondsSinceEpoch}_$safe';
    try {
      await SupabaseService.client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime ?? mimeFor(name), upsert: false),
          );
      return path;
    } on StorageException catch (e) {
      throw ChatUploadException(e.statusCode == '403' ? 'Tidak diizinkan mengunggah ke percakapan ini.' : 'Gagal mengunggah berkas.');
    } catch (_) {
      throw const ChatUploadException('Gagal mengunggah berkas. Periksa koneksi.');
    }
  }

  static Future<void> remove(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await SupabaseService.client.storage.from(bucket).remove([path]);
    } catch (_) {}
  }

  static String mimeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    return const {
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'png': 'image/png',
          'webp': 'image/webp',
          'heic': 'image/heic',
          'pdf': 'application/pdf',
          'doc': 'application/msword',
          'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'xls': 'application/vnd.ms-excel',
          'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'ppt': 'application/vnd.ms-powerpoint',
          'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          'txt': 'text/plain',
          'zip': 'application/zip',
          'm4a': 'audio/mp4',
          'aac': 'audio/aac',
          'mp3': 'audio/mpeg',
        }[ext] ??
        'application/octet-stream';
  }
}

class ChatUploadException implements Exception {
  const ChatUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}

String fileSizeLabel(num? bytes) {
  final b = (bytes ?? 0).toDouble();
  if (b <= 0) return '';
  if (b < 1024) return '${b.toInt()} B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}

String durationLabel(Duration d) {
  final m = d.inMinutes, s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Foto di gelembung chat; ketuk untuk layar penuh (bisa dicubit untuk zoom).
class ChatImage extends StatefulWidget {
  const ChatImage({super.key, required this.path});
  final String path;
  @override
  State<ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends State<ChatImage> {
  late Future<String?> _url = ChatFiles.url(widget.path);

  @override
  void didUpdateWidget(ChatImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _url = ChatFiles.url(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snap) {
        final u = snap.data;
        final box = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160, maxHeight: 320),
            child: u == null
                ? Container(
                    width: 220,
                    height: 180,
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: snap.connectionState == ConnectionState.done
                        ? const Icon(Ph.image)
                        : const SizedBox(width: 22, height: 22, child: CircularProgressIndicator.adaptive(strokeWidth: 2)),
                  )
                : Image.network(u,
                    fit: BoxFit.cover,
                    cacheWidth: 900,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 220, height: 180, child: Icon(Ph.image))),
          ),
        );
        return GestureDetector(
          onTap: u == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: GlassAppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
                      body: Center(child: InteractiveViewer(maxScale: 5, child: Image.network(u))),
                    ),
                  )),
          child: box,
        );
      },
    );
  }
}

/// Dokumen: ikon, nama, ukuran. Ketuk untuk membuka/mengunduh.
class ChatFileTile extends StatelessWidget {
  const ChatFileTile({super.key, required this.path, required this.name, this.size, required this.mine});
  final String path;
  final String name;
  final num? size;
  final bool mine;

  IconData get _icon {
    final e = name.split('.').last.toLowerCase();
    if (e == 'pdf') return Ph.fileDoc;
    if (e.startsWith('doc')) return PhFill.fileText;
    if (e.startsWith('xls')) return Ph.table;
    if (e.startsWith('ppt')) return Ph.monitorPlay;
    return PhFill.file;
  }

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final u = await ChatFiles.url(path);
        if (u == null) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berkas tidak dapat dibuka.')));
          return;
        }
        await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: fg.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_icon, size: 34, color: fg),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
              if (fileSizeLabel(size).isNotEmpty) Text(fileSizeLabel(size), style: TextStyle(fontSize: AppType.caption, color: fg.withValues(alpha: 0.7))),
            ]),
          ),
          const SizedBox(width: 6),
          Icon(Ph.downloadSimple, size: 20, color: fg.withValues(alpha: 0.8)),
        ]),
      ),
    );
  }
}

/// Pesan suara: tombol putar/jeda, garis kemajuan, durasi.
class ChatAudioBubble extends StatefulWidget {
  const ChatAudioBubble({super.key, required this.path, this.durationMs, required this.mine});
  final String path;
  final int? durationMs;
  final bool mine;
  @override
  State<ChatAudioBubble> createState() => _ChatAudioBubbleState();
}

class _ChatAudioBubbleState extends State<ChatAudioBubble> {
  AudioPlayer? _p;
  final _subs = <StreamSubscription<dynamic>>[];
  Duration _pos = Duration.zero, _dur = Duration.zero;
  bool _playing = false, _loading = false;

  @override
  void initState() {
    super.initState();
    _dur = Duration(milliseconds: widget.durationMs ?? 0);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _p?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    var p = _p;
    if (p == null) {
      setState(() => _loading = true);
      final u = await ChatFiles.url(widget.path);
      if (!mounted) return;
      if (u == null) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesan suara tidak dapat diputar.')));
        return;
      }
      p = _p = AudioPlayer();
      _subs
        ..add(p.onPositionChanged.listen((d) {
          if (mounted) setState(() => _pos = d);
        }))
        ..add(p.onDurationChanged.listen((d) {
          if (mounted && d > Duration.zero) setState(() => _dur = d);
        }))
        ..add(p.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _playing = false;
              _pos = Duration.zero;
            });
          }
        }));
      await p.play(UrlSource(u));
      if (mounted) setState(() { _loading = false; _playing = true; });
      return;
    }
    if (_playing) {
      await p.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await p.resume();
      if (mounted) setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.mine ? Colors.white : Theme.of(context).colorScheme.primary;
    final total = _dur.inMilliseconds;
    final v = total <= 0 ? 0.0 : (_pos.inMilliseconds / total).clamp(0.0, 1.0);
    return SizedBox(
      width: 220,
      child: Row(children: [
        IconButton(
          onPressed: _toggle,
          icon: _loading
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2, backgroundColor: fg))
              : Icon(_playing ? PhFill.pause : PhFill.play, color: fg, size: 30),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: v, minHeight: 4, color: fg, backgroundColor: fg.withValues(alpha: 0.25)),
            ),
            const SizedBox(height: 4),
            Text(durationLabel(_playing || _pos > Duration.zero ? _pos : _dur),
                style: TextStyle(fontSize: AppType.micro, color: widget.mine ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

/// Perekam pesan suara (AAC .m4a). Mulai dengan [start]; [stop] mengembalikan berkas + durasi; [cancel] membuang.
class VoiceRecorder {
  final _rec = AudioRecorder();
  DateTime? _startedAt;
  String? _path;

  Future<bool> start() async {
    if (kIsWeb) return false;
    if (!await _rec.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1), path: _path!);
    _startedAt = DateTime.now();
    return true;
  }

  Future<(Uint8List, int)?> stop() async {
    final started = _startedAt;
    _startedAt = null;
    final p = await _rec.stop();
    if (p == null || started == null) return null;
    final ms = DateTime.now().difference(started).inMilliseconds;
    if (ms < 700) return null; // terlalu singkat: anggap tidak sengaja
    final f = File(p);
    final bytes = await f.readAsBytes();
    try {
      await f.delete();
    } catch (_) {}
    return (bytes, ms);
  }

  Future<void> cancel() async {
    _startedAt = null;
    final p = await _rec.stop();
    if (p == null) return;
    try {
      await File(p).delete();
    } catch (_) {}
  }

  void dispose() => _rec.dispose();
}
