import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/feature_flags.dart';
import '../core/widgets/coming_soon_page.dart';
import '../features/auth/domain/auth_models.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/pages/account_conflict_page.dart';
import '../features/auth/presentation/pages/email_login_page.dart';
import '../features/auth/presentation/pages/profile_setup_page.dart';
import '../features/auth/presentation/pages/signup_done_page.dart';
import '../features/auth/presentation/pages/social_auth_error_page.dart';
import '../features/auth/presentation/pages/social_login_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/auth/presentation/pages/terms_page.dart';
import '../features/course/presentation/pages/add_places_page.dart';
import '../features/course/presentation/pages/course_info_page.dart';
import '../features/course/presentation/pages/courses_page.dart';
import '../features/course/presentation/pages/place_selection_page.dart';
import '../features/extraction/presentation/pages/extraction_result_page.dart';
import '../features/extraction/presentation/pages/link_input_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/place/presentation/place_detail_page.dart';
import '../features/saved/presentation/pages/collection_detail_page.dart';
import '../features/saved/domain/saved_models.dart';
import '../features/saved/presentation/pages/saved_map_page.dart';
import '../features/saved/presentation/pages/saved_page.dart';
import 'routes.dart';
import 'shell/app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// 인증 상태가 바뀌면 redirect를 다시 평가한다.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

String? authRedirect(AuthState auth, String location) {
  final isLogin = location.startsWith('/login');
  final isSignup = location.startsWith('/signup');
  // 초대 수락 화면은 비로그인도 진입 → 화면에서 토큰 보관 후 로그인으로 보낸다.
  final isInvite = location.startsWith('/invites/');

  if (location == AppRoutes.loginEmail && !FeatureFlags.emailAuthEnabled) return AppRoutes.login;

  switch (auth.status) {
    case AuthStatus.unknown:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthStatus.unauthenticated:
      return isLogin || isInvite ? null : AppRoutes.login;
    case AuthStatus.signingUp:
      if (isSignup || location == AppRoutes.preferences) return null;
      return AppRoutes.signupTerms;
    case AuthStatus.authenticated:
      if (auth.justSignedUp) return location == AppRoutes.signupDone ? null : AppRoutes.signupDone;
      if (location == AppRoutes.splash || isLogin || isSignup) return AppRoutes.home;
      return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      // ── 탭바 없는 화면 ──────────────────────────────
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const SocialLoginPage()),
      GoRoute(
        path: AppRoutes.loginConflict,
        builder: (_, s) => AccountConflictPage(conflict: s.extra as AccountConflict?),
      ),
      GoRoute(path: AppRoutes.loginError, builder: (_, s) => SocialAuthErrorPage(message: s.extra as String?)),
      GoRoute(path: AppRoutes.loginEmail, builder: (_, _) => const EmailLoginPage()),
      GoRoute(path: AppRoutes.signupTerms, builder: (_, _) => const TermsPage()),
      GoRoute(path: AppRoutes.signupProfile, builder: (_, _) => const ProfileSetupPage()),
      GoRoute(path: AppRoutes.signupDone, builder: (_, _) => const SignupDonePage()),
      GoRoute(path: AppRoutes.preferences, builder: (_, _) => const ComingSoonPage(title: '취향 설정')),
      // 코스 만들기 위저드 (진행 바 4/4, 하나의 CourseDraft 공유)
      GoRoute(path: AppRoutes.courseNewInfo, builder: (_, _) => const CourseInfoPage()),
      GoRoute(path: AppRoutes.courseNewPlaces, builder: (_, _) => const PlaceSelectionPage()),
      GoRoute(path: AppRoutes.courseNewCompanion, builder: (_, _) => const ComingSoonPage(title: '동행 설정')),
      GoRoute(
        path: AppRoutes.pickPlaces,
        builder: (_, s) => AddPlacesPage(args: s.extra as AddPlacesArgs? ?? const AddPlacesArgs()),
      ),

      // ── 하단 탭 5개 (활성 표시는 현재 라우트 기준) ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.courses,
              builder: (_, _) => const CoursesPage(),
              routes: [
                GoRoute(path: ':id', builder: (_, _) => const ComingSoonPage(title: '코스 상세')),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.saved,
              builder: (_, _) => const SavedPage(),
              routes: [
                GoRoute(
                  path: 'collections/:id',
                  builder: (_, s) => CollectionDetailPage(collectionId: s.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'map',
                  builder: (_, s) {
                    final q = s.uri.queryParameters;
                    return SavedMapPage(
                      mode: q['mode'] == 'collection' ? SavedMapMode.collection : SavedMapMode.category,
                      initialCategoryKey: q['key'],
                      initialCollectionId: q['id'],
                    );
                  },
                ),
              ],
            ),
            GoRoute(path: '/places/:id', builder: (_, s) => PlaceDetailPage(placeId: s.pathParameters['id']!)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.extract,
              builder: (_, _) => const LinkInputPage(),
              routes: [
                GoRoute(
                  path: 'result',
                  builder: (_, s) => ExtractionResultPage(
                    url: s.uri.queryParameters['url'] ?? '',
                    fromShare: s.uri.queryParameters['from'] == 'share',
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.my, builder: (_, _) => const ComingSoonPage(title: '마이', showBack: false)),
          ]),
        ],
      ),
    ],
  );
});
