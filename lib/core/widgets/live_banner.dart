import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../services/live_notifier.dart';

/// Membungkus seluruh aplikasi; banner notifikasi meluncur dari atas.
class LiveBanner extends StatelessWidget {
  const LiveBanner({super.key, required this.router, required this.child});
  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      child,
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ValueListenableBuilder<LiveNotice?>(
                  valueListenable: LiveNotifier.instance.current,
                  builder: (_, n, __) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(a),
                        child: c,
                      ),
                    ),
                    child: n == null ? const SizedBox.shrink(key: ValueKey('none')) : _Card(key: ValueKey(n.id), n: n, router: router),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.n, required this.router});
  final LiveNotice n;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final color = n.urgent
        ? AppColors.red
        : (n.type == 'warning' || n.type == 'tracking')
            ? const Color(0xFFE59A1F)
            : const Color(0xFF2456B8);
    final icon = n.urgent
        ? Icons.sos_rounded
        : n.type == 'tracking'
            ? Icons.my_location_rounded
            : n.type == 'warning'
                ? Icons.warning_amber_rounded
                : Icons.notifications_active_rounded;
    return Material(
      color: Colors.transparent,
      child: Dismissible(
        key: ValueKey('dismiss-${n.id}'),
        direction: DismissDirection.up,
        onDismissed: (_) => LiveNotifier.instance.dismiss(),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            LiveNotifier.instance.dismiss();
            final l = n.link;
            if (l != null && l.startsWith('/')) router.go(l);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF16397A), AppColors.navyDeep]),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withValues(alpha: 0.7), width: 1.2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(n.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, height: 1.25)),
                  if (n.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(n.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 13, height: 1.3)),
                    ),
                ]),
              ),
              IconButton(
                tooltip: 'Tutup',
                onPressed: LiveNotifier.instance.dismiss,
                icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.7), size: 20),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
