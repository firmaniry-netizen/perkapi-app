import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/models/modules.dart';
import '../../shared/widgets/state_widgets.dart';
import 'module_list_view.dart';

class ModuleListPage extends StatelessWidget {
  const ModuleListPage({super.key, required this.moduleId});
  final String moduleId;

  @override
  Widget build(BuildContext context) {
    final m = modules[moduleId];
    if (m == null) return const Scaffold(body: EmptyState(message: 'Modul tidak ditemukan'));
    if (!Access.instance.can(m.readPerm)) return const AccessDenied();
    final accent = AppColors.forKey(m.id);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(m.title)),
      body: Stack(children: [
        // Cahaya radial berwarna modul di belakang kepala layar: memberi kedalaman tanpa menambah elemen.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 320,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, -1.0),
                  radius: 1.1,
                  colors: [accent.withValues(alpha: dark ? 0.22 : 0.14), accent.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Reveal(index: 0, dy: -14, child: ScreenHero(
            heroTag: 'tile:${m.id}',
            title: m.title,
            subtitle: 'Kelola dan telusuri data ${m.title.toLowerCase()}',
            icon: m.icon,
            accent: AppColors.forKey(m.id),
          )),
        ),
        Expanded(child: ModuleListView(module: m)),
      ])),
      ]),
    );
  }
}
