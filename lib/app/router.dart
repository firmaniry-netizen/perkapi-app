import 'package:go_router/go_router.dart';

import '../core/services/access_service.dart';
import '../core/services/supabase_service.dart';
import '../core/utils/go_router_refresh_stream.dart';
import '../features/ai/ai_page.dart';
import '../features/alerts/alert_compose_page.dart';
import '../features/alerts/alerts_page.dart';
import '../features/auth/auth_repository.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/registrations_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/ahu/ahu_page.dart';
import '../features/organization/organization_profile_page.dart';
import '../features/organization/org_structure_page.dart';
import '../features/profession/profession_pages.dart';
import '../features/regulations/regulations_page.dart';
import '../features/gallery/gallery_page.dart';
import '../features/members/member_card_page.dart';
import '../features/members/verify_member_page.dart';
import '../features/modules/module_form_page.dart';
import '../features/modules/module_list_page.dart';
import '../features/pocket_book/pocket_book_page.dart';
import '../features/profile/profile_page.dart';
import '../features/broadcast/broadcast_page.dart';
import '../features/chat/chat_list_page.dart';
import '../features/chat/chat_page.dart';
import '../features/geofence/geofence_page.dart';
import '../features/reports/reports_page.dart';
import '../features/safety/safety_page.dart';
import '../features/search/search_page.dart';
import '../features/tracking/tracking_page.dart';
import '../features/settings/notification_status_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/more_page.dart';
import '../features/splash/splash_page.dart';
import '../features/welcome/welcome_page.dart';
import '../shared/widgets/state_widgets.dart';

class AppRoutes {
  AppRoutes._();
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
}

GoRoute _list(String path, String moduleId) =>
    GoRoute(path: path, builder: (_, __) => ModuleListPage(moduleId: moduleId));

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(
      SupabaseService.client.auth.onAuthStateChange.map((s) {
        if (s.session == null) Access.instance.clear();
        return s;
      }),
    ),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == AppRoutes.splash || loc == AppRoutes.welcome) return null;
      final loggedIn = SupabaseService.isLoggedIn;
      if (!loggedIn && loc != AppRoutes.login && loc != AppRoutes.register) return AppRoutes.login;
      if (loggedIn && loc == AppRoutes.login) return AppRoutes.dashboard;
      if (loggedIn && loc == AppRoutes.register && !RegistrationFlow.active) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.welcome, builder: (_, __) => const WelcomePage()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
      GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: AppRoutes.dashboard, builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/pocket-book', builder: (_, __) => const PocketBookPage()),
          GoRoute(
              path: '/pocket-book/:id',
              builder: (_, s) => ModuleFormPage(moduleId: 'notes', rowId: s.pathParameters['id'])),
          GoRoute(path: '/organization-info', builder: (_, __) => const InfoPage()),
          _list('/members', 'members'),
          _list('/events', 'events'),
          _list('/forum', 'forum'),
          // Notifikasi & Peringatan kini satu kotak masuk (tab). Rute lama tetap hidup agar tautan/notifikasi push tidak rusak.
          GoRoute(path: '/notifications', builder: (_, __) => const AlertsPage(initialTab: 1)),
          GoRoute(path: '/inbox', builder: (_, __) => const AlertsPage()),
          GoRoute(path: '/gallery', builder: (_, s) => GalleryPage(autoAdd: s.uri.queryParameters['add'] == '1', openPostId: s.uri.queryParameters['post'])),
          GoRoute(path: '/ahu', builder: (_, __) => const AhuPage()),
          GoRoute(path: '/profession', builder: (_, __) => const ProfessionPage()),
          GoRoute(path: '/regulations', builder: (_, __) => const RegulationsPage()),
          GoRoute(path: '/profession/registration', builder: (_, __) => const AhuRegistrationGuidePage()),
          GoRoute(path: '/profession/renewal', builder: (_, __) => const AhuRenewalPage()),
          GoRoute(path: '/profession/reports', builder: (_, __) => const AhuReportFormatPage()),
          GoRoute(path: '/organization-profile', builder: (_, __) => const OrganizationProfilePage()),
          GoRoute(path: '/organization-structure', builder: (_, __) => const OrgStructurePage()),
          GoRoute(path: '/member-card', builder: (_, __) => const MemberCardPage()),
          GoRoute(path: '/verify-member', builder: (_, __) => const VerifyMemberPage()),
          GoRoute(path: '/calendar', builder: (_, __) => const CalendarPage()),
          GoRoute(path: '/alerts', builder: (_, __) => const AlertsPage()),
          GoRoute(path: '/alerts/new', builder: (_, __) => const AlertComposePage()),
          GoRoute(path: '/ai', builder: (_, __) => const AiPage()),
          GoRoute(path: '/safety', builder: (_, __) => const SafetyPage()),
          GoRoute(path: '/tracking', builder: (_, __) => const TrackingPage()),
          GoRoute(path: '/geofences', builder: (_, __) => const GeofencePage()),
          GoRoute(path: '/broadcast', builder: (_, __) => const BroadcastPage()),
          GoRoute(path: '/chat', builder: (_, __) => const ChatListPage()),
          GoRoute(path: '/chat/:id', builder: (_, s) => ChatPage(threadId: s.pathParameters['id']!)),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsPage()),
          GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
          GoRoute(path: '/registrations', builder: (_, __) => const RegistrationsPage()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
          GoRoute(path: '/notification-status', builder: (_, __) => const NotificationStatusPage()),
          GoRoute(path: '/more', builder: (_, __) => const MorePage()),
          GoRoute(path: '/access-denied', builder: (_, __) => const AccessDenied()),
          GoRoute(
              path: '/module/:id',
              builder: (_, s) => ModuleListPage(moduleId: s.pathParameters['id']!)),
          GoRoute(
              path: '/module/:id/new',
              builder: (_, s) => ModuleFormPage(moduleId: s.pathParameters['id']!)),
          GoRoute(
              path: '/module/:id/:rowId',
              builder: (_, s) => ModuleFormPage(
                  moduleId: s.pathParameters['id']!, rowId: s.pathParameters['rowId'])),
        ],
      ),
    ],
  );
}
