import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/smooth_overlays.dart';

class AvatarException implements Exception {
  AvatarException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Unggah/hapus foto profil. Foto disimpan di bucket privat `avatars`:
/// - milik sendiri : `<auth.uid>/avatar_<ts>.<ext>`
/// - diubah admin  : `members/<member_id>/avatar_<ts>.<ext>` (butuh izin manage_member,
///   lihat sql/09_member_avatars.sql)
class AvatarUploader {
  static const maxBytes = 2 * 1024 * 1024;
  static SupabaseClient get _db => SupabaseService.client;

  static String? _kind(List<int> b) {
    if (b.length > 4 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'jpg';
    if (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'png';
    return null;
  }

  /// Mengembalikan path baru, atau null bila pengguna membatalkan.
  static Future<String?> pickAndUpload({
    required String memberId,
    required bool forSelf,
    String? oldPath,
  }) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    final f = res?.files.single;
    final bytes = f?.bytes;
    if (f == null || bytes == null) return null;
    if (bytes.length > maxBytes) throw AvatarException('Ukuran foto maksimal 2 MB.');
    final kind = _kind(bytes);
    if (kind == null) throw AvatarException('File harus berupa foto JPG atau PNG.');

    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw AvatarException('Sesi berakhir. Silakan masuk lagi.');
    final folder = forSelf ? uid : 'members/$memberId';
    final path = '$folder/avatar_${DateTime.now().millisecondsSinceEpoch}.$kind';

    try {
      await _db.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: kind == 'png' ? 'image/png' : 'image/jpeg'),
          );
    } on StorageException {
      throw AvatarException('Upload ditolak. Anda mungkin tidak memiliki izin.');
    } catch (_) {
      throw AvatarException('Gagal mengunggah foto. Periksa koneksi Anda.');
    }

    try {
      await _db.from('members').update({'avatar_path': path}).eq('id', memberId);
    } catch (_) {
      try {
        await _db.storage.from('avatars').remove([path]);
      } catch (_) {}
      throw AvatarException('Gagal menyimpan foto profil.');
    }
    await _discard(oldPath);
    return path;
  }

  static Future<void> remove({required String memberId, required String? oldPath}) async {
    try {
      await _db.from('members').update({'avatar_path': null}).eq('id', memberId);
    } catch (_) {
      throw AvatarException('Gagal menghapus foto profil.');
    }
    await _discard(oldPath);
  }

  static Future<void> _discard(String? path) async {
    if (path == null || path.isEmpty) return;
    AvatarService.invalidate(path);
    try {
      await _db.storage.from('avatars').remove([path]);
    } catch (_) {}
  }
}

/// Avatar besar dengan tombol kamera (ubah) dan hapus. Dipakai di Profil dan detail Anggota.
class AvatarEditor extends StatefulWidget {
  const AvatarEditor({
    super.key,
    required this.memberId,
    required this.forSelf,
    required this.name,
    required this.path,
    required this.canEdit,
    required this.onChanged,
    this.radius = 36,
  });
  final String memberId;
  final bool forSelf;
  final String name;
  final String? path;
  final bool canEdit;
  final ValueChanged<String?> onChanged;
  final double radius;

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  bool _busy = false;

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<String?> Function() job, String okMsg, {bool cancelIsNull = true}) async {
    setState(() => _busy = true);
    try {
      final p = await job();
      if (p == null && cancelIsNull) return;
      widget.onChanged(p);
      _snack(okMsg);
    } on AvatarException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change() => _run(
        () => AvatarUploader.pickAndUpload(
            memberId: widget.memberId, forSelf: widget.forSelf, oldPath: widget.path),
        'Foto profil diperbarui.',
      );

  Future<void> _remove() async {
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus foto profil?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await AvatarUploader.remove(memberId: widget.memberId, oldPath: widget.path);
      return null;
    }, 'Foto profil dihapus.', cancelIsNull: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = (widget.path ?? '').isNotEmpty;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [
        MemberAvatar(name: widget.name, path: widget.path, radius: widget.radius),
        if (widget.canEdit)
          Positioned(
            right: -4,
            bottom: -4,
            child: Material(
              color: scheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _busy ? null : _change,
                child: Tooltip(
                  message: hasPhoto ? 'Ganti foto' : 'Tambah foto',
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.camera_alt_outlined, size: 18, color: scheme.onPrimary),
                  ),
                ),
              ),
            ),
          ),
      ]),
      if (widget.canEdit && hasPhoto)
        TextButton(
          onPressed: _busy ? null : _remove,
          child: const Text('Hapus foto'),
        ),
    ]);
  }
}
