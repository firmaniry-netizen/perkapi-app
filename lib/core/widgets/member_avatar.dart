import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

/// Cache URL bertanda tangan untuk foto profil (bucket privat `avatars`).
/// URL berlaku 1 jam; disimpan 50 menit di memori agar daftar anggota tidak
/// meminta URL berulang kali saat di-scroll.
class AvatarService {
  AvatarService._();

  static const _ttl = Duration(minutes: 50);
  static final Map<String, (String, DateTime)> _cache = {};
  static final Map<String, Future<String?>> _pending = {};

  static Future<String?> url(String path) {
    final hit = _cache[path];
    if (hit != null && DateTime.now().isBefore(hit.$2)) return Future.value(hit.$1);
    return _pending[path] ??= _fetch(path).whenComplete(() => _pending.remove(path));
  }

  static Future<String?> _fetch(String path) async {
    try {
      final u = await SupabaseService.client.storage.from('avatars').createSignedUrl(path, 3600);
      _cache[path] = (u, DateTime.now().add(_ttl));
      return u;
    } catch (_) {
      return null; // tampilkan inisial
    }
  }

  static void invalidate(String? path) {
    if (path != null) _cache.remove(path);
  }

  static void clear() {
    _cache.clear();
    _pending.clear();
  }
}

/// Avatar anggota: foto bila ada, jika tidak (atau gagal dimuat) inisial nama.
class MemberAvatar extends StatefulWidget {
  const MemberAvatar({super.key, required this.name, this.path, this.radius = 22});
  final String name;
  final String? path;
  final double radius;

  @override
  State<MemberAvatar> createState() => _MemberAvatarState();
}

class _MemberAvatarState extends State<MemberAvatar> {
  Future<String?>? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant MemberAvatar old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _resolve();
  }

  void _resolve() {
    final p = widget.path;
    _url = (p == null || p.isEmpty) ? null : AvatarService.url(p);
  }

  String get _initial {
    final n = widget.name.trim();
    return n.isEmpty ? '?' : String.fromCharCode(n.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: widget.name.isEmpty ? 'Foto anggota' : 'Foto ${widget.name}',
      child: ExcludeSemantics(
        child: FutureBuilder<String?>(
          future: _url,
          builder: (context, snap) {
            final u = snap.data;
            return CircleAvatar(
              radius: widget.radius,
              backgroundColor: scheme.primaryContainer,
              foregroundImage: u == null ? null : NetworkImage(u),
              onForegroundImageError: u == null ? null : (_, __) {},
              child: Text(
                _initial,
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: widget.radius * 0.8,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
