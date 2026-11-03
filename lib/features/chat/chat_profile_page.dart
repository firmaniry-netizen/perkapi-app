import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/services/online_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/member_avatar.dart';
import 'call_service.dart';
import 'chat_media.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/motion.dart';
import '../../core/constants/app_tokens.dart';

/// Info kontak / info grup, seperti WhatsApp: foto, nama, status online, tombol pesan/telepon/video,
/// data keanggotaan, serta foto & dokumen yang pernah dikirim di percakapan ini.
///
/// - Chat pribadi: [memberId] diisi, [threadId] = percakapan berdua.
/// - Grup: [isGroup] true, [threadId] diisi; ketuk anggota untuk melihat profilnya.
/// - Profil anggota dari daftar grup: [memberId] diisi, [threadId] boleh null (tanpa media).
class ChatProfilePage extends StatefulWidget {
  const ChatProfilePage({super.key, this.threadId, this.memberId, this.isGroup = false, this.title = ''});
  final String? threadId;
  final String? memberId;
  final bool isGroup;
  final String title;

  @override
  State<ChatProfilePage> createState() => _ChatProfilePageState();
}

class _ChatProfilePageState extends State<ChatProfilePage> {
  final _db = SupabaseService.client;
  Map<String, dynamic>? _p;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _media = [];
  bool _loading = true;

  String? get _me => Access.instance.memberId;

  @override
  void initState() {
    super.initState();
    OnlineService.instance.online.addListener(_rebuild);
    _load();
  }

  @override
  void dispose() {
    OnlineService.instance.online.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      if (!widget.isGroup && widget.memberId != null) {
        final r = List<Map<String, dynamic>>.from(await _db.rpc('chat_member_profile', params: {'p_member': widget.memberId}) as List);
        if (r.isNotEmpty) _p = r.first;
      }
      if (widget.isGroup && widget.threadId != null) {
        _members = List<Map<String, dynamic>>.from(await _db.rpc('chat_thread_members', params: {'p_thread': widget.threadId}) as List)
          ..sort((a, b) => '${a['name']}'.toLowerCase().compareTo('${b['name']}'.toLowerCase()));
      }
      if (widget.threadId != null) {
        _media = List<Map<String, dynamic>>.from(await _db
            .from('chat_messages')
            .select('id,kind,attachment_path,attachment_name,attachment_size,created_at')
            .eq('thread_id', widget.threadId!)
            .inFilter('kind', ['image', 'file'])
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false)
            .limit(60));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _launch(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka.')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = widget.isGroup ? widget.title : '${_p?['name'] ?? widget.title}';
    final online = !widget.isGroup && OnlineService.instance.isOnline(widget.memberId);
    final images = _media.where((m) => m['kind'] == 'image').toList();
    final files = _media.where((m) => m['kind'] == 'file').toList();
    final canCall = !widget.isGroup && widget.threadId != null && widget.memberId != null && widget.memberId != _me;

    return Scaffold(
      appBar: GlassAppBar(title: Text(widget.isGroup ? 'Info grup' : 'Info kontak')),
      body: _loading
          ? const SkeletonList()
          : ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              const SizedBox(height: 16),
              Center(
                child: widget.isGroup
                    ? CircleAvatar(radius: 56, backgroundColor: AppColors.navyAction, child: const Icon(CupertinoIcons.person_3_fill, size: 56, color: Colors.white))
                    : GestureDetector(
                        onTap: () => _showPhoto(name, _p?['avatar_path'] as String?),
                        child: MemberAvatar(name: name, path: _p?['avatar_path'] as String?, radius: 56),
                      ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isGroup ? 'Grup · ${_members.length} anggota' : (online ? 'online' : (_p?['member_number'] != null ? 'No. anggota ${_p!['member_number']}' : 'Anggota PERKAPI')),
                textAlign: TextAlign.center,
                style: TextStyle(color: online ? AppColors.emerald : scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _Action(icon: CupertinoIcons.chat_bubble_fill, label: 'Pesan', onTap: () => Navigator.of(context).maybePop()),
                if (canCall) ...[
                  _Action(
                    icon: CupertinoIcons.phone_fill,
                    label: 'Telepon',
                    onTap: () => CallService.instance.call(context, threadId: widget.threadId!, peerId: widget.memberId!, peerName: name, video: false),
                  ),
                  _Action(
                    icon: CupertinoIcons.videocam_fill,
                    label: 'Video',
                    onTap: () => CallService.instance.call(context, threadId: widget.threadId!, peerId: widget.memberId!, peerName: name, video: true),
                  ),
                ],
              ]),
              const SizedBox(height: 12),
              if (!widget.isGroup && _p != null) _infoCard(scheme),
              if (images.isNotEmpty || files.isNotEmpty) _mediaCard(scheme, images, files),
              if (widget.isGroup) _membersCard(scheme),
            ]),
    );
  }

