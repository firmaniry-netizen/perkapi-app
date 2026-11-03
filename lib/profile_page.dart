import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/widgets/state_widgets.dart';
import '../auth/auth_repository.dart';
import '../members/avatar_editor.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/widgets/illustrations.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final a = Access.instance;
    final m = a.member ?? {};
    final scheme = Theme.of(context).colorScheme;
    Widget menu(IconData icon, String label, String route) => ListTile(
          minTileHeight: 56,
          leading: SolidTile(icon: icon, color: AppColors.forKey(route), size: 40, radius: 14),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          onTap: () => context.push(route),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.hero),
          child: Stack(children: [
            const Positioned.fill(child: AuroraBackground(child: SizedBox.shrink())),
            const Positioned.fill(child: DotGrid(opacity: 0.07)),
            const Positioned(right: -8, bottom: -10, child: ScalesArt(size: 130, opacity: 0.14)),
            Positioned(
              left: 22,
              bottom: 0,
              child: Container(
                width: 40,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(children: [
                AvatarEditor(
                  memberId: a.memberId ?? '',
                  forSelf: true,
                  name: a.name,
                  path: a.avatarPath,
                  canEdit: a.memberId != null,
                  onChanged: (p) {
                    Access.instance.setAvatarPath(p);
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(a.roleLabel, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 10),
                    StatusChip('${m['status'] ?? '-'}'),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        const SectionHeader('Data anggota'),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            _row('Nomor anggota', '${m['member_number'] ?? '-'}'),
            const Divider(indent: 16, endIndent: 16),
            _row('Email', '${m['email'] ?? '-'}'),
            const Divider(indent: 16, endIndent: 16),
            _row('Telepon', '${m['phone'] ?? '-'}'),
          ]),
        ),
        const SectionHeader('Situs resmi'),
        const SizedBox(height: 8),
        const AppCard(padding: EdgeInsets.symmetric(vertical: 4), child: _DirectoryToggle()),
        const SectionHeader('Pintasan'),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            menu(Icons.qr_code_2_outlined, 'Kartu anggota', '/member-card'),
            menu(Icons.verified_outlined, 'Pendaftaran AHU', '/ahu'),
            menu(Icons.notification_important_outlined, 'Peringatan anggota', '/alerts'),
            menu(Icons.shield_outlined, 'Keamanan & SOS', '/safety'),
            if (a.can('view_location')) menu(Icons.my_location_outlined, 'Pelacakan GPS', '/tracking'),
            menu(Icons.settings_outlined, 'Pengaturan & keamanan', '/settings'),
            menu(Icons.apps_rounded, 'Semua menu', '/more'),
          ]),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => AuthRepository().signOut(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Keluar'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: scheme.error,
            side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
          ),
        ),
      ]),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(width: 16),
          Expanded(child: Text(v, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

/// Persetujuan tampil di direktori anggota publik situs resmi (kolom members.show_in_directory, SQL 37).
/// Yang tampil di situs hanya nama, nomor anggota, nomor & status verifikasi AHU, kota cabang, dan status.
class _DirectoryToggle extends StatefulWidget {
  const _DirectoryToggle();
  @override
  State<_DirectoryToggle> createState() => _DirectoryToggleState();
}

class _DirectoryToggleState extends State<_DirectoryToggle> {
  bool _busy = false;

  Future<void> _set(bool v) async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.client.from('members').update({'show_in_directory': v}).eq('user_id', uid);
      Access.instance.setMemberFields({'show_in_directory': v});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(v ? 'Anda tampil di direktori anggota situs resmi.' : 'Anda tidak lagi tampil di direktori situs.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gagal menyimpan. Periksa koneksi Anda.')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = Access.instance.member ?? {};
    final on = m['show_in_directory'] == true;
    final approved = Access.instance.isApproved;
    return SwitchListTile(
      value: on,
      onChanged: _busy || !approved ? null : _set,
      secondary: const Icon(Icons.travel_explore_rounded),
      title: const Text('Tampilkan saya di direktori publik', style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(approved
          ? 'Masyarakat dapat memastikan Anda anggota PERKAPI lewat situs resmi. Email dan nomor HP tidak ditampilkan.'
          : 'Tersedia setelah pendaftaran Anda disetujui admin.'),
    );
  }
}
