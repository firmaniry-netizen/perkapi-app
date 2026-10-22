import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/services/push_service.dart';
import '../core/services/quick_shortcuts.dart';
import '../core/widgets/live_banner.dart';
import 'router.dart';
import 'theme_controller.dart';
import 'theme.dart';

class PerkapiApp extends StatefulWidget {
  const PerkapiApp({super.key});

  @override
  State<PerkapiApp> createState() => _PerkapiAppState();
}

class _PerkapiAppState extends State<PerkapiApp> {
  late final GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
    PushService.instance.attachRouter(_router);
    QuickShortcuts.init(_router);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (_, mode, __) => MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        routerConfig: _router,
        scrollBehavior: const _SmoothScroll(),
        builder: (context, child) => LiveBanner(router: _router, child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}


/// Gulir memantul lembut (seperti iOS) di semua platform, tanpa kilau overscroll biru.
class _SmoothScroll extends MaterialScrollBehavior {
  const _SmoothScroll();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