  Widget _infoCard(ColorScheme scheme) {
    final p = _p!;
    String? s(Object? v) => (v == null || '$v'.trim().isEmpty) ? null : '$v'.trim();
    final joined = DateTime.tryParse('${p['joined_at']}')?.toLocal();
    const bln = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final tiles = <Widget>[
      if (s(p['member_number']) != null) _tile(CupertinoIcons.person_crop_rectangle, 'Nomor anggota', s(p['member_number'])!),
      if (s(p['branch']) != null) _tile(CupertinoIcons.building_2_fill, 'Cabang', s(p['branch'])!),
      if (p['ahu_verified'] == true)
        _tile(CupertinoIcons.checkmark_seal_fill, 'Terdaftar di AHU', s(p['ahu_registration_number']) ?? 'Terverifikasi', color: AppColors.emerald),
      if (joined != null) _tile(CupertinoIcons.calendar_badge_plus, 'Anggota sejak', '${joined.day} ${bln[joined.month - 1]} ${joined.year}'),
      if (s(p['phone']) != null)
        _tile(CupertinoIcons.phone, 'Telepon', s(p['phone'])!, onTap: () => _launch('tel:${s(p['phone'])!.replaceAll(RegExp(r'[^0-9+]'), '')}')),
      if (s(p['email']) != null) _tile(CupertinoIcons.mail, 'Email', s(p['email'])!, onTap: () => _launch('mailto:${s(p['email'])}')),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return _section(scheme, 'Info', Column(children: tiles));
  }

  Widget _mediaCard(ColorScheme scheme, List<Map<String, dynamic>> images, List<Map<String, dynamic>> files) {
    return _section(
      scheme,
      'Media & dokumen (${images.length + files.length})',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (images.isNotEmpty)
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => SizedBox(width: 96, height: 96, child: ChatImage(path: '${images[i]['attachment_path']}')),
            ),
          ),
        for (final f in files.take(10))
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ChatFileTile(path: '${f['attachment_path']}', name: '${f['attachment_name'] ?? 'Dokumen'}', size: f['attachment_size'] as num?, mine: false),
          ),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _membersCard(ColorScheme scheme) {
    return _section(
      scheme,
      '${_members.length} anggota',
      Column(children: [
        for (final m in _members)
          ListTile(
            leading: MemberAvatar(name: '${m['name']}', radius: 20),
            title: Text('${m['member_id']}' == _me ? 'Anda' : '${m['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: OnlineService.instance.isOnline('${m['member_id']}') ? const Text('online', style: TextStyle(color: AppColors.emerald)) : null,
            onTap: '${m['member_id']}' == _me
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ChatProfilePage(memberId: '${m['member_id']}', title: '${m['name']}'),
                    )),
          ),
      ]),
    );
  }

  Widget _section(ColorScheme scheme, String title, Widget child) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
        ),
        child,
      ]),
    );
  }

  Widget _tile(IconData icon, String label, String value, {VoidCallback? onTap, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.navyAction),
      title: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(label),
      onTap: onTap,
      trailing: onTap == null ? null : const Icon(CupertinoIcons.chevron_right),
    );
  }

  void _showPhoto(String name, String? path) {
    if (path == null || path.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: GlassAppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(name)),
        body: FutureBuilder<String?>(
          future: AvatarService.url(path),
          builder: (_, s) => Center(
            child: s.data == null ? const CircularProgressIndicator() : InteractiveViewer(child: Image.network(s.data!)),
          ),
        ),
      ),
    ));
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.button),
          onTap: onTap,
          child: SizedBox(
            width: 88,
            height: 72,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)),
            ]),
          ),
        ),
      ),
    );
  }
}
