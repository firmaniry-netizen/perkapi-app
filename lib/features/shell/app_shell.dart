import 'package:flutter/material.dart';
import '../../core/constants/phosphor_icons.dart';

import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/nav_clearance.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/services/pin_service.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/perkapi_logo.dart';
import '../../shared/widgets/state_widgets.dart';
import '../../core/services/live_notifier.dart';
import '../../core/services/push_service.dart';
import '../alerts/alert_service.dart';
import '../tracking/location_service.dart';
import '../chat/call_service.dart';
import '../../core/services/online_service.dart';
import '../auth/auth_repository.dart';
import '../auth/pending_approval_view.dart';
import '../settings/pin_widgets.dart';
import 'more_page.dart';
import 'nav_items.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/widgets/aurora_background.dart';

/// Kerangka utama: tab bar bawah (layar sempit) atau sidebar (layar lebar/web).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _locked = false;
  // true selama status kunci (PIN/biometrik) belum dibaca, agar konten tidak sempat terlihat.
  bool _checking = true;
  bool _pinOn = false;
  bool _bioOn = false;

  @override
  void initState() {
    super.initState();
    Access.instance.addListener(_onAccess);
    if (!Access.instance.loaded) Access.instance.load();
    if (Access.instance.loaded && Access.instance.error == null && Access.instance.isApproved) _startLive();
    _checkLock();
  }

  void _startLive() {
    AlertService.instance.start();
    LiveNotifier.instance.start();
    LocationService.instance.start();
    PushService.instance.register();
    // status online + panggilan masuk (telepon/video call) — dipasang setelah frame agar tidak mengubah state saat build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      OnlineService.instance.start(Access.instance.memberId);
      CallService.instance.start(Access.instance.memberId, context);
    });
  }

  @override
  void dispose() {
    LiveNotifier.instance.stop();
    LocationService.instance.stop();
    OnlineService.instance.stop();
    CallService.instance.stop();
    Access.instance.removeListener(_onAccess);
    super.dispose();
  }

  void _onAccess() {
    if (Access.instance.loaded && Access.instance.error == null && Access.instance.isApproved) _startLive();
    if (mounted) setState(() {});
  }

  Future<void> _checkLock() async {
    const storage = FlutterSecureStorage();
    var bio = false;
    var pin = false;
    try {
      bio = await storage.read(key: 'biometric_lock') == '1';
      pin = await PinService.isEnabled();
    } catch (_) {}
    if (!mounted) return;
    if (!bio && !pin) {
      setState(() => _checking = false);
      return;
    }
    setState(() {
      _checking = false;
      _locked = true;
      _pinOn = pin;
      _bioOn = bio;
    });
    if (bio) await _unlock();
  }

  Future<void> _unlock() async {
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) {
        // Tanpa biometrik di perangkat: bila PIN aktif tetap terkunci (buka lewat PIN).
        if (mounted && !_pinOn) setState(() => _locked = false);
        return;
      }
      final ok = await auth.authenticate(localizedReason: 'Buka PERKAPI');
      if (mounted) setState(() => _locked = !ok);
    } catch (_) {
      if (mounted) setState(() => _locked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = Access.instance;
    if (!a.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator.adaptive()));
    if (a.error != null) {
      return Scaffold(
        body: Column(children: [
          Expanded(child: ErrorState(message: a.error!, onRetry: a.load)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton(onPressed: () => AuthRepository().signOut(), child: const Text('Keluar')),
            ),
          ),
        ]),
      );
    }
    if (!a.isApproved) return const PendingApprovalView();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = Stack(children: [
      widget.child,
      if (_checking || _locked)
        Positioned.fill(
          child: _LockView(
            checking: _checking,
            pinOn: _pinOn,
            bioOn: _bioOn,
            onUnlocked: () => setState(() => _locked = false),
            onTooMany: () {
              setState(() => _locked = false);
              AuthRepository().signOut();
            },
            onBiometric: _unlock,
          ),
        ),
    ]);

    if (wide) {
      final items = allItems.where((i) => a.can(i.perm)).toList();
      final byLabel = {for (final i in items) i.label: i};
      // Rute terpanjang yang cocok = menu aktif (mis. /profession/renewal mengalahkan /profession).
      NavItem? activeItem;
      for (final i in items) {
        final best = activeItem;
        if (widget.location.startsWith(i.route) && (best == null || i.route.length > best.route.length)) activeItem = i;
      }
      return Scaffold(
        body: Row(children: [
          Material(
            color: AppColors.navy,
            child: DecoratedBox(
            // panel samping: gradasi dongker dalam + garis kaca tipis di tepi kanan
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF13336B), AppColors.navy, AppColors.navyDeep]),
              border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
            ),
            child: SizedBox(
            width: 240,
            child: Column(children: [
              const SizedBox(height: 24),
              const PerkapiLogo(size: 56, onDark: true),
              const SizedBox(height: 8),
              const Wordmark(size: 22, color: Colors.white),
              const SizedBox(height: 16),
              // Menu dikelompokkan sama seperti halaman "Semua menu" (Organisasi, Profesi, Akun & sistem).
              Expanded(
                child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10), children: [
                  for (final g in MorePage.groups)
                    if (g.$2.any((l) => byLabel.containsKey(l))) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                        child: Text(g.$1.toUpperCase(),
                            style: TextStyle(
                                color: AppColors.gold.withValues(alpha: 0.85),
                                fontSize: AppType.micro,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                      ),
                      for (final l in g.$2)
                        if (byLabel[l] != null) _SideItem(item: byLabel[l]!, selected: byLabel[l] == activeItem, onTap: () => context.go(byLabel[l]!.route)),
                    ],
                ]),
              ),
              ListTile(
                dense: true,
                iconColor: Colors.white70,
                textColor: Colors.white,
                leading: MemberAvatar(name: a.name, path: a.avatarPath, radius: 14),
                title: Text(a.name, overflow: TextOverflow.ellipsis),
                onTap: () => context.go('/profile'),
              ),
            ]),
            )),
          ),
          Expanded(child: body),
        ]),
      );
    }

    final visible = bottomItems.where((i) => a.can(i.perm)).toList();
    final current = bottomIndexFor(widget.location);
    final selected = current < 0 ? -1 : visible.indexWhere((i) => i.route == bottomItems[current].route);
    // Tab bar hanya di halaman utama; di halaman fitur disembunyikan
    // supaya tidak menutupi isi dan tombol halaman itu (halaman fitur punya tombol kembali sendiri).
    if (!isTopLevelRoute(widget.location)) {
      return Scaffold(body: body);
    }
    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: _TabBar(
        items: visible,
        selected: selected,
        onSelect: (i) => context.go(visible[i].route),
      ),
    );
  }
}

