import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/feature_flags.dart';
import '../core/share/pending_links.dart';
import '../features/auth/domain/auth_models.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/pages/account_conflict_page.dart';
import '../features/auth/presentation/pages/id_signup_page.dart';
import '../features/auth/presentation/pages/email_login_page.dart';
import '../features/auth/presentation/pages/profile_setup_page.dart';
import '../features/auth/presentation/pages/signup_done_page.dart';
import '../features/auth/presentation/pages/social_auth_error_page.dart';
import '../features/auth/presentation/pages/social_login_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/auth/presentation/pages/terms_page.dart';
import '../features/course/presentation/pages/add_places_page.dart';
import '../features/course/presentation/pages/ai_recommendation_page.dart';
import '../features/course/presentation/pages/companion_page.dart';
import '../features/course/presentation/pages/blocked_places_page.dart';
import '../features/course/presentation/pages/course_detail_page.dart';
import '../features/course/presentation/pages/course_edit_page.dart';
import '../features/course/presentation/pages/course_info_page.dart';
import '../features/course/presentation/pages/courses_page.dart';
import '../features/course/presentation/pages/place_selection_page.dart';
import '../features/extraction/presentation/pages/extraction_result_page.dart';
import '../features/extraction/presentation/pages/link_input_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/my/presentation/my_page.dart';
import '../features/party/presentation/invite_accept_page.dart';
import '../features/place/presentation/place_detail_page.dart';
import '../features/place/presentation/place_search_page.dart';
import '../features/saved/presentation/pages/collection_detail_page.dart';
import '../features/preference/presentation/preference_page.dart';
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

/// 코스 링크(`/courses/{id}`)면 코스 id. 코스 만들기 · 장소 고르기 화면은 링크가 아니다.
String? courseLinkId(String location) {
  final parts = Uri.parse(location).pathSegments;
  if (parts.length != 2 || parts[0] != 'courses') return null;
  return const {'new', 'pick-places'}.contains(parts[1]) ? null : parts[1];
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
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      // 코스 링크로 들어왔는데 아직 로그인 전(앱 시작 직후 포함)이면 보관했다가 로그인 후 연다
      final courseId = courseLinkId(state.matchedLocation);
      if (courseId != null && (auth.status != AuthStatus.authenticated || auth.justSignedUp)) {
        Future.microtask(() => ref.read(pendingLinksProvider.notifier).setCourse(courseId));
      }
      return authRedirect(auth, state.matchedLocation);
    },
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
      GoRoute(path: AppRoutes.signupAccount, builder: (_, _) => const IdSignupPage()),
      GoRoute(path: AppRoutes.signupDone, builder: (_, _) => const SignupDonePage()),
      GoRoute(
        path: AppRoutes.preferences,
        builder: (_, s) => PreferencePage(onboarding: s.uri.queryParameters['mode'] == 'onboarding'),
      ),
      // 코스 만들기 위저드 (진행 바 4/4, 하나의 CourseDraft 공유)
      GoRoute(path: AppRoutes.courseNewInfo, builder: (_, _) => const CourseInfoPage()),
      GoRoute(path: AppRoutes.courseNewPlaces, builder: (_, _) => const PlaceSelectionPage()),
      GoRoute(path: AppRoutes.courseNewCompanion, builder: (_, _) => const CompanionPage()),
      GoRoute(path: AppRoutes.courseNewAi, builder: (_, _) => const AiRecommendationPage()),
      // 완료 화면은 없앴다(저장하면 바로 상세). 예전 링크는 상세로 보낸다.
      GoRoute(
        path: '/courses/new/done',
        redirect: (_, s) => AppRoutes.course(s.uri.queryParameters['id'] ?? '', justSaved: true),
      ),
      GoRoute(path: AppRoutes.blockedPlaces, builder: (_, _) => const BlockedPlacesPage()),
      GoRoute(path: AppRoutes.placeSearch, builder: (_, _) => const PlaceSearchPage()),
      GoRoute(path: '/course-edit/:id', builder: (_, s) => CourseEditPage(courseId: s.pathParameters['id']!)),
      GoRoute(path: '/invites/:token', builder: (_, s) => InviteAcceptPage(token: s.pathParameters['token']!)),
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
              builder: (_, s) => CoursesPage(initialTab: s.uri.queryParameters['tab'] == 'party' ? 1 : 0),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, s) => CourseDetailPage(courseId: s.pathParameters['id']!, justSaved: s.uri.queryParameters['saved'] == '1'),
                ),
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
            GoRoute(path: AppRoutes.my, builder: (_, _) => const MyPage()),
          ]),
        ],
      ),
    ],
  );
});
