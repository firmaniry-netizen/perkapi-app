import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/org_profile.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/widgets/scale_3d.dart';
import '../../core/widgets/ui_kit.dart';
import '../profession/guide_widgets.dart';

/// Profil Organisasi: identitas, visi-misi, kegiatan, legalitas, dan kontak sekretariat.
/// Isinya diatur di lib/core/constants/org_profile.dart.
class OrganizationProfilePage extends StatelessWidget {
  const OrganizationProfilePage({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka tautan ini.')));
    }
  }

  Widget _contactRow(BuildContext context, IconData icon, String label, String value, Uri? uri) {
    final sc = Theme.of(context).colorScheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: sc.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sc.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(height: 1.35)),
          ]),
        ),
        if (uri != null) Icon(Icons.open_in_new_rounded, size: 18, color: sc.onSurfaceVariant),
      ]),
    );
    if (uri == null) return row;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _open(context, uri), child: row);
  }

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    final hasContact = OrgProfile.address.isNotEmpty || OrgProfile.phone.isNotEmpty || OrgProfile.email.isNotEmpty || OrgProfile.website.isNotEmpty;
    final nothingFilled = OrgProfile.about.isEmpty &&
        OrgProfile.vision.isEmpty &&
        OrgProfile.missions.isEmpty &&
        OrgProfile.activities.isEmpty &&
        OrgProfile.legal.isEmpty &&
        !hasContact;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Organisasi')),
      body: PageGlow(
        accent: AppColors.navyAction,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            Reveal(
              index: 0,
              dy: -12,
              child: AppCard(
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
                    child: Image.asset(AppAssets.logoPerkapi, height: 48, width: 48, errorBuilder: (_, __, ___) => const Icon(Icons.apartment_rounded, size: 40, color: AppColors.navy)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(AppConstants.appName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 0.4)),
                      const SizedBox(height: 2),
                      Text(OrgProfile.fullName.isNotEmpty ? OrgProfile.fullName : AppConstants.appSubtitle, style: TextStyle(height: 1.35, color: sc.onSurfaceVariant)),
                      if (OrgProfile.founded.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Berdiri ${OrgProfile.founded}', style: TextStyle(fontSize: 13, color: sc.onSurfaceVariant)),
                      ],
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            const Reveal(index: 1, child: Scale3D()),
            const SizedBox(height: 12),
            AppCard(
              onTap: () => context.push('/organization-structure'),
              child: Row(children: [
                const SolidTile(icon: Icons.account_tree_rounded, color: AppColors.navy, size: 44, radius: 14),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Struktur Organisasi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    SizedBox(height: 2),
                    Text('Susunan pengurus lengkap dengan foto', style: TextStyle(fontSize: 13)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: sc.onSurfaceVariant),
              ]),
            ),
            if (nothingFilled) ...[
              const SizedBox(height: 16),
              const GuideCallout(text: 'Profil organisasi belum diisi oleh pengelola. Informasi tentang organisasi akan tampil di sini setelah diisi.'),
            ],
            if (OrgProfile.about.isNotEmpty) GuideCard(title: 'Tentang', child: Text(OrgProfile.about, style: const TextStyle(height: 1.5))),
            if (OrgProfile.vision.isNotEmpty) GuideCard(title: 'Visi', child: Text(OrgProfile.vision, style: const TextStyle(height: 1.5))),
            if (OrgProfile.missions.isNotEmpty) GuideCard(title: 'Misi', child: GuideList(OrgProfile.missions, numbered: true)),
            if (OrgProfile.activities.isNotEmpty) GuideCard(title: 'Bidang kegiatan', child: GuideList(OrgProfile.activities)),
            if (OrgProfile.legal.isNotEmpty) GuideCard(title: 'Legalitas', child: Text(OrgProfile.legal, style: const TextStyle(height: 1.5))),
            if (hasContact)
              GuideCard(
                title: 'Kontak sekretariat',
                child: Column(children: [
                  if (OrgProfile.address.isNotEmpty) _contactRow(context, Icons.location_on_outlined, 'Alamat', OrgProfile.address, null),
                  if (OrgProfile.phone.isNotEmpty)
                    _contactRow(context, Icons.phone_outlined, 'Telepon', OrgProfile.phone, Uri(scheme: 'tel', path: OrgProfile.phone.replaceAll(' ', ''))),
                  if (OrgProfile.email.isNotEmpty) _contactRow(context, Icons.mail_outline_rounded, 'Email', OrgProfile.email, Uri(scheme: 'mailto', path: OrgProfile.email)),
                  if (OrgProfile.website.isNotEmpty) _contactRow(context, Icons.language_rounded, 'Situs web', OrgProfile.website, Uri.tryParse(OrgProfile.website)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