/// Tab bar gaya iOS: bar kaca menempel di tepi bawah, tab sama lebar, ikon dan label selalu tampil.
/// Tab aktif memakai ikon terisi dan warna aksen; pil lembut di belakangnya meluncur ke tab yang dipilih.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.items, required this.selected, required this.onSelect});
  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = dark ? AppColors.navyLight : AppColors.navy;
    final still = MediaQuery.disableAnimationsOf(context);
    // Kontras tinggi: bar pekat tanpa blur supaya label tetap terbaca.
    final solid = MediaQuery.highContrastOf(context);

    Widget tab(int i) {
      final on = i == selected;
      final color = on ? accent : muted;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: items[i].label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (i != selected) tapHaptic();
              onSelect(i);
            },
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(on ? (items[i].activeIcon ?? items[i].icon) : items[i].icon, size: 25, color: color),
              const SizedBox(height: 3),
              ExcludeSemantics(
                child: Text(
                  items[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: AppType.micro, fontWeight: on ? FontWeight.w600 : FontWeight.w500, height: 1.1),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: solid ? 1 : 0.78),
        border: Border(top: BorderSide(color: (dark ? Colors.white : AppColors.navy).withValues(alpha: dark ? 0.12 : 0.08))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kFloatNavHeight,
          child: Stack(children: [
            // Tab sama lebar, jadi posisi pil cukup dihitung dari indeks tab.
            if (selected >= 0 && items.length > 1)
              AnimatedAlign(
                alignment: Alignment(-1 + 2 * selected / (items.length - 1), 0),
                duration: Duration(milliseconds: still ? 0 : 360),
                curve: const Cubic(0.23, 1, 0.32, 1),
                child: FractionallySizedBox(
                  widthFactor: 1 / items.length,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: dark ? 0.22 : 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            Row(children: [for (var i = 0; i < items.length; i++) tab(i)]),
          ]),
        ),
      ),
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      // Isi halaman terlihat samar di balik bar (blur + saturasi), seperti tab bar iOS.
      child: solid ? bar : ClipRect(child: BackdropFilter(filter: LiquidGlass.backdrop(22), child: bar)),
    );
  }
}

/// Item sidebar tablet/web: pil aktif lembut + garis emas di kiri.
class _SideItem extends StatelessWidget {
  const _SideItem({required this.item, required this.selected, required this.onTap});
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: Duration(milliseconds: still ? 0 : 220),
            curve: Curves.easeOutCubic,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            // Pil kaca untuk menu aktif (tepi putih tipis + kilau), titik emas sebagai penanda.
            decoration: BoxDecoration(
              color: selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: selected ? 0.22 : 0)),
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: Duration(milliseconds: still ? 0 : 220),
                width: selected ? 6 : 0,
                height: 6,
                margin: EdgeInsets.only(right: selected ? 8 : 0),
                decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
              ),
              Icon(item.icon, size: 20, color: selected ? Colors.white : Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: AppType.small,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Layar kunci (PIN / biometrik): latar aurora dongker, logo dengan cincin "bernapas", judul huruf situs.
class _LockView extends StatelessWidget {
  const _LockView({
    required this.checking,
    required this.pinOn,
    required this.bioOn,
    required this.onUnlocked,
    required this.onTooMany,
    required this.onBiometric,
  });
  final bool checking, pinOn, bioOn;
  final VoidCallback onUnlocked, onTooMany, onBiometric;

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: SafeArea(
        child: Center(
          child: checking
              ? const PerkapiLogo(size: 72, onDark: true)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const BreathingRing(child: PerkapiLogo(size: 76, onDark: true, animate: true)),
                    const SizedBox(height: 20),
                    Text('PERKAPI terkunci', style: AppType.headline(26, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      pinOn ? 'Masukkan PIN untuk membuka aplikasi' : 'Gunakan sidik jari atau wajah untuk membuka',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: AppType.small),
                    ),
                    const SizedBox(height: 24),
                    if (pinOn) PinPad(onUnlocked: onUnlocked, onTooMany: onTooMany),
                    if (bioOn || !pinOn) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.navy,
                          minimumSize: const Size(220, 52),
                        ),
                        onPressed: onBiometric,
                        icon: const Icon(Ph.lockKey),
                        label: const Text('Buka dengan biometrik'),
                      ),
                    ],
                  ]),
                ),
        ),
      ),
    );
  }
}
